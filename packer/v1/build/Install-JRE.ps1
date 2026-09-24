<#
.SYNOPSIS
    Installs a standalone Adoptium Temurin JRE and points MATLAB at it.

.DESCRIPTION
    R2026b and newer no longer ship a bundled Java runtime, but MATLAB Job
    Scheduler still needs one. Downloads the Adoptium Temurin JRE, verifies its
    checksum, and configures MATLAB by release:
    - before R2026b: junction the standalone JRE over MATLAB's bundled one;
    - R2026b and newer: set MJS_JAVA in mjs_def.bat to point MJS at it.

.NOTES
    Copyright 2026 The MathWorks, Inc.
#>

$ErrorActionPreference = 'Stop'

# Release at/after which MATLAB no longer ships a bundled JRE.
$Script:JreDroppedRelease = 'R2026b'

function Get-NormalizedRelease {
    param([Parameter(Mandatory)] [string] $Release)
    return $Release.Substring(0, 1).ToUpper() + $Release.Substring(1).ToLower()
}

# Query the Adoptium assets API for the latest GA JRE (returns link + SHA-256).
function Get-AdoptiumAsset {
    param(
        [Parameter(Mandatory)] [string] $JavaVersion,
        [string] $Arch = 'x64'
    )
    $apiUrl = "https://api.adoptium.net/v3/assets/latest/$JavaVersion/hotspot" +
        "?architecture=$Arch&image_type=jre&os=windows&vendor=eclipse"
    $package = (Invoke-RestMethod -Uri $apiUrl)[0].binary.package
    if (-not $package.link) {
        throw "Adoptium API returned no download link for JRE $JavaVersion (windows/$Arch)"
    }
    return $package
}

# Download and checksum-verify the JRE zip; return its local path.
function Get-Jre {
    param(
        [Parameter(Mandatory)] [string] $JavaVersion,
        [string] $Arch = 'x64'
    )
    $package = Get-AdoptiumAsset -JavaVersion $JavaVersion -Arch $Arch
    $zipPath = "$Env:TEMP\OpenJDK${JavaVersion}U-jre.zip"

    # Write-Host, not Write-Output: this function returns $zipPath.
    Write-Host "Downloading Temurin $JavaVersion JRE (windows/$Arch) ..."
    Invoke-WebRequest -Uri $package.link -OutFile $zipPath

    Write-Host 'Verifying checksum ...'
    $actual = (Get-FileHash -Path $zipPath -Algorithm SHA256).Hash
    if ($actual -ine $package.checksum) {
        throw "Checksum mismatch: expected $($package.checksum), got $actual"
    }
    Write-Host 'Checksum OK'
    return $zipPath
}

# Extract the zip into $JrePath and verify java runs.
function Install-Jre {
    param(
        [Parameter(Mandatory)] [string] $ZipPath,
        [Parameter(Mandatory)] [string] $JrePath
    )
    if (Test-Path $JrePath) { Remove-Item -Path $JrePath -Recurse -Force }
    $extractRoot = "$Env:TEMP\jre-extract"
    if (Test-Path $extractRoot) { Remove-Item -Path $extractRoot -Recurse -Force }

    Expand-Archive -Path $ZipPath -DestinationPath $extractRoot -Force
    $innerDir = Get-ChildItem -Path $extractRoot -Directory | Select-Object -First 1
    New-Item -Path (Split-Path -Parent $JrePath) -ItemType Directory -Force | Out-Null
    Move-Item -Path $innerDir.FullName -Destination $JrePath
    Remove-Item -Path $extractRoot -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $ZipPath -Force -ErrorAction SilentlyContinue

    $javaExe = Join-Path $JrePath 'bin\java.exe'
    if (-not (Test-Path $javaExe)) {
        throw "java.exe not found at $javaExe after installation"
    }
    # Run java -version out-of-process (its stderr banner would trip EAP=Stop).
    $process = Start-Process -FilePath $javaExe -ArgumentList '-version' `
        -NoNewWindow -Wait -PassThru -ErrorAction Continue
    if ($process.ExitCode -ne 0) {
        throw "java -version failed with exit code $($process.ExitCode)"
    }
}

# $true if the release still bundles a JRE (before R2026b).
function Test-ReleaseShipsJre {
    param([Parameter(Mandatory)] [string] $Release)
    return $Release -lt $Script:JreDroppedRelease
}

# Point MATLAB/MJS at the standalone JRE (junction pre-R2026b, else MJS_JAVA).
function Set-MatlabJre {
    param(
        [Parameter(Mandatory)] [string] $Release,
        [Parameter(Mandatory)] [string] $MatlabRoot,
        [Parameter(Mandatory)] [string] $JrePath
    )
    if (Test-ReleaseShipsJre -Release $Release) {
        $matlabJre = "$MatlabRoot\sys\java\jre\win64\jre"
        if (Test-Path $matlabJre) { Remove-Item -Path $matlabJre -Recurse -Force }
        New-Item -Path (Split-Path -Parent $matlabJre) -ItemType Directory -Force | Out-Null
        New-Item -Path $matlabJre -ItemType Junction -Value $JrePath | Out-Null
        Write-Output "Linked bundled MATLAB JRE at $matlabJre -> $JrePath"
    }
    else {
        $mjsDefFile = "$MatlabRoot\toolbox\parallel\bin\mjs_def.bat"
        if (-not (Test-Path $mjsDefFile)) {
            throw "mjs_def.bat not found at $mjsDefFile"
        }
        (Get-Content $mjsDefFile -Raw) -Replace 'REM set MJS_JAVA=.*', "set MJS_JAVA=$JrePath" | Set-Content $mjsDefFile
        if (-not (Select-String -Pattern '^set MJS_JAVA=' -Path $mjsDefFile)) {
            throw "Failed to set MJS_JAVA in $mjsDefFile - check whether a 'REM set MJS_JAVA=' line exists in this release's mjs_def.bat"
        }
        Write-Output 'Updated MJS_JAVA setting:'
        Select-String -Pattern '^set MJS_JAVA=' -Path $mjsDefFile
    }
}

# Log the Temurin license terms and on-image license files.
function Write-LicenseInfo {
    param(
        [Parameter(Mandatory)] [string] $JavaVersion,
        [Parameter(Mandatory)] [string] $JrePath,
        [string] $Arch = 'x64'
    )
    $legalBase = Join-Path $JrePath 'legal\java.base'

    Write-Output '============================================================'
    Write-Output "Adoptium Temurin JRE $JavaVersion - license information"
    Write-Output '============================================================'
    Write-Output 'License: GNU General Public License, version 2, WITH the Classpath Exception'
    Write-Output 'SPDX-License-Identifier: GPL-2.0 WITH Classpath-exception-2.0'
    Write-Output "Source: https://api.adoptium.net/v3/assets/latest/$JavaVersion/hotspot?architecture=$Arch&image_type=jre&os=windows&vendor=eclipse"
    Write-Output ''

    $notice = Join-Path $JrePath 'NOTICE'
    if (Test-Path $notice) {
        Write-Output '----- NOTICE (bundled with the JRE) -----'
        Get-Content -Path $notice | ForEach-Object { Write-Output $_ }
        Write-Output ''
    }

    Write-Output '----- Full license text bundled on the image -----'
    foreach ($f in 'LICENSE', 'ASSEMBLY_EXCEPTION', 'ADDITIONAL_LICENSE_INFO') {
        $p = Join-Path $legalBase $f
        if (Test-Path $p) { Write-Output "  $p" }
    }
    Write-Output ''

    $legalRoot = Join-Path $JrePath 'legal'
    if (Test-Path $legalRoot) {
        Write-Output "----- Third-party component licenses (under $legalRoot) -----"
        Get-ChildItem -Path $legalRoot -Recurse -File |
            Where-Object { $_.Extension -eq '.md' -or $_.Name -eq 'LICENSE' } |
            Sort-Object FullName |
            ForEach-Object { Write-Output ('  ' + $_.FullName.Substring($JrePath.Length + 1)) }
        Write-Output ''
    }
    Write-Output '============================================================'
}

function Invoke-Main {
    if (-not $Env:RELEASE) {
        throw 'RELEASE is not defined.'
    }
    if (-not $Env:MATLAB_ROOT) {
        throw 'MATLAB_ROOT is not defined.'
    }
    $javaVersion = if ($Env:JAVA_VERSION) { $Env:JAVA_VERSION } else { '8' }
    $release = Get-NormalizedRelease -Release $Env:RELEASE
    $matlabRoot = $Env:MATLAB_ROOT
    $jrePath = 'C:\Program Files\Eclipse Adoptium\jre-{0}' -f $javaVersion

    $zipPath = Get-Jre -JavaVersion $javaVersion
    Install-Jre -ZipPath $zipPath -JrePath $jrePath
    Set-MatlabJre -Release $release -MatlabRoot $matlabRoot -JrePath $jrePath

    Write-Output "Adoptium JRE $javaVersion installed to $jrePath"
    Write-LicenseInfo -JavaVersion $javaVersion -JrePath $jrePath
}

# Run only when executed directly (dot-sourcing loads the functions for tests).
if ($MyInvocation.InvocationName -ne '.') {
    Invoke-Main
}
