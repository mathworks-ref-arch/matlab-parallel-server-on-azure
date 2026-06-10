<#
.SYNOPSIS
    Configures the default DNS search suffix for Azure Windows VMs.
.DESCRIPTION
    Configures the DNS search suffix on Azure Windows VMs when a 
    custom DNS server is used in the VNET. Without this, Azure DHCP 
    assigns 'reddog.microsoft.com' as the default domain, causing short-name
    resolution (e.g. 'ping <hostname>') to fail with NXDOMAIN. 
    For more details, see:
    https://learn.microsoft.com/en-us/azure/virtual-network/virtual-networks-name-resolution-for-vms-and-role-instances?tabs=redhat#name-resolution-that-uses-your-own-dns-server
.NOTES
    Copyright 2026 The MathWorks, Inc.
#>

function Set-CustomDNSSuffix {
    param(
        [string]$CustomDNSSuffix
    )

    if ([string]::IsNullOrWhiteSpace($CustomDNSSuffix)) {
        Write-Output "CustomDNSSuffix parameter is empty or not set. Skipping DNS configuration."
        return
    }

    Write-Output "Setting DNS search suffix to: $CustomDNSSuffix"

    # Set the DNS suffix for all network adapters
    Write-Output "Setting DNS suffix for all network adapters"
    Get-NetAdapter | Where-Object {$_.Status -eq "Up"} | ForEach-Object {
        Set-DnsClient -InterfaceIndex $_.ifIndex -ConnectionSpecificSuffix $CustomDNSSuffix
        Write-Output "Set DNS suffix for adapter: $($_.Name) (Index: $($_.ifIndex))"
    }

    # Set the primary DNS suffix for the computer
    Write-Output "Setting primary DNS suffix for the computer"
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "Domain" -Value $CustomDNSSuffix
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "NV Domain" -Value $CustomDNSSuffix

    # Set the DNS suffix search list
    Write-Output "Setting DNS suffix search list"
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "SearchList" -Value $CustomDNSSuffix

    # Enable DNS suffix appending for short-name resolution
    Write-Output "Enabling DNS suffix appending"
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "UseDomainNameDevolution" -Value 1

    # Flush DNS cache to apply changes immediately
    Write-Output "Flushing DNS cache"
    Clear-DnsClientCache

    Write-Output "DNS configuration completed successfully"
}

try {
    Set-CustomDNSSuffix -CustomDNSSuffix $Env:CustomDNSSuffix
}
catch {
    Write-Output "Failed to configure DNS: $_"
    throw
}
