<#
.SYNOPSIS
    Sets up the hostname configuration for cluster headnode and worker nodes based on public or private connectivity.

.DESCRIPTION
    Sets up the hostname configuration for cluster headnode and worker nodes based on public or private connectivity.
    Determines external and internal hostnames based on network configuration and node type.
    ExternalHostname: Hostname visible to MATLAB clients while connecting to the cluster
    InternalHostname: Hostname visible to the cluster nodes for intra-cluster communication.
    The variables set in this script are sourced by the user-data script for headnode and cluster node VMs.

.NOTES
    Copyright 2026 The MathWorks, Inc.
#>

# Initialize both hostnames to local hostname
$Env:ExternalHostname = $Env:LocalHostname
$Env:InternalHostname = $Env:LocalHostname

if ($Env:PublicIPv4) {
    # Public IP Enabled: Use Azure Public FQDN for external, local hostname for internal
    if ($Env:NodeType -eq 'worker') {
        $InstanceID = $Env:ResourceID.Split('/')[-1]
        $Location = Invoke-RestMethod -Headers @{"Metadata"="true"} -Method GET -Uri "http://169.254.169.254/metadata/instance/compute/location?api-version=2021-02-01&format=text"
        $Env:ExternalHostname = "vm${InstanceID}.${Env:DomainNameLabel}.${Location}.cloudapp.azure.com"
    } else {
        $Env:ExternalHostname = $Env:HeadnodeHostname
    }
}
elseif ($Env:CustomDNSSuffix) {
    # Private Network with Custom DNS: Use FQDN for both
    $FQDN = "${Env:LocalHostname}.${Env:CustomDNSSuffix}"
    $Env:ExternalHostname = $FQDN
    $Env:InternalHostname = $FQDN
}
elseif ($Env:MATLABRelease -gt "R2022b") {
    # Private Network without DNS (R2023a+): Use IP addresses
    $Env:ExternalHostname = $Env:LocalIPv4
    $Env:InternalHostname = $Env:LocalIPv4
}
