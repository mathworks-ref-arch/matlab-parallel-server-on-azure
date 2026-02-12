<#
.SYNOPSIS
    Installs MATLAB and toolboxes using MPM.

.LINK
    https://github.com/mathworks-ref-arch/matlab-dockerfile/blob/main/MPM.md

.DESCRIPTION
    Installs MATLAB and related products using MATLAB Package Manager.

.PARAMETER Products
    Space-separated list of MATLAB toolboxes to install.

.PARAMETER Release
    MATLAB release

.PARAMETER MATLABRoot
    Destination path that should contain the MATLAB install.

.PARAMETER RemoteSourceLocation
    Location containing the source files for MATLAB installation.

.PARAMETER LocalSourcePath
    Local path where the remote source location should be mounted.

.NOTES
    Copyright 2024-2025 The MathWorks, Inc.
    The $ErrorActionPreference variable is set to 'Stop' to ensure that any errors encountered during the function execution will cause the script to stop and throw an error.
#>

function Install-MATLAB {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Release,

        [Parameter(Mandatory = $true)]
        [string] $Products,

        [Parameter(Mandatory = $true)]
        [string] $MATLABRoot,

        [Parameter(Mandatory = $false)]
        [string] $RemoteSourceLocation,

        [Parameter(Mandatory = $false)]
        [string] $LocalSourcePath
    )

    # If the RemoteSourceLocation is not NULL nor empty, then set the ProductsSourceLocation variable to install the products from source
    if (-not [string]::IsNullOrEmpty($RemoteSourceLocation)) {
        $ProductsSourceLocation = Join-Path -Path "$LocalSourcePath" -ChildPath "dvd\archives"
    }

    # Dot-sourcing the Install-ProductsUsingMPM script
    . 'C:\Windows\Temp\config\matlab\Install-ProductsUsingMPM.ps1'

    Install-ProductsUsingMPM -Release $Release -Products $Products -SourcePath $ProductsSourceLocation -DestinationPath "$MATLABRoot"
}

try {
    $ErrorActionPreference = 'Stop'

    Install-MATLAB -Products "$Env:PRODUCTS" -Release "$Env:RELEASE" -MATLABRoot "$Env:MATLAB_ROOT" -RemoteSourceLocation "$Env:MATLAB_SOURCE_LOCATION" -LocalSourcePath 'X:'
}
catch {
    $ScriptPath = $MyInvocation.MyCommand.Path
    Write-Output "ERROR - An error occurred while running script 'Install-MATLAB': $ScriptPath. Error: $_"
    throw
}
