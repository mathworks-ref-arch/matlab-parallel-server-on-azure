<#
.SYNOPSIS
    Set registry keys to disable unwanted pop-ups in Windows Server.

.DESCRIPTION
    Set registry keys to disable unwanted pop-ups in Windows Server.

.EXAMPLE
    Disable-Popups

.NOTES
    Copyright 2025 The MathWorks, Inc.
    The $ErrorActionPreference variable is set to 'Stop' to ensure that any errors encountered during the function execution will cause the script to stop and throw an error.
#>

function Disable-Popups {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', 'Disable-Popups')]
    param()
    Write-Output 'Set registry keys to disable unwanted pop-ups in Windows Server'

    $NewNetworkWindowsOffKey = 'HKLM:\System\CurrentControlSet\Control\Network\NewNetworkWindowOff\'
    $WindowsOOBEKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OOBE\'

    if (-not (Test-Path -Path "$NewNetworkWindowsOffKey")) {
        New-Item -Path "$NewNetworkWindowsOffKey"
    }

    if (-not (Test-Path -Path "$WindowsOOBEKey")) {
        New-Item -Path "$WindowsOOBEKey"
    }

    Set-ItemProperty -Path 'HKLM:\Software\Microsoft\ServerManager' -Name 'DoNotOpenServerManagerAtLogon' -Value 1

}

try {
    $ErrorActionPreference = 'Stop'
    Disable-Popups
}
catch {
    $ScriptPath = $MyInvocation.MyCommand.Path
    Write-Output "ERROR - An error occurred while running script 'Disable-Popups': $ScriptPath. Error: $_"
    throw
}
