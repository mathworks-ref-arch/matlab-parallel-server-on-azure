# Copyright 2022-2026 The MathWorks, Inc.
# This file is sourced by powershell at launch of the virtual machine in user data.
# It defines all the environment variables required to startup properly.

$Env:MATLABRoot = (Get-Item (Get-Command matlab).Path).Directory.Parent.FullName
$Env:PolyspaceRoot = 'C:\PolyspaceServer'

$Env:MATLABRelease = ([xml](Get-Content "$Env:MATLABRoot\VersionInfo.xml")).MathWorks_version_info.release
$Env:ParallelToolBoxRoot = "$Env:MATLABRoot\toolbox\parallel\bin"
$Env:MJSDefFile = "$Env:ParallelToolBoxRoot\mjs_def.bat"

$Env:MJSStatusLogFile = "$Env:ProgramData\MathWorks\mjs_status_transitions.log"
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

If (-not $Env:PublicIPv4) {
    Write-Output 'This reference architecture requires public IP addresses.'
    Exit 1
}

# Determine the public FQDN for workers and headnode
# DomainNameLabel used for the workers is set in the ARM template
If ("$Env:NodeType" -eq 'worker') {
    # Resource IDs for VMSS instances are of the form:
    # /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<RESOURCE_GROUP>/providers/Microsoft.Compute/virtualMachineScaleSets/<VMSS_NAME>/virtualMachines/<INSTANCE_ID>
    $InstanceID = $Env:ResourceID.Split('/')[-1]
    $Location = Invoke-RestMethod -Headers @{"Metadata"="true"} -Method GET -Uri "http://169.254.169.254/metadata/instance/compute/location?api-version=2021-02-01&format=text"

    # FQDNs for Public IPv4 addresses follow this format
    # Source: https://learn.microsoft.com/en-us/azure/virtual-network/ip-services/public-ip-addresses#domain-name-label
    $Env:ExternalHostName = "vm${InstanceID}.${Env:DomainNameLabel}.${Location}.cloudapp.azure.com"
} else {
    $Env:ExternalHostName = $Env:HeadnodeHostname
}
