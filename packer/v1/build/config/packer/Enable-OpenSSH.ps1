<#
.SYNOPSIS
    Installs and configures the open ssh on Windows Server

.DESCRIPTION
    This script is meant to be run once during VM provisioning. However, this script can run safely multiple times without any unexpected side effects or requiring any invariants to be reset manually.

.EXAMPLE
    Enable-OpenSSh

.LINK
    https://docs.microsoft.com/en-us/windows-server/administration/openssh/openssh_install_firstuse

.NOTES
    Copyright 2024-2025 The MathWorks, Inc.
    The $ErrorActionPreference variable is set to 'Stop' to ensure that any errors encountered during the function execution will cause the script to stop and throw an error.
#>


function Enable-OpenSSh {

    Write-Output 'Starting Enable-OpenSSh...'

    # Print latest version of OpenSSH available
    Get-WindowsCapability -Online | Where-Object Name -Like 'OpenSSH*'
    $Name = (Get-WindowsCapability -Online | Where-Object Name -Like 'OpenSSH.Server*' | ForEach-Object { $_.Name })

    # Install the OpenSSH Server
    Add-WindowsCapability -Online -Name $Name

    # Start the sshd service
    Start-Service sshd

    # Optional, but recommended.
    Set-Service -Name sshd -StartupType 'Automatic'

    # Confirm the Firewall rule is configured. It should be created automatically by setup. Run the following to verify.
    if (!(Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue | Select-Object Name, Enabled)) {
        Write-Output "Firewall Rule 'OpenSSH-Server-In-TCP' does not exist, creating it..."
        New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
    }
    else {
        Write-Output "Firewall rule 'OpenSSH-Server-In-TCP' has been created and exists."
    }

    # Set PowerShell as default shell from OpenSSH.
    New-ItemProperty -Path 'HKLM:\SOFTWARE\OpenSSH' -Name DefaultShell -Value 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -PropertyType String -Force

    Write-Output 'Done with Enable-OpenSSh.'
}



try {
    $ErrorActionPreference = 'Stop'
    Enable-OpenSSh
}
catch {
    $ScriptPath = $MyInvocation.MyCommand.Path
    Write-Output "ERROR - An error occurred while running script 'Enable-OpenSSh': $ScriptPath. Error: $_"
    throw
}
