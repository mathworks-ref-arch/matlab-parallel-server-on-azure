<#
.SYNOPSIS
    Installs Runtime scripts.

.DESCRIPTION
    Installs Runtime scripts to be executed within the Parallel Server Headnode and worker nodes after provisioning.

.EXAMPLE
    Install-RuntimeScripts

.NOTES
    Copyright 2023-2025 The MathWorks, Inc.
    The function sets $ErrorActionPreference to 'Stop' to ensure that any errors encountered during the installation process will cause the script to stop and throw an error.
#>
function Install-RuntimeScripts {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', 'Install-RuntimeScripts')]
    param()
    Write-Output 'Starting Install-RuntimeScripts...'

    $RuntimeScriptsPath = "$Env:ProgramFiles\MathWorks\"

    if (-not (Test-Path $RuntimeScriptsPath)) { [Void]( New-Item -Path $RuntimeScriptsPath -ItemType Directory ) }

    # Install mwplatforminterfaces package
    Move-Item -Path 'C:\Windows\Temp\runtime\mwplatforminterfaces\' -Destination "$Env:ProgramFiles\MathWorks\"

    # Update to the latest pip version
    py -m pip install --upgrade pip

    # Installing common dependencies
    py -m pip install -e "$Env:ProgramFiles\MathWorks\mwplatforminterfaces"

    # Installing cloud-specific dependencies, supported clouds are aws, azure
    py -m pip install -e "$Env:ProgramFiles\MathWorks\mwplatforminterfaces[azure]"

    # Install cluster_management package
    Move-Item -Path 'C:\Windows\Temp\runtime\cluster_management\terminationpolicies\mjs_status_scripts' -Destination 'C:\'
    Move-Item -Path 'C:\Windows\Temp\runtime\cluster_management\' -Destination "$Env:ProgramFiles\MathWorks\"

    Write-Output 'Done with Install-RuntimeScripts.'
}


try {
    $ErrorActionPreference = 'Stop'
    Install-RuntimeScripts
}
catch {
    $ScriptPath = $MyInvocation.MyCommand.Path
    Write-Output "ERROR - An error occurred while running script 'Install-RuntimeScripts': $ScriptPath. Error: $_"
    throw
}
