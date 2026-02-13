<#
.SYNOPSIS
    Configures Polyspace for use, including the setup of licensing.

.DESCRIPTION
    Configures Polyspace for use, including the setup of licensing.
    Additional Polyspace configurations can be added here to be executed during the VM instance creation in the ARM template deployment process.

.PARAMETER PolyspaceRoot
    (Required) Root folder for Polyspace.

.PARAMETER MLMLicenseFile
    (Optional) The path to the Polyspace license file. If no value is specified, Polyspace will be configured to use online licensing.

.EXAMPLE
    Set-Polyspace -PolyspaceRoot "<POLYSPACE_ROOT_FOLDER>" -MLMLicenseFile "<PATH_TO_POLYSPACE_LICENSE_FILE>"

.NOTES
    Copyright 2022-2025 The MathWorks, Inc.
#>

function Set-PolyspaceLicense{

    param(
        [Parameter(Mandatory = $true)]
        [string] $PolyspaceRoot,

        [Parameter()]
        [string] $MLMLicenseFile
    )

    Write-Output 'Starting PolyspaceLicense...'

    If ($PolyspaceRoot -and ($MLMLicenseFile -match '\d+@.+')) {
        Write-Output 'License Polyspace using Network License Manager'
        $OnlineLicensePath = "$PolyspaceRoot\licenses\license_info.xml"
        If (Test-Path $OnlineLicensePath) { Remove-Item $OnlineLicensePath }

        $Port, $Hostname = $MLMLicenseFile.split('@')
        $LicenseContent = "SERVER $Hostname 123456789ABC $Port`r`nUSE_SERVER"
        $LicenseRoot = "$PolyspaceRoot\licenses"
        If (-not (Test-Path $LicenseRoot)) { New-Item -Path $LicenseRoot -ItemType Directory }

        Set-Content -Path "$LicenseRoot\network.lic" -Value $LicenseContent -NoNewline
    }
    Else {
        Write-Output 'License Polyspace using Online Licensing'
    }
}

function Set-Polyspace {
    param(
        [Parameter(Mandatory = $true)]
        [string] $PolyspaceRoot,

        [Parameter()]
        [string] $MLMLicenseFile
    )

    Set-PolyspaceLicense -PolyspaceRoot $PolyspaceRoot -MLMLicenseFile $MLMLicenseFile
}

try {
    Set-Polyspace -PolyspaceRoot $Env:PolyspaceRoot -MLMLicenseFile $Env:MLMLicenseFile
}
catch {
    $ScriptPath = $MyInvocation.MyCommand.Path
    Write-Output "ERROR - An error occurred while running script '30_Setup-Polyspace': $ScriptPath. Error: $_"
    throw
}
