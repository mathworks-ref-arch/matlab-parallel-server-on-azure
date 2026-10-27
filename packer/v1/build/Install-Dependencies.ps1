<#
.SYNOPSIS
    Installs dependencies for the reference architecture features.
.DESCRIPTION
    The Install-Dependencies function installs the required dependencies for the resultant Azure Image.
.PARAMETER PythonInstallerUrl
    The URL for Python 64-bit installer.
.PARAMETER EdgeInstallerUrl
    The URL for the Microsoft Edge Enterprise 64-bit installer.
.NOTES
    Copyright 2024-2026 The MathWorks, Inc.
    The $ErrorActionPreference variable is set to 'Stop' to ensure that any errors encountered during the function execution will cause the script to stop and throw an error.
#>

function Install-AzCLI {
    Write-Output 'Starting Install-AzCLI...'
    Invoke-WebRequest -Uri https://aka.ms/installazurecliwindowsx64 -OutFile .\AzureCLI.msi
    Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'
    Remove-Item .\AzureCLI.msi
    Write-Output 'Done with Install-AzCLI.'
}

function Install-Python {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PythonInstallerUrl
    )

    Write-Output 'Starting Install-Python...'

    Invoke-WebRequest -Uri $PythonInstallerUrl -OutFile "$Env:TEMP\python-installer.exe"

    Write-Output 'Python Installer downloaded successfully. Installing ...'

    Start-Process "$Env:TEMP\python-installer.exe" -Wait -ArgumentList '/quiet InstallAllUsers=1 TargetDir="C:\Program Files\Python"'

    Remove-Item "$Env:TEMP\python-installer.exe"

    Write-Output 'Done with Install-Python.'
}

function Install-EdgeBrowser {
    param(
        [Parameter(Mandatory = $true)]
        [string] $EdgeInstallerUrl
    )

    Write-Output 'Starting Install-EdgeBrowser...'

    $InstallerFile = "$Env:TEMP\MicrosoftEdgeEnterpriseX64.msi"
    (New-Object System.Net.WebClient).DownloadFile($EdgeInstallerUrl, $InstallerFile)

    Write-Output 'Edge installer downloaded successfully. Installing ...'

    $Installer = Start-Process msiexec.exe -Wait -PassThru -ArgumentList "/i `"$InstallerFile`" /quiet /norestart"

    # Exit code 3010 means the install succeeded and needs a restart, which the build does later.
    if ($Installer.ExitCode -ne 0 -and $Installer.ExitCode -ne 3010) {
        throw "Edge installation failed with exit code $($Installer.ExitCode)."
    }

    Remove-Item $InstallerFile

    $EdgeExecutable = @(
        "${Env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
        "$Env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not $EdgeExecutable) {
        throw 'msedge.exe not found after installing Edge.'
    }

    Write-Output "Edge version in this image: $((Get-Item $EdgeExecutable).VersionInfo.ProductVersion)"

    Write-Output 'Done with Install-EdgeBrowser.'
}

function Install-MPM {
    # As a best practice, installing the latest version of mpm before calling it.
    Write-Output 'Installing mpm ...'
    Invoke-WebRequest -OutFile "$Env:TEMP\mpm.exe" -Uri 'https://www.mathworks.com/mpm/win64/mpm'
    Write-Output 'Done with installing mpm.'
}

function Install-Dependencies {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', 'Install-Dependencies')]
    param(
        [Parameter(Mandatory = $true)]
        [string] $PythonInstallerUrl,

        [Parameter(Mandatory = $true)]
        [string] $EdgeInstallerUrl
    )

    Install-EdgeBrowser -EdgeInstallerUrl $EdgeInstallerUrl
    Install-AzCLI
    Install-Python -PythonInstallerUrl $PythonInstallerUrl
    Install-MPM
}


try {
    $ErrorActionPreference = 'Stop'

    Install-Dependencies -PythonInstallerUrl "$Env:PYTHON_INSTALLER_URL" -EdgeInstallerUrl "$Env:EDGE_INSTALLER_URL"
}
catch {
    $ScriptPath = $MyInvocation.MyCommand.Path
    Write-Output "ERROR - An error occurred while running script 'Install-Dependencies': $ScriptPath. Error: $_"
    throw
}
