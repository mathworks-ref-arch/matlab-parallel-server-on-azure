<#
.SYNOPSIS
    Installs Support Packages using MPM.

.LINK
    https://github.com/mathworks-ref-arch/matlab-dockerfile/blob/main/MPM.md

.DESCRIPTION
    Installs MATLAB and related products using MATLAB Package Manager.

.PARAMETER SupportPackages
    Space-separated list of MATLAB Support Packages to install.

.PARAMETER Release
    MATLAB release

.PARAMETER MATLABSourceLocation
    Location containing the source files for MATLAB/Polyspace installation.

.PARAMETER LocalSourcePath
    Local path where the remote source location should be mounted.

.NOTES
    Copyright 2024-2025 The MathWorks, Inc.
    The $ErrorActionPreference variable is set to 'Stop' to ensure that any errors encountered during the function execution will cause the script to stop and throw an error.
#>

function Install-SupportPackages {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', 'Install-SupportPackages')]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Release,

        [Parameter(Mandatory = $false)]
        [string] $SupportPackages,

        [Parameter(Mandatory = $false)]
        [string] $RemoteSourceLocation,

        [Parameter(Mandatory = $false)]
        [string] $LocalSourcePath
    )

    # If the RemoteSourceLocation is not NULL nor empty, then set the SPKGSourceLocation variable to install the products from source
    if (-not [string]::IsNullOrEmpty($RemoteSourceLocation)) {
        $SPKGSourceLocation = Join-Path -Path "$LocalSourcePath" -ChildPath 'support_packages\archives'
    }

    # Dot-sourcing the Install-ProductsUsingMPM script
    . 'C:\Windows\Temp\config\matlab\Install-ProductsUsingMPM.ps1'

    # If no support packages are specified, skip the installation
    if (-not [string]::IsNullOrWhiteSpace($SupportPackages)) {
        Install-ProductsUsingMPM -Release $Release -Products $SupportPackages -SourcePath $SPKGSourceLocation
    }
    else {
        Write-Output 'No support packages specified, skipping installation.'
    }
}

try {
    $ErrorActionPreference = 'Stop'

    Install-SupportPackages -SupportPackages "$Env:SPKGS" -Release "$Env:RELEASE" -RemoteSourceLocation "$Env:MATLAB_SOURCE_LOCATION" -LocalSourcePath 'X:'
}
catch {
    $ScriptPath = $MyInvocation.MyCommand.Path
    Write-Output "ERROR - An error occurred while running script 'Install-SupportPackages': $ScriptPath. Error: $_"
    throw
}
