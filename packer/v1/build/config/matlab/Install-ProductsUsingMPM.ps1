<#
.SYNOPSIS
    Installs products using MPM.

.LINK
    https://github.com/mathworks-ref-arch/matlab-dockerfile/blob/main/MPM.md

.DESCRIPTION
    Function definition to installs MATLAB and related products using MATLAB Package Manager.

.PARAMETER Products
    Space-separated list of products to install.

.PARAMETER Release
    MATLAB release

.PARAMETER DestinationPath
    Destination path where the products should be installed.

.PARAMETER SourcePath
    Location containing the source files for products installation.

.NOTES
    Copyright 2024-2025 The MathWorks, Inc.
#>

function Install-ProductsUsingMPM {

    param(
        [Parameter(Mandatory = $true)]
        [string] $Release,
 
        [Parameter(Mandatory = $true)]
        [string] $Products,

        [Parameter(Mandatory = $false)]
        [string] $SourcePath,

        [Parameter(Mandatory = $false)]
        [string] $DestinationPath
    )
 
    Write-Output 'Starting Install-ProductsUsingMPM...'
 
    Set-Location -Path $Env:TEMP
 
    $MpmLogFilePath = "$Env:TEMP\mathworks_$Env:USERNAME.log"
   
    $ProductsList = $Products -split ' '
   
    try {
        # Construct the mpm install command with required args
        $MPMExe = "$Env:TEMP\mpm.exe"
        $InstallArgs = @('install', '--products', $ProductsList)

        # Add the --destination flag if DestinationPath provided, else, MPM will install products to a default location
        if (-not [string]::IsNullOrEmpty($DestinationPath)) {
            $InstallArgs += @('--destination', $DestinationPath)
        }

        # Check if SourcePath is provided, if yes, install products from source
        if (-not [string]::IsNullOrEmpty($SourcePath)) {
            $InstallArgs += @('--source', $SourcePath)
        }
        else {
            $InstallArgs += @('--release', $Release)
        }

        # Execute the installation
        Write-Output "Executing MPM command: $MPMExe $InstallArgs"
        & $MPMExe @InstallArgs

        if ($LASTEXITCODE -ne 0) {
            throw "$MPMExe failed with exit code $LASTEXITCODE"
        }

        if (Test-Path $MpmLogFilePath) {
            Remove-Item $MpmLogFilePath
        }
    }
    catch {
        # Log the content of the mpm log file if it exists
        if (Test-Path $MpmLogFilePath) {
            Get-Content -Path $MpmLogFilePath
        }
        throw
    }

    Write-Output 'Done with Install-ProductsUsingMPM.'
}



