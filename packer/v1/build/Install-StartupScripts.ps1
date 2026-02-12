<#
.SYNOPSIS
    Installs Startup scripts.

.DESCRIPTION
    Installs startup scripts to be executed within the EC2 instance during provisioning via the CloudFormation template.

.EXAMPLE
    Install-StartupScripts

.NOTES
    Copyright 2023-2025 The MathWorks, Inc.
    The function sets $ErrorActionPreference to 'Stop' to ensure that any errors encountered during the installation process will cause the script to stop and throw an error.
#>
function Install-StartupScripts {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', 'Install-StartupScripts')]
    param()
    Write-Output 'Starting Install-StartupScripts...'

    $StartupPath = "$Env:ProgramFiles\MathWorks\Startup"

    if (-not (Test-Path $StartupPath)) { [Void]( New-Item -Path $StartupPath -ItemType Directory ) }

    Copy-Item -Path 'C:\Windows\Temp\startup\*' -Destination $StartupPath -Recurse

    Write-Output 'Done with Install-StartupScripts.'
}


try {
    $ErrorActionPreference = 'Stop'
    Install-StartupScripts
}
catch {
    $ScriptPath = $MyInvocation.MyCommand.Path
    Write-Output "ERROR - An error occurred while running script 'Install-StartupScripts': $ScriptPath. Error: $_"
    throw
}
