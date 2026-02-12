<#
.SYNOPSIS
    Configures required settings for MATLAB.

.DESCRIPTION
    Configures required settings for MATLAB.

.NOTES
    Copyright 2020-2025 The MathWorks, Inc.
    The $ErrorActionPreference variable is set to 'Stop' to ensure that any errors encountered during the function execution will cause the script to stop and throw an error.
#>

function Install-Certificates {
  [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', 'Install-Certificates')]
  param(
    [Parameter(Mandatory = $true)]
    [string] $Url
  )

  Write-Output 'Starting Install-Certificates ...'

  $WebRequest = [Net.WebRequest]::CreateHttp($Url)
  $WebRequest.AllowAutoRedirect = $true
  $Chain = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Chain
  [Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

  # Request website
  try {
    $WebRequest.GetResponse()
  }
  catch {
    Write-Output 'GetResponse() returned an error'
  }

  # Creates Certificate
  $Certificate = $WebRequest.ServicePoint.Certificate.Handle

  # Build chain
  $Chain.Build($Certificate)
  $Cert = $Chain.ChainElements[$Chain.ChainElements.Count - 1].Certificate
  $Bytes = $Cert.Export([Security.Cryptography.X509Certificates.X509ContentType]::Cert)
  Set-Content -Value $Bytes -Encoding byte -Path 'C:\Windows\Temp\mathworks_root_ca.cer'

  # Install the certificate
  Import-Certificate -FilePath 'C:\Windows\Temp\mathworks_root_ca.cer' -CertStoreLocation 'Cert:\LocalMachine\Root'

  # Cleanup
  [Net.ServicePointManager]::ServerCertificateValidationCallback = $null
  Remove-Item 'C:\Windows\Temp\mathworks_root_ca.cer'

  Write-Output 'Done with Install-Certificates.'
}


function Add-MATLABSecuritySettings {
  [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', 'Add-MATLABSecuritySettings')]
  param(
    [Parameter(Mandatory = $true)]
    [string] $Release
  )

  Write-Output 'Starting Add-MATLABSecuritySettings ...'

  Write-Output 'Set firewall rules for MATLAB'
  $MATLABExePath = Join-Path "$Env:MATLAB_ROOT" -ChildPath 'bin\win64\matlab.exe'
  $MATLABOLMExePath = Join-Path "$Env:MATLAB_ROOT" -ChildPath 'bin\win64\mw_olm.exe'
  New-NetFirewallRule -DisplayName "MATLAB $Release" -Name "MATLAB $Release" -Program "$MATLABExePath" -Action Allow
  # mw_olm executable removed in R2023b but needed for older releases
  New-NetFirewallRule -DisplayName 'mw_olm' -Name 'mw_olm' -Program "$MATLABOLMExePath" -Action Allow
  Add-MpPreference -ExclusionPath "$Env:MATLAB_ROOT"

  Write-Output 'Done with Add-MATLABSecuritySettings ...'
}


function Add-DesktopShortcut {

  param(
    [Parameter(Mandatory = $true)]
    [string] $Release
  )

  Write-Output 'Starting Add-DesktopShortcut ...'

  Write-Output 'Remove Azure VM desktop shortcuts.'

  $currentUser = [Environment]::UserName
  Remove-Item -Path "C:\Users\$currentUser\Desktop\*.website"

  Write-Output 'Add MATLAB shortcut in Desktop for all users.'
  Copy-Item -Path "$Env:ProgramData\Microsoft\Windows\Start Menu\Programs\MATLAB $Release\MATLAB $Release.lnk" -Destination 'C:\Users\Public\Desktop'

  Write-Output 'Done with Add-DesktopShortcut.'
}


function Initialize-MATLAB {
  param(
    [Parameter(Mandatory = $true)]
    [string] $Release
  )
  Add-MATLABSecuritySettings -Release $Release
  Install-Certificates -Url 'https://licensing.mathworks.com'
  Add-DesktopShortcut -Release $Release
}


try {
  $ErrorActionPreference = 'Stop'
  Initialize-MATLAB -Release $Env:RELEASE
}
catch {
  $ScriptPath = $MyInvocation.MyCommand.Path
  Write-Output "ERROR - An error occurred while running script 'Initialize-MATLAB': $ScriptPath. Error: $_"
  throw
}
