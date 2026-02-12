<#
.SYNOPSIS
    Initializes and formats raw data disks on the system.

.DESCRIPTION
    This script is designed to initialize and format raw data disks on the system. The script is intended to be used in the setup process for MATLAB configurations.

.NOTES
    Copyright 2022-2025 The MathWorks, Inc.
#>


function Setup-Disk {
    Stop-Service -Name ShellHWDetection

    # Mount data disks
    Get-Disk |
    Where-Object PartitionStyle -eq 'raw' |
    Initialize-Disk -PartitionStyle MBR -PassThru |
    New-Partition -AssignDriveLetter -UseMaximumSize |
    Format-Volume -FileSystem NTFS -NewFileSystemLabel 'Data' -Confirm:$false

    Start-Service -Name ShellHWDetection
}

try {
    Setup-Disk
}
catch {
    $ScriptPath = $MyInvocation.MyCommand.Path
    Write-Output "ERROR - An error occurred while running script '10_Setup-Disk': $ScriptPath. Error: $_"
    throw
}
