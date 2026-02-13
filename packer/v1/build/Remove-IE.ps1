<#
.SYNOPSIS
    Removes Internet Explorer (IE).

.DESCRIPTION
    Disables Internet Explorer (IE) as a Windows optional feature. This function will not raise any errors if IE is not enabled.

.EXAMPLE
    Remove-IE

.NOTES
    Copyright 2023-2024 The MathWorks, Inc.
    The function sets $ErrorActionPreference to 'Stop' to ensure that any errors encountered during the installation process will cause the script to stop and throw an error.
#>
function Remove-IE {

    Write-Output 'Starting Remove-IE...'

    # If IE is not present still returns success
    Disable-WindowsOptionalFeature -FeatureName Internet-Explorer-Optional-amd64 -Online -NoRestart

    # Add a registry entry to fix an issue when running "Invoke-WebRequest" from Optional Inline Command.
    $KeyPath = 'Registry::HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Internet Explorer\Main'
    if (!(Test-Path $KeyPath)) { New-Item $KeyPath -Force | Out-Null }
    Set-ItemProperty -Path $KeyPath -Name 'DisableFirstRunCustomize' -Value 1

    Write-Output 'Done with Remove-IE.'
}

try {
    $ErrorActionPreference = 'Stop'
    Remove-IE
}
catch {
    $ScriptPath = $MyInvocation.MyCommand.Path
    Write-Output "ERROR - An error occurred while running script 'Remove-IE': $ScriptPath. Error: $_"
    throw
}
