<#
.SYNOPSIS
createFileShare:     Create a file share in an existing storage account

# Copyright 2018 The MathWorks, Inc.

.DESCRIPTION
Usage:               createFileShare [-StorageAccountName storage_account_name]
                                     [-StorageAccountKey storage_account_key]
                                     [-ShareName share_name]
                                     [-ShareQuota share_quota]

-StorageAccountName  Name of the storage account in which to create the file share.

-StorageAccountKey   Key to the storage account in which to create the file share.

-ShareName           Name of the file share to create.

-ShareQuota          Optional. Specifies the maximum size of the share in GB. Must be greater than 0,
                     and less than or equal to 5TB(5120).

.EXAMPLE
createFileShare -StorageAccountName myAccount -StorageAccountKey exampleKey== -ShareName myShare -ShareQuota 100
#>

Param (
    [Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$StorageAccountName,
    [Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$StorageAccountKey,
    [Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$ShareName,
    [Parameter(Mandatory=$False)][ValidateRange(0, 5120)][string]$ShareQuota
)

$Version = "2015-12-11"

$Url = "https://$StorageAccountName.file.core.windows.net/${ShareName}?restype=share";

$Date = (Get-Date).ToUniversalTime()
$Datestr = $Date.ToString("R");

$StrToSign = "PUT`n`n`n`n`n`n`n`n`n`n`n`nx-ms-date:$Datestr"
If ($PSBoundParameters.ContainsKey('ShareQuota')) {
    $StrToSign = $StrToSign + "`nx-ms-share-quota:$ShareQuota"
}
$StrToSign = $StrToSign + "`nx-ms-version:$Version"
$StrToSign = $StrToSign + "`n/${StorageAccountName}/${ShareName}"
$StrToSign = $StrToSign + "`nrestype:share"
 
[byte[]]$DataBytes = ([System.Text.Encoding]::UTF8).GetBytes($StrToSign)
$Hmacsha256 = New-Object System.Security.Cryptography.HMACSHA256
$Hmacsha256.Key = [Convert]::FromBase64String($StorageAccountKey)
$Sig = [Convert]::ToBase64String($Hmacsha256.ComputeHash($DataBytes))
$AuthHdr = "SharedKey ${StorageAccountName}:$Sig"
  
$RequestHeader = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
 
$RequestHeader.Add("Authorization", $AuthHdr)
$RequestHeader.Add("x-ms-date", $Datestr)
$RequestHeader.Add("x-ms-version", $Version)
If ($PSBoundParameters.ContainsKey('ShareQuota')) {
    $RequestHeader.Add("x-ms-share-quota", $ShareQuota)
}
$RequestHeader.Add("Content-Length", "0")
 
$Response = New-Object PSObject
$Response = (Invoke-RestMethod -Uri $Url -Method put -Headers $RequestHeader)