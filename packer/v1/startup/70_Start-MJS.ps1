<#
.SYNOPSIS
    Starts and configures the MATLAB Job Scheduler (MJS) and related services for MATLAB Parallel Server deployment on Azure.

.DESCRIPTION
    Configures networking, firewall rules, and the hosts file, then installs and starts the
    MATLAB Job Scheduler (MJS) and associated services for MATLAB Parallel Server on Azure.
    On the headnode, this starts the job manager; on worker nodes, it starts the workers.
    Also manages busy/idle script file extensions required by MJS for MATLAB releases prior to R2024b.

.PARAMETER InternalHostname
    The internal hostname (computer name) of the current node. Defaults to $Env:InternalHostname.

.PARAMETER ExternalHostname
    The external hostname (will be visible to MATLAB clients) of the current node. Defaults to $Env:ExternalHostname.

.PARAMETER NodeType
    The type of node ('headnode' or 'worker'). Determines which services are started. Defaults to $Env:NodeType.

.ENVIRONMENT
    This script requires the following environment variables to be set before execution. These variables are
    either set in the user-data or in previous startup scripts.

    LocalIPv4            - Local IPv4 address of the current node.
    HeadnodeHostname     - External hostname of the headnode (used by workers to identify the headnode).
    HeadnodeLocalIP      - Local IP of the headnode (used by workers to resolve headnode hostname).
    MJSBusyIdleScripts   - Path to the directory containing busy and idle scripts.
    ParallelToolBoxRoot  - Path to the Parallel Toolbox installation directory.
    JobManagerName       - Name of the MJS job manager.
    MATLABRelease        - MATLAB release version (e.g. 'R2024a'), used to handle busy/idle script extensions.
    MJSAdminPasswordFile - Path to the file containing the MJS administrator password (Security Level 2 and 3).
    CertFile             - Path to the certificate file used by the job manager.
    WorkersPerNode       - Number of workers to start on each worker node.

.EXAMPLE
    Start-MJS -NodeType "headnode" -ExternalHostname "myheadnode" -InternalHostname "myheadnode-internal"

.NOTES
    Copyright 2022-2026 The MathWorks, Inc.
#>

function Convert-BusyIdleScriptExtensions {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', 'Convert-BusyIdleScriptExtensions')]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('NULL', 'BAT')]
        [string]$Extension
    )

    # Define the base filenames without extension
    $FileNames = @('busy', 'idle')

    foreach ($FileName in $FileNames) {
        # Construct the full path for each file with and without the .bat extension
        $FullPathWithExtension = Join-Path -Path $Env:MJSBusyIdleScripts -ChildPath "$FileName.bat"
        $FullPathWithoutExtension = Join-Path -Path $Env:MJSBusyIdleScripts -ChildPath $FileName

        if ($Extension -eq 'NULL' -and (Test-Path -Path $FullPathWithExtension)) {
            # Rename the file to remove the '.bat' extension
            Rename-Item -Path $FullPathWithExtension -NewName $FullPathWithoutExtension
        }
        elseif ($Extension -eq 'BAT' -and (Test-Path -Path $FullPathWithoutExtension)) {
            # Rename the file to add the '.bat' extension
            Rename-Item -Path $FullPathWithoutExtension -NewName $FullPathWithExtension
        }
    }
}

function Start-MJS {
    param(
        [Parameter(Mandatory = $false)]
        [string]$InternalHostname = $Env:InternalHostname,

        [Parameter(Mandatory = $false)]
        [string]$ExternalHostname = $Env:ExternalHostname,

        [Parameter(Mandatory = $false)]
        [string]$NodeType
    )
    Write-Output '===Setting up Networking==='

    # Set context for Online Licensing.
    [Environment]::SetEnvironmentVariable('MHLM_CONTEXT', 'PARALLEL_SERVER_Azure', 'Machine')

    # Open all firewall ports. Rely on external network security group to protect subnet.
    Get-NetFirewallRule | Where-Object { $_.Name -like 'RemoteSvcAdmin*' } | Enable-NetFirewallRule
    New-NetFirewallRule -Name 'parallelserver_inbound' -DisplayName 'parallelserver_inbound' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 0-65535 -ErrorAction SilentlyContinue
    New-NetFirewallRule -Name 'parallelserver_outbound' -DisplayName 'parallelserver_outbound' -Direction Outbound -Action Allow -Protocol TCP -LocalPort 0-65535 -ErrorAction SilentlyContinue

    # Ensure that all communication with the headnode occurs on the local network.
    if ($NodeType -eq 'headnode') {
        Add-Content "$Env:Windir\System32\drivers\etc\hosts" "$Env:LocalIPv4`t$ExternalHostname"
        $MJSHostname = "$ExternalHostname"
    }
    else {
        $HeadnodeExternalHostname = "$Env:HeadnodeHostname"
        Add-Content "$Env:Windir\System32\drivers\etc\hosts" "$Env:HeadnodeLocalIP`t$HeadnodeExternalHostname"
        $MJSHostname = "$InternalHostname"
    }

    # Ensure that the MATLAB client can connect directly to the workers.
    # This is a necessary condition to create parpools.
    [Environment]::SetEnvironmentVariable('MDCE_OVERRIDE_EXTERNAL_HOSTNAME', $ExternalHostName, 'Machine')
    [Environment]::SetEnvironmentVariable('MDCE_OVERRIDE_INTERNAL_HOSTNAME', $InternalHostName, 'Machine')

    # Set MPICH_INTERFACE_HOSTNAME to internal hostname for worker-worker communication
    [Environment]::SetEnvironmentVariable('MPICH_INTERFACE_HOSTNAME', $InternalHostName, 'Machine')

    $MJSOpts = @(
        '-hostname', "$MJSHostname",
        '-enablepeerlookup',
        '-cleanPreserveJobs',
        '-sendactivitynotifications',
        '-scriptroot', "$Env:MJSBusyIdleScripts",
        '-disableelevate'
    )

    # Stop MJS if it is already running
    if ($NodeType -eq 'headnode') {
        $IsMJSRunning = (tasklist /fi 'ImageName eq mjsd.exe' | Select-String -Pattern 'mjsd.exe' -Quiet)

        if ($IsMJSRunning) {
            Write-Output 'MJS is running, hence stopping already running services.'
            & "$Env:ParallelToolBoxRoot\stopjobmanager.bat" -name "$Env:JobManagerName" -cleanPreserveJobs
            Write-Output 'Stopped Job manager'
            & "$Env:ParallelToolBoxRoot\mjs.bat" stop -cleanPreserveJobs
        }

        & "$Env:ParallelToolBoxRoot\mjs.bat" uninstall -cleanPreserveJobs
        if (-not $?) {
            Write-Output 'Failed to uninstall MJS, must not be installed'
        }
    }

    # Before starting MJS, we must ensure that the busy and idle scripts do not have any extension
    # This is needed because mjs start -sendactivitynotifications expects these files to be without extension
    if ($Env:MATLABRelease -lt 'R2024b') {
        # This has been fixed for R2024b and beyond
        Convert-BusyIdleScriptExtensions -Extension 'NULL'
    }

    # Start all services
    Write-Output '===Installing MATLAB Job Scheduler==='
    & "$Env:ParallelToolBoxRoot\mjs.bat" install -cleanPreserveJobs
    if (-not $?) { throw 'Failed to install MJS' }

    Write-Output '===Starting MATLAB Job Scheduler==='
    & "$Env:ParallelToolBoxRoot\mjs.bat" start $MJSOpts
    if (-not $?) {
        throw "Failed to start MJS with options: $MJSOpts"
    }


    if ($NodeType -eq 'headnode') {
        Write-Output '===Starting Job Manager==='
        if (Test-Path $Env:MJSAdminPasswordFile) {
            # Provide the password for the administrator account if one has been generated (Security Level 2 and 3)
            $AdminPassword = $(Get-Content $Env:MJSAdminPasswordFile)
            if ($Env:MATLABRelease -gt 'R2023b') {
                $Env:PARALLEL_SERVER_JOBMANAGER_ADMIN_PASSWORD = $AdminPassword
            } 
            else {
                $Env:MDCEQE_JOBMANAGER_ADMIN_PASSWORD = $AdminPassword
            }
            
        }
        & "$Env:ParallelToolBoxRoot\startjobmanager.bat" -name "$Env:JobManagerName" -certificate "$Env:CertFile" -cleanPreserveJobs
        if (-not $?) {
            throw 'Failed to start Job Manager'
        }

        # If the job manager is successfully started, add .bat extension to the busy and idle files else MJS can't execute them
        Convert-BusyIdleScriptExtensions -Extension 'BAT'

    }
    else {
        Write-Output '===Starting workers==='
        & "$Env:ParallelToolBoxRoot\startworker.bat" -jobmanagerhost $HeadnodeExternalHostname -jobmanager "$Env:JobManagerName" -num $Env:WorkersPerNode
    }
}

try {
    Start-MJS -NodeType $Env:NodeType -ExternalHostname $Env:ExternalHostname -InternalHostname $Env:InternalHostname
}
catch {
    $ScriptPath = $MyInvocation.MyCommand.Path
    Write-Output "ERROR - An error occurred while running script '70_Start-MJS': $ScriptPath. Error: $_"
    throw
}
