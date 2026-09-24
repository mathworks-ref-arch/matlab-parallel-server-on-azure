<#
.SYNOPSIS
    Cleans up residual files remaining from Packer build.
.DESCRIPTION
    This script serves as the final step in the VHD building process, responsible for cleaning up residual files created during the Packer build.
.EXAMPLE
    Remove-TemporaryFiles
.NOTES
    Copyright 2024-2026 The MathWorks, Inc.
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

function Remove-DotNet6Runtimes {
    Write-Output 'Starting Remove-DotNet6Runtimes...'

    # List of .NET 6 runtime folders to target
    $runtimeFolders = @(
        "$env:ProgramFiles\dotnet\shared\Microsoft.NETCore.App",
        "$env:ProgramFiles\dotnet\shared\Microsoft.AspNetCore.App",
        "$env:ProgramFiles (x86)\dotnet\shared\Microsoft.NETCore.App",
        "$env:ProgramFiles (x86)\dotnet\shared\Microsoft.AspNetCore.App"
    )

    foreach ($path in $runtimeFolders) {
        if (-not (Test-Path $path)) {
            Write-Output "Path not found: $path"
            continue
        }

        Get-ChildItem -Path $path -Directory | ForEach-Object {
            # Check if the directory name matches a .NET 6 version pattern (e.g., 6.0, 6.0.1)
            if ($_.Name -match '^6\.\d+(\.\d+)?$') {
                Write-Output "Removing .NET 6 runtime: $($_.FullName)"
                try {
                    Remove-Item -Path $_.FullName -Recurse -Force
                } catch {
                    Write-Output "WARNING: Failed to remove: $($_.FullName) - $_"
                }
            }
        }
    }

    Write-Output 'Done with Remove-DotNet6Runtimes.'
}


function Cleanup {
    Remove-SourceFiles -Path 'X:'
    Remove-TemporaryBuildFiles
    Remove-DotNet6Runtimes
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
