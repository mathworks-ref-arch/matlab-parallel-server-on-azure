# Copyright 2022-2026 The MathWorks, Inc.
# This file is sourced by powershell at launch of the virtual machine in user data.
# It defines all the environment variables required to startup properly.

$Env:MATLABRoot = (Get-Item (Get-Command matlab).Path).Directory.Parent.FullName
$Env:PolyspaceRoot = 'C:\PolyspaceServer'

$Env:MATLABRelease = ([xml](Get-Content "$Env:MATLABRoot\VersionInfo.xml")).MathWorks_version_info.release
$Env:ParallelToolBoxRoot = "$Env:MATLABRoot\toolbox\parallel\bin"
$Env:MJSDefFile = "$Env:ParallelToolBoxRoot\mjs_def.bat"

$Env:ClusterManagementDataFile = "$Env:ProgramFiles\MathWorks\cluster_management\data\cluster_management_data.json"
$Env:MJSBusyIdleScripts = "C:\mjs_status_scripts"

$Env:EbsVolume = Invoke-RestMethod -Headers @{"Metadata"="true"} -Method GET -Uri "http://169.254.169.254/metadata/instance/compute/storageProfile/dataDisks?api-version=2021-02-01&format=text"
If ($Env:EbsVolume) {
    If (Get-Volume | Where-Object FileSystemLabel -eq "Data") {
        $DriveLetter = Get-Volume | Where-Object FileSystemLabel -eq "Data" | Select-Object -Last 1 -ExpandProperty DriveLetter
    } Else {
        # Disk is not mounted yet, finding next available DriveLetter
        $DriveLetter = [char]([int](Get-Volume | Sort-Object DriveLetter | Select-Object -Last 1 -ExpandProperty DriveLetter) + 1)
    }
    $Env:CheckpointRoot = "${DriveLetter}:\MJS\Checkpoint"
} Else {
    $Env:CheckpointRoot = "$Env:ProgramData\MJS\Checkpoint"
}

$Env:SecurityRoot = "$Env:CheckpointRoot\security"
$Env:SecretFile = "$Env:SecurityRoot\secret"
$Env:CertFile = "$Env:SecurityRoot\cert"
$Env:MJSAdminPasswordFile = "$Env:SecurityRoot\initial_admin_password"

$Env:ResourceID = Invoke-RestMethod -Headers @{"Metadata"="true"} -Method GET -Uri "http://169.254.169.254/metadata/instance/compute/resourceId?api-version=2021-02-01&format=text"
$Env:LocalIPv4 = Invoke-RestMethod -Headers @{"Metadata"="true"} -Method GET -Uri "http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0/privateIpAddress?api-version=2021-02-01&format=text"
$Env:LocalHostname = Invoke-RestMethod -Headers @{"Metadata"="true"} -Method GET -Uri "http://169.254.169.254/metadata/instance/compute/osProfile/computerName?api-version=2021-02-01&format=text"
$Env:PublicIPv4 = (Invoke-RestMethod -Headers @{Metadata="true"} -Uri "http://169.254.169.254/metadata/loadbalancer?api-version=2020-10-01").loadbalancer.publicIpAddresses[0].frontendIpAddress
