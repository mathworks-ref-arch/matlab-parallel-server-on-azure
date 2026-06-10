<#
.SYNOPSIS
    Invokes the Microsoft Sysprep tool to capture custom Windows image.

.DESCRIPTION
    Invokes the Microsoft Sysprep tool to capture custom Windows image.
    https://learn.microsoft.com/en-us/azure/virtual-machines/windows/build-image-with-packer

.EXAMPLE
    Invoke-Sysprep

.NOTES
    Copyright 2024-2026 The MathWorks, Inc.
    The $ErrorActionPreference variable is set to 'Stop' to ensure that any errors encountered during the function execution will cause the script to stop and throw an error.
#>
function Invoke-Sysprep {
    try {
        Write-Output 'Starting Invoke-Sysprep...'

        Write-Output 'Waiting for essential services to start...'

        # Boolean flag to check if required services are running
        $ServicesRunning = $false

        # Start a stopwatch for timing
        $ServicesTimeoutDuration = 300
        $Stopwatch = New-Object System.Diagnostics.Stopwatch
        $Stopwatch.Start()

        while ($Stopwatch.Elapsed.TotalSeconds -le $ServicesTimeoutDuration) { 
            $RdAgent = Get-Service RdAgent -ErrorAction SilentlyContinue
            $GuestAgent = Get-Service WindowsAzureGuestAgent -ErrorAction SilentlyContinue

            if (($RdAgent.Status -eq 'Running') -and ($GuestAgent.Status -eq 'Running')) {
                Write-Output 'SUCCESS: Both RdAgent and WindowsAzureGuestAgent services are running.'
                $ServicesRunning = $true
                break
            }
        }

        $Stopwatch.Stop()

        if (-not $ServicesRunning) {
            Write-Output "Services RdAgent and WindowsAzureGuestAgent did not start within the specified timeout of $ServicesTimeoutDuration seconds."
            throw
        }

        # Start a stopwatch for timing sysprep
        $SysprepTimeoutDuration = 300
        $Stopwatch = New-Object System.Diagnostics.Stopwatch
        $Stopwatch.Start()

        # Start sysprep
        & "$Env:SystemRoot\System32\Sysprep\Sysprep.exe" /oobe /generalize /quiet /quit
        
        $ExpectedImageState = 'IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE'

        while ($Stopwatch.Elapsed.TotalSeconds -le $SysprepTimeoutDuration) { 
            $ImageState = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State'
            if ($ImageState.ImageState -ne $ExpectedImageState) {
                Write-Output $ImageState.ImageState
                Start-Sleep -Seconds 10  
            } 
            else {
                Write-Output "Final image state: $($ImageState.ImageState)"
                break 
            } 
        }
        $Stopwatch.Stop()
        if ($ImageState.ImageState -ne $ExpectedImageState) {
            $FinalImageState = $ImageState.ImageState
            throw "Image stage is $FinalImageState after $SysprepTimeoutDuration but was expected to be $ExpectedImageState"
        }

        Write-Output 'Done with Invoke-Sysprep.'

        Write-Output 'Wait for 5 mins to let sysprep complete...'
        Start-Sleep -Seconds 300
        Write-Output '5 mins wait is over.'
    }
    finally {
        Write-Output 'Printing last 10 lines of sysprep log for verification...'
        Get-FileContent -FilePath '%WINDIR%\System32\Sysprep\Panther\Setupact.log' -NLines 10
    }
}

function Get-FileContent {
    param(
        [Parameter(Mandatory = $true)]
        [string] $FilePath,

        [Parameter(Mandatory = $false)]
        [Int32] $NLines = 10
    )

    # Expand environment variables in the file path
    $ExpandedPath = [Environment]::ExpandEnvironmentVariables($FilePath)
    
    # Check if the file exists before attempting to read it
    if (Test-Path -Path $ExpandedPath) {
        Get-Content -Path $ExpandedPath -Tail $NLines
    }
    else {
        Write-Output "WARNING: File not found: $ExpandedPath"
    }
}


try {
    $ErrorActionPreference = 'Stop'
    Invoke-Sysprep
}
catch {
    $ScriptPath = $MyInvocation.MyCommand.Path
    Write-Output "ERROR - An error occurred while running script 'Invoke-Sysprep': $ScriptPath. Error: $_"
    throw
}
