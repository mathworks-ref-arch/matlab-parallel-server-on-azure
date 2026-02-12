<#
.SYNOPSIS
  Installs Polyspace using MPM.

.NOTES
  Copyright 2024-2025 The MathWorks, Inc.
  The function sets $ErrorActionPreference to 'Stop' to ensure that any errors encountered during the installation process will cause the script to stop and throw an error.
#>


function Initialize-Polyspace {
    param(
        [Parameter(Mandatory = $false)]
        [string] $PolyspaceRoot
    )
    Write-Output 'Starting Initialize-Polyspace...'
    Write-Output 'Setting up Polyspace...'
    $MJSConfigFile = Join-Path "$Env:MATLAB_ROOT" -ChildPath 'toolbox\parallel\bin\mjs_polyspace.conf'

    # Read the content of the configuration file
    $MJSConfig = Get-Content $MJSConfigFile

    # Point at polyspace install in the MJS Config file
    $UpdatedConfig = $MJSConfig -replace '# POLYSPACE_SERVER_ROOT=C:.+$', "POLYSPACE_SERVER_ROOT=$PolyspaceRoot"

    # Write the updated content back to the configuration file with ASCII encoding
    Write-Output 'Updating MJS config file to point to Polyspace installation path...'
    $UpdatedConfig | Out-File -FilePath $MJSConfigFile -Encoding ASCII
    Write-Output 'Successfully updated MJS Config.'

    Write-Output 'Done with setting up Polyspace.'
}

try {
    $ErrorActionPreference = "Stop"
    Initialize-Polyspace -PolyspaceRoot "C:\PolyspaceServer\"
}
catch {
    Write-Output "ERROR - An error occurred while running script 'Initialize-Polyspace': $_"
    throw
}
