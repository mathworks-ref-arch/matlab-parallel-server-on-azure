<#
.SYNOPSIS
    Turns on strict Authenticode signature verification (CVE-2013-3900).

.DESCRIPTION
    Sets the EnableCertPaddingCheck registry value for 64-bit and 32-bit applications. Windows treats a signed file with extra content outside its signature as unsigned.

.EXAMPLE
    Enable-CertPaddingCheck

.LINK
    https://msrc.microsoft.com/update-guide/vulnerability/CVE-2013-3900

.NOTES
    Copyright 2026 The MathWorks, Inc.
    The $ErrorActionPreference variable is set to 'Stop' to ensure that any errors encountered during the function execution will cause the script to stop and throw an error.
#>

function Enable-CertPaddingCheck {
    Write-Output 'Starting Enable-CertPaddingCheck...'

    $WintrustConfigKeys = @(
        'HKLM:\Software\Microsoft\Cryptography\Wintrust\Config',
        'HKLM:\Software\Wow6432Node\Microsoft\Cryptography\Wintrust\Config'
    )

    foreach ($Key in $WintrustConfigKeys) {
        if (-not (Test-Path $Key)) {
            New-Item -Path $Key -Force | Out-Null
        }

        New-ItemProperty -Path $Key -Name 'EnableCertPaddingCheck' -Value 1 -PropertyType DWord -Force | Out-Null
        Write-Output "Set EnableCertPaddingCheck on $Key"
    }

    Write-Output 'Done with Enable-CertPaddingCheck.'
}

try {
    $ErrorActionPreference = 'Stop'
    Enable-CertPaddingCheck
}
catch {
    $ScriptPath = $MyInvocation.MyCommand.Path
    Write-Output "ERROR - An error occurred while running script 'Enable-CertPaddingCheck': $ScriptPath. Error: $_"
    throw
}
