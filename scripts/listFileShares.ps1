<#
.SYNOPSIS
listFileShares:     List all file shares in an existing storage account

# Copyright 2018 The MathWorks, Inc.

.DESCRIPTION
Usage:               listFileShares [-StorageAccountName storage_account_name]
                                    [-StorageAccountKey storage_account_key]

-StorageAccountName  Name of the storage account.

-StorageAccountKey   Key to the storage account.

.EXAMPLE
listFileShares -StorageAccountName myAccount -StorageAccountKey exampleKey==
#>

Param (
    [Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$StorageAccountName,
    [Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$StorageAccountKey
)

$Version = "2017-04-17"

$Url = "https://$StorageAccountName.file.core.windows.net/?comp=list";

$Date = (Get-Date).ToUniversalTime()
$Datestr = $Date.ToString("R");

$StrToSign = "GET`n`n`n`n`n`n`n`n`n`n`n`nx-ms-date:$Datestr"
$StrToSign = $StrToSign + "`nx-ms-version:$Version"
$StrToSign = $StrToSign + "`n/${StorageAccountName}/${ShareName}"
$StrToSign = $StrToSign + "`ncomp:list"
 
[byte[]]$DataBytes = ([System.Text.Encoding]::UTF8).GetBytes($StrToSign)
$Hmacsha256 = New-Object System.Security.Cryptography.HMACSHA256
$Hmacsha256.Key = [Convert]::FromBase64String($StorageAccountKey)
$Sig = [Convert]::ToBase64String($Hmacsha256.ComputeHash($DataBytes))
$AuthHdr = "SharedKey ${StorageAccountName}:$Sig"
  
$RequestHeader = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
 
$RequestHeader.Add("Authorization", $AuthHdr)
$RequestHeader.Add("x-ms-date", $Datestr)
$RequestHeader.Add("x-ms-version", $Version)
 
$Response = (Invoke-RestMethod -Uri $Url -Method get -Headers $RequestHeader)
[xml]$ResponseXml = $Response.Substring($Response.IndexOf("<"))
If($ResponseXml) {
    $Shares = $ResponseXml.EnumerationResults.Shares.Share
    Return $Shares
}
Return @()