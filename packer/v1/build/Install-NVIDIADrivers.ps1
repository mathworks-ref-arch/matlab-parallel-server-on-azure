<#
.SYNOPSIS
    Installs NVIDIA GPU drivers.

.DESCRIPTION
    Downloads NVIDIA GPU drivers from the specified URL. Please note that:
        1)The driver versions may require modification between different MATLAB releases.
        2)This script must be run on a GPU Instance type (e.g. NC6)

.PARAMETER NVIDIADriverInstallerUrl
    (Required) The URL for downloading NVIDIA GPU drivers.

.EXAMPLE
    Install-NVIDIADrivers  -NVIDIADriverInstallerUrl "https://example.com/nvidia-driver.exe"

.LINK
    https://uk.mathworks.com/help/parallel-computing/gpu-computing-requirements.html
.NOTES
    Copyright 2024-2025 The MathWorks, Inc.
    The $ErrorActionPreference variable is set to 'Stop' to ensure that any errors encountered during the function execution will cause the script to stop and throw an error.
#>

function Install-NVIDIADrivers {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', 'Install-NVIDIADrivers')]
    param(
        [Parameter(Mandatory = $true)]
        [string] $NVIDIADriverInstallerUrl
    )

    $GPU = Get-CimInstance Win32_VideoController
    if ($null -eq $GPU ) {
        Write-Output 'Cannot find a GPU'
        exit 0
    }


    Write-Output 'Starting Install-NVIDIADrivers...'

    # Start in the temp folder
    Set-Location C:\Windows\Temp

    $StartTime = Get-Date

    $Output = 'C:\Windows\Temp\cuda.exe'
    (New-Object System.Net.WebClient).DownloadFile($NVIDIADriverInstallerUrl, $Output)
    Write-Output "NVIDIA drivers downloaded successfully. Time taken: $((Get-Date).Subtract($StartTime).Seconds) second(s)"

    # Install drivers - the instance should be rebooted prior to use
    Write-Output 'Installing NVIDIA Drivers ...'
    Start-Process -FilePath 'C:\Windows\Temp\cuda.exe' -ArgumentList '-s -noreboot -clean' -Wait -NoNewWindow

    Write-Output 'Done with Install-NVIDIADrivers.'
}


try {
    $ErrorActionPreference = 'Stop'
    Install-NVIDIADrivers -NVIDIADriverInstallerUrl $Env:NVIDIA_DRIVER_INSTALLER_URL
}
catch {
    $ScriptPath = $MyInvocation.MyCommand.Path
    Write-Output "ERROR - An error occurred while running script 'Install-NVIDIADrivers': $ScriptPath. Error: $_"
    throw
}
