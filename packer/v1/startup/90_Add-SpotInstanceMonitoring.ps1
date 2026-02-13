<#
.SYNOPSIS
    Creates a task to monitor spot VM interruptions and stop all workers on the worker before VM termination.

.DESCRIPTION
    Creates a task to monitor spot VM interruptions and stop all workers on the worker before VM termination.

.NOTES
    Copyright 2024-2025 The MathWorks, Inc.
#>

function Add-SpotInstanceMonitoringTask {

    Write-Output 'Creating a task to monitor spot VM interruptions and stop all workers on the worker before VM termination.'

    $TaskName = 'Handle Spot Worker command on VM Interruption.'
    $TaskCommand = "cmd /c '$Env:ProgramFiles\MathWorks\cluster_management\spotinstances\handle_instance_interruption.py'"
    $StartTime = (Get-Date).AddMinutes(1).ToString('HH:mm')

    Write-Output 'Creating task ...'

    schtasks /create /tn $TaskName /sc once /st $StartTime /tr $TaskCommand /ru System

    Write-Output 'Task created successfully'
}


try {
    if (($Env:NodeType -eq 'worker') -and ($Env:UseSpotInstance -eq 'Yes')) {
        Add-SpotInstanceMonitoringTask
    }
}
catch {
    $ScriptPath = $MyInvocation.MyCommand.Path
    Write-Output "ERROR - An error occurred while running script '90_Add-SpotInstanceMonitoring': $ScriptPath. Error: $_"
    throw
}
