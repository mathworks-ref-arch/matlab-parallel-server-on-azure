<#
.SYNOPSIS
    Configures MATLAB for use, including the setup of licensing.

.DESCRIPTION
    Configures MATLAB for use, including the setup of licensing.
    Additional MATLAB configurations can be added here to be executed during the MATLAB VM instance creation in the ARM template deployment process.

.PARAMETER MATLABRoot
    (Required) Root folder for MATLAB.

.PARAMETER MLMLicenseFile
    (Optional) The path to the MATLAB license file. If no value is specified, MATLAB will be configured to use online licensing.

.EXAMPLE
    Set-MATLAB -MATLABRoot "<MATLAB_ROOT_FOLDER>" -MLMLicenseFile "<PATH_TO_MATLAB_LICENSE_FILE>"

.NOTES
    Copyright 2022-2025 The MathWorks, Inc.
#>


function Set-MATLABLicense{

    param(
        [Parameter(Mandatory = $true)]
        [string] $MATLABRoot,

        [Parameter()]
        [string] $MLMLicenseFile
    )

    Write-Output 'Starting Set-MATLABLicense...'

    If ($MATLABRoot -and ($MLMLicenseFile -match '\d+@.+')) {
        Write-Output 'License MATLAB using Network License Manager'
        $OnlineLicensePath = "$MATLABRoot\licenses\license_info.xml"
        If (Test-Path $OnlineLicensePath) { Remove-Item $OnlineLicensePath }

        $Port, $Hostname = $MLMLicenseFile.split('@')
        $LicenseContent = "SERVER $Hostname 123456789ABC $Port`r`nUSE_SERVER"
        $LicenseRoot = "$MATLABRoot\licenses"
        If (-not (Test-Path $LicenseRoot)) { New-Item -Path $LicenseRoot -ItemType Directory }

        Set-Content -Path "$LicenseRoot\network.lic" -Value $LicenseContent -NoNewline
    }
    Else {
        Write-Output 'License MATLAB using Online Licensing'
    }
}

function Set-MATLAB {
    param(
        [Parameter(Mandatory = $true)]
        [string] $MATLABRoot,

        [Parameter()]
        [string] $MLMLicenseFile
    )

    Set-MATLABLicense -MATLABRoot $MATLABRoot -MLMLicenseFile $MLMLicenseFile
}

try {
    Set-MATLAB -MATLABRoot $Env:MATLABRoot -MLMLicenseFile $Env:MLMLicenseFile
}
catch {
    $ScriptPath = $MyInvocation.MyCommand.Path
    Write-Output "ERROR - An error occurred while running script '20_Setup-MATLAB': $ScriptPath. Error: $_"
    throw
}
