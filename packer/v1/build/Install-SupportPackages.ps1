<#
.SYNOPSIS
    Installs Support Packages using MPM.

.LINK
    https://github.com/mathworks-ref-arch/matlab-dockerfile/blob/main/MPM.md

.DESCRIPTION
    Sets the Support Package root directory and installs MATLAB Support Packages using MATLAB Package Manager.

.PARAMETER SupportPackages
    Space-separated list of MATLAB Support Packages to install.

.PARAMETER Release
    MATLAB release

.PARAMETER MATLABSourceLocation
    Location containing the source files for MATLAB/Polyspace installation.

.PARAMETER LocalSourcePath
    Local path where the remote source location should be mounted.

.NOTES
    Copyright 2024-2026 The MathWorks, Inc.
    The $ErrorActionPreference variable is set to 'Stop' to ensure that any errors encountered during the function execution will cause the script to stop and throw an error.
#>

function Set-SupportPackageRoot {

    param(
        [Parameter(Mandatory = $true)]
        [string] $Release,

        [Parameter(Mandatory = $true)]
        [string] $Destination,

        [Parameter(Mandatory = $true)]
        [string] $MATLABRoot
    )
    # Ensure that the destination directory exists
    if (-not (Test-Path -Path $Destination)) {
        New-Item -Path $Destination -ItemType Directory -Force | Out-Null
    }

    if ( $Release -gt "R2024b" ) {
        $SprootWriterPath = Join-Path -Path "${MATLABRoot}" -ChildPath "bin\win64\sprootsettingwriter.exe"
        New-Item -Path "${Destination}" -ItemType Directory -Force | Out-Null    
        & "${SprootWriterPath}" -matlabroot "$MATLABRoot" -sproot "${Destination}"
    } else {
        Set-Content -Path "$MATLABRoot\toolbox\local\supportpackagerootsetting.xml" -Value "<?xml version=`"1.0`" encoding=`"UTF-8`"?><SupportPackageRootSettings><Setting name=`"sproot`">$Destination</Setting></SupportPackageRootSettings>"
    }

}

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

    if (-not [string]::IsNullOrEmpty($RemoteSourceLocation)) {
        $SPKGSourceLocation = Join-Path -Path "$LocalSourcePath" -ChildPath 'support_packages\archives'
    }

    . 'C:\Windows\Temp\config\matlab\Install-ProductsUsingMPM.ps1'

    if (-not [string]::IsNullOrWhiteSpace($SupportPackages)) {
        Install-ProductsUsingMPM -Release $Release -Products $SupportPackages -SourcePath $SPKGSourceLocation
    }
    else {
        Write-Output 'No support packages specified, skipping installation.'
    }
}

try {
    $ErrorActionPreference = 'Stop'
    $MATLABRoot = "C:\Program Files\MATLAB\$Env:RELEASE"
    $DefaultSpkgRoot = "$MATLABRoot\supportpackages"

    Set-SupportPackageRoot -Release $Env:RELEASE -Destination "${DefaultSpkgRoot}" -MATLABRoot "${MATLABRoot}"
    Install-SupportPackages -SupportPackages "$Env:SPKGS" -Release "$Env:RELEASE" -RemoteSourceLocation "$Env:MATLAB_SOURCE_LOCATION" -LocalSourcePath 'X:'
}
catch {
    $ScriptPath = $MyInvocation.MyCommand.Path
    Write-Output "ERROR - An error occurred while running script 'Install-SupportPackages': $ScriptPath. Error: $_"
    throw
}