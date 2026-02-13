<#
.SYNOPSIS
    Initialize the source location for installing products from source via MPM.

.LINK
    https://github.com/mathworks-ref-arch/matlab-dockerfile/blob/main/MPM.md

.DESCRIPTION
    Initialize the source location for installing products from source via MPM. The script is also responsible for mounting the external SMB File Share with MATLAB installation files into a local drive.

.PARAMETER RemoteSourceLocation
    Location containing the source files for MATLAB/Polyspace installation.

.PARAMETER LocalSourcePath
    Local path where the remote source location should be mounted.

.NOTES
    Copyright 2024-2025 The MathWorks, Inc.
#>

function Initialize-SourceLocation {
    # Initializes a given local path by downloading required installation files from a remote source location
    param(
        [Parameter(Mandatory = $false)]
        [string] $RemoteSourceLocation,

        [Parameter(Mandatory = $false)]
        [string] $LocalSourcePath = 'X:'
    )

    if ([string]::IsNullOrEmpty($RemoteSourceLocation)) {
        Write-Output 'No source location provided.'
        return
    }

    if (Test-path -Path $LocalSourcePath) {
        Write-Output 'Source location already initialized.'
        return
    }

    # Dot-sourcing the Mount-MATLABSource script
    . 'C:\Windows\Temp\config\matlab\Mount-MATLABSource.ps1'

    # Call Mount-MATLABSource function to mount the SMB File Share containing MATLAB installation files
    Mount-MATLABSource -SourceLocation "$RemoteSourceLocation" -FileShareAlias "MATLABFILESHAREUSERNAME" -ShareKeyAlias "MATLABFILESHAREPASSWORD" -AzureKeyVault "$Env:AZURE_KEY_VAULT" -DriveToMount "$LocalSourcePath"

    if (-not (Test-path -Path $LocalSourcePath)) {
        throw 'Unable to initialize the given source location.'
    }
}

try {
    $ErrorActionPreference = 'Stop'
    Initialize-SourceLocation -RemoteSourceLocation "$Env:MATLAB_SOURCE_LOCATION"  -LocalSourcePath 'X:'
}
catch {
    $ScriptPath = $MyInvocation.MyCommand.Path
    Write-Output "ERROR - An error occurred while running script 'Initialize-SourceLocation': $ScriptPath. Error: $_"
    throw
}
