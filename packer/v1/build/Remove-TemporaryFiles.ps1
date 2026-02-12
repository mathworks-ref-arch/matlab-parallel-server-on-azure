<#
.SYNOPSIS
    Cleans up residual files remaining from Packer build.
.DESCRIPTION
    This script serves as the final step in the VHD building process, responsible for cleaning up residual files created during the Packer build.
.EXAMPLE
    Remove-TemporaryFiles
.NOTES
    Copyright 2024-2025 The MathWorks, Inc.
    The $ErrorActionPreference variable is set to 'Stop' to ensure that any errors encountered during the function execution will cause the script to stop and throw an error.
#>

function Remove-TemporaryBuildFiles {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', 'Remove-TemporaryBuildFiles')]
    param()

    Write-Output 'Cleaning up leftover files...'
    $TemporaryFiles = @(
        'C:\Windows\Temp\packer-*.ps1',
        'C:\Windows\Temp\script-*.ps1',
        'C:\Windows\Temp\config',
        'C:\Windows\Temp\runtime',
        'C:\Windows\Temp\startup',
        "$ENV:USERPROFILE\.azure",
        "$Env:TEMP\mpm.exe"
    )

    foreach ($Path in $TemporaryFiles) {
        if (Test-Path $Path) {
            Remove-Item $Path -Force -Recurse
        }
    }

    Write-Output 'Cleanup completed.'
}

function Remove-SourceFiles {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', 'Remove-SourceFiles')]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    if (Test-Path -Path $Path) {
        Remove-SmbMapping -LocalPath "$Path" -Force -UpdateProfile
    }
}


function Cleanup {
    Remove-SourceFiles -Path 'X:'
    Remove-TemporaryBuildFiles
}

try {
    $ErrorActionPreference = 'Stop'
    Cleanup
}
catch {
    $ScriptPath = $MyInvocation.MyCommand.Path
    Write-Output "ERROR - An error occurred while running script 'Remove-TemporaryFiles': $ScriptPath. Error: $_"
    throw
}
