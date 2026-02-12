<#
.SYNOPSIS
    Starts and configures the MATLAB Job Scheduler (MJS) and related services for MATLAB Parallel Server deployment on Azure.

.DESCRIPTION
    This script sets up networking, configures environment variables, manages firewall rules, updates the hosts file for headnode and worker nodes, and starts the MATLAB Job Scheduler (MJS) and associated services. It handles the installation, uninstallation, and startup of MJS, as well as the job manager and worker nodes, depending on the node type. The script also manages the file extensions of busy and idle scripts required by MJS, ensuring compatibility with different MATLAB releases.

.PARAMETER HeadnodeHostname
    The hostname of the headnode. Defaults to the value of $Env:HeadnodeHostname.

.PARAMETER NodeType
    The type of node ('headnode' or worker node). Determines the configuration and services to start.

.NOTES
    - Requires environment variables to be set for various paths and configuration values.
    - Assumes that the Parallel Toolbox and MATLAB are installed and available at specified locations.
    - For MATLAB releases prior to R2024b, busy and idle scripts must not have file extensions when starting MJS.
    - After starting the job manager, busy and idle scripts must have the '.bat' extension for execution.

.EXAMPLE
    Start-MJS -HeadnodeHostname "hostname" -NodeType "headnode"

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
        [string]$HeadnodeHostname = $Env:HeadnodeHostname,

        [Parameter(Mandatory = $false)]
        [string]$LocalHostname = $Env:LocalHostname,

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
        Add-Content "$Env:Windir\System32\drivers\etc\hosts" "$Env:LocalIPv4`t$HeadnodeHostname"
    }
    else {
        Add-Content "$Env:Windir\System32\drivers\etc\hosts" "$Env:HeadnodeLocalIP`t$HeadnodeHostname"
    }

    # Ensure that the MATLAB client can connect directly to the workers.
    # This is a necessary condition to create parpools.
    [Environment]::SetEnvironmentVariable('MDCE_OVERRIDE_EXTERNAL_HOSTNAME', $Env:ExternalHostName, 'Machine')
    [Environment]::SetEnvironmentVariable('MDCE_OVERRIDE_INTERNAL_HOSTNAME', $Env:LocalHostname, 'Machine')

    $MJSOpts = @(
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
        & "$Env:ParallelToolBoxRoot\startworker.bat" -jobmanagerhost $HeadnodeHostname -jobmanager "$Env:JobManagerName" -num $Env:WorkersPerNode
    }
}

try {
    Start-MJS -HeadnodeHostname $Env:HeadnodeHostname -NodeType $Env:NodeType -LocalHostname $Env:LocalHostname
}
catch {
    $ScriptPath = $MyInvocation.MyCommand.Path
    Write-Output "ERROR - An error occurred while running script '70_Start-MJS': $ScriptPath. Error: $_"
    throw
}
