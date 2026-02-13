<#
.SYNOPSIS
    Edit the MJS startup parameters in the mjs_def file

.DESCRIPTION
    # This script defines MATLAB Job Scheduler Startup Parameters
    # https://www.mathworks.com/help/matlab-parallel-server/define-startup-parameters.html

.OUTPUTS
    0 if parameter was set successfully, non-zero on error.

.EXAMPLE
    Edit-MJSDef

.NOTES
    Copyright 2022-2025 The MathWorks, Inc.
#>
function Set-MJSParams {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', 'Set-MJSParams')]
    param (
        [Parameter(Mandatory = $true)]
        [string] $DefFile,

        [Parameter(Mandatory = $true)]
        [string] $ParameterName,

        [Parameter(Mandatory = $true)]
        [string] $ParameterValue
    )

    (Get-Content $DefFile -Raw) -replace "REM set $ParameterName=.*", "set $ParameterName=$ParameterValue" | Set-Content $DefFile
    if (-not (Select-String -Pattern "^set $ParameterName=" -Path $DefFile)) {
        Write-Output "Failed to set parameter $ParameterName"
        exit 1
    }
}

function Set-MJSSecurityParams {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', 'Set-MJSSecurityParams')]
    param (
        [Parameter(Mandatory = $true)]
        [string] $SecurityLevel,

        [Parameter(Mandatory = $true)]
        [string] $MJSAdminPasswordFile
    )

    if ($SecurityLevel) {
        Set-MJSParams -DefFile $Env:MJSDefFile -ParameterName 'SECURITY_LEVEL' -ParameterValue $SecurityLevel

        # Generate default password for ADMIN_USER at Security Level 2 and 3
        if (([int]$SecurityLevel -ge 2) -and -not (Test-Path $MJSAdminPasswordFile)) {
            $MJSAdminPasswordRoot = Split-Path -Parent $MJSAdminPasswordFile
            if (-not (Test-Path $MJSAdminPasswordRoot)) {
                New-Item -Path $MJSAdminPasswordRoot -ItemType Directory
            }
            Add-Type -AssemblyName 'System.Web'
            [System.Web.Security.Membership]::GeneratePassword(32, 0) | Set-Content $MJSAdminPasswordFile
        }
    }
}

function Set-MJSHeapMemory {
    param (
        [Parameter(Mandatory = $true)]
        [int] $WorkersPerNode,

        [Parameter(Mandatory = $true)]
        [int] $MaxNodes
    )

    $MemoryMB = (Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory / 1024 / 1024
    if ($Env:NodeType -eq 'headnode') {
        $JobManagerMaximumMemoryMB = 1024 + 5 * $MaxNodes * $WorkersPerNode
        if ($JobManagerMaximumMemoryMB -gt $MemoryMB / 2) {
            $JobManagerMaximumMemoryMB = [int]($MemoryMB / 2)
        }
        Set-MJSParams -DefFile $Env:MJSDefFile -ParameterName 'JOB_MANAGER_MAXIMUM_MEMORY' -ParameterValue "${JobManagerMaximumMemoryMB}m"
    }
    else {
        $WorkerMaximumMemoryMB = 1024 + 64 * $WorkersPerNode
        if ($WorkerMaximumMemoryMB -gt $MemoryMB / 4) {
            $WorkerMaximumMemoryMB = [int]($MemoryMB / 4)
        }
        Set-MJSParams -DefFile $Env:MJSDefFile -ParameterName 'WORKER_MAXIMUM_MEMORY' -ParameterValue "${WorkerMaximumMemoryMB}m"
    }
}

function Set-MJSAutoScalingParams {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', 'Set-MJSAutoScalingParams')]
    param (
        [Parameter(Mandatory = $true)]
        [string] $EnableAutoscaling,

        [Parameter(Mandatory = $true)]
        [string] $MATLABRelease,

        [Parameter(Mandatory = $true)]
        [int] $WorkersPerNode,

        [Parameter(Mandatory = $true)]
        [int] $MaxNodes
    )

    # Initialize the autoscaling flag
    $AutoscalingFlag = $false
    if ($EnableAutoscaling -eq 'Yes') {
        if ($MATLABRelease -gt 'R2021b') {
            $AutoscalingFlag = $true
            Set-MJSParams -DefFile $Env:MJSDefFile -ParameterName 'MAX_WINDOWS_WORKERS' -ParameterValue "$(1*$MaxNodes*$WorkersPerNode)"
        }
        else {
            Write-Output 'WARNING: Auto-Resizing is only available for R2022a and later'
        }
    }
    # Apply the autoscaling setting to the cluster management data file
    $ClusterManagementProgramData = Get-Content -Path $Env:ClusterManagementDataFile -Raw | ConvertFrom-Json
    $ClusterManagementProgramData.config.autoscaling_enabled = $AutoscalingFlag
    $ClusterManagementProgramData | ConvertTo-Json | Set-Content -Path $Env:ClusterManagementDataFile
}

function Set-MJSSchedulingAlgorithm {
    param (
        [Parameter(Mandatory = $true)]
        [string] $MATLABRelease,

        [Parameter(Mandatory = $true)]
        [string] $SchedulingAlgorithm
    )

    if ($MATLABRelease -gt 'R2023a') {
        Set-MJSParams -DefFile $Env:MJSDefFile -ParameterName 'SCHEDULING_ALGORITHM' -ParameterValue "$SchedulingAlgorithm"
    }
    else {
        Write-Output 'WARNING: Selecting the scheduling algorithm is only available for R2023b and later'
    }
}

function Edit-MJSDef {
    if ($Env:NodeType -eq 'headnode') {
        # Hostname of the job manager.
        $MJSHostname = $Env:HeadnodeHostname
    }
    else {
        # Hostname of the worker node
        $MJSHostname = $Env:LocalHostname
    }

    $parameters = @{  
        'CHECKPOINTBASE'             = $Env:CheckpointRoot
        'USE_SECURE_COMMUNICATION'   = 'true'
        'REQUIRE_CLIENT_CERTIFICATE' = 'true'
        'HOSTNAME'                   = $MJSHostname
        'SHARED_SECRET_FILE'         = $Env:SecretFile
    }  
    foreach ($param in $parameters.GetEnumerator()) {  
        Set-MJSParams -DefFile $Env:MJSDefFile -ParameterName $param.Key -ParameterValue $param.Value  
    }

    # Set Cluster Command Verification
    # https://www.mathworks.com/help/matlab-parallel-server/set-matlab-job-scheduler-cluster-security.html#mw_ca721746-0154-4d20-9a6e-753bed4d4058
    # For releases MATLAB R2023a and later, this variable makes the mjs service verify each command with the secret file before execution.
    if ($Env:MATLABRelease -ge 'R2023a') {
        Set-MJSParams -DefFile $Env:MJSDefFile -ParameterName 'REQUIRE_SCRIPT_VERIFICATION' -ParameterValue 'true'
    }

    # Use a license that is managed online.
    if (-not $Env:MLMLicenseFile) {
        Set-MJSParams -DefFile $Env:MJSDefFile -ParameterName 'USE_ONLINE_LICENSING' -ParameterValue 'true'
    }

    # Set MATLAB Job Scheduler Cluster Security
    # https://www.mathworks.com/help/matlab-parallel-server/set-matlab-job-scheduler-cluster-security.html
    Set-MJSSecurityParams -SecurityLevel $Env:SecurityLevel -MJSAdminPasswordFile $Env:MJSAdminPasswordFile    

    # Increase heap memory available to MJS
    # https://www.mathworks.com/help/matlab-parallel-server/customize-startup-parameters.html
    Set-MJSHeapMemory -WorkersPerNode $Env:WorkersPerNode -MaxNodes $Env:MaxNodes

    # Set up MJS Cluster for Auto-Resizing
    # https://www.mathworks.com/help/matlab-parallel-server/set-up-your-mjs-cluster-for-resizing.html
    if ($Env:NodeType -eq 'headnode') {
        Set-MJSAutoScalingParams -EnableAutoscaling $Env:EnableAutoscaling -MATLABRelease $Env:MATLABRelease -WorkersPerNode $Env:WorkersPerNode -MaxNodes $Env:MaxNodes
    }

    # Set scheduling algorithm for the job manager
    if ($Env:SchedulingAlgorithm) {
        Set-MJSSchedulingAlgorithm -MATLABRelease $Env:MATLABRelease -SchedulingAlgorithm $Env:SchedulingAlgorithm
    }
}

try {
    Edit-MJSDef
}
catch {
    $ScriptPath = $MyInvocation.MyCommand.Path
    Write-Output "ERROR - An error occurred while running script '50_Edit-MJS-Def': $ScriptPath. Error: $_"
    throw
}
