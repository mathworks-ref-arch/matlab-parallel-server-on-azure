<#
.SYNOPSIS
    Installs Polyspace using MPM.

.LINK
    https://github.com/mathworks-ref-arch/matlab-dockerfile/blob/main/MPM.md

.DESCRIPTION
    Installs Polyspace using MATLAB Package Manager.

.PARAMETER PolyspaceProducts
    Space-separated list of Polyspace products to install.

.PARAMETER Release
    MATLAB release

.PARAMETER PolyspaceInstallPath
    Destination path that should contain the Polyspace install.

.PARAMETER RemoteSourceLocation
    Location containing the source files for MATLAB installation.

.PARAMETER LocalSourcePath
    Local path where the remote source location should be mounted.

.NOTES
    Copyright 2024-2025 The MathWorks, Inc.
    The $ErrorActionPreference variable is set to 'Stop' to ensure that any errors encountered during the function execution will cause the script to stop and throw an error.
#>

function Install-Polyspace {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Release,

        [Parameter(Mandatory = $false)]
        [string] $PolyspaceProducts,

        [Parameter(Mandatory = $true)]
        [string] $PolyspaceInstallPath,

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

    # If no polyspace product is specified, skip the installation
    if (-not [string]::IsNullOrWhiteSpace($PolyspaceProducts)) {
        Install-ProductsUsingMPM -Release $Release -Products $PolyspaceProducts -SourcePath "$ProductsSourceLocation" -DestinationPath "$PolyspaceInstallPath"
    }
    else {
        Write-Output "No polyspace product specified, skipping installation."
    }
}

try {
    $ErrorActionPreference = 'Stop'

    Install-Polyspace -PolyspaceProducts "$Env:POLYSPACE_PRODUCTS" -Release "$Env:RELEASE" -PolyspaceInstallPath "C:\PolyspaceServer\" -RemoteSourceLocation "$Env:MATLAB_SOURCE_LOCATION" -LocalSourcePath 'X:'
}
catch {
    $ScriptPath = $MyInvocation.MyCommand.Path
    Write-Output "ERROR - An error occurred while running script 'Install-Polyspace': $ScriptPath. Error: $_"
    throw
}
