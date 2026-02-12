<#
.SYNOPSIS
    Startup script to configure the cluster management program that handles termination policies and autoscaling for the Parallel Server Cluster.

.DESCRIPTION
    This script uses the user preferences for auto-termination of the Parallel Server Cluster that are set as environment variables and configures the Cluster Management Program accordingly. It creates a scheduled task for the cluster management program to run in the head node every minute.

    A scheduled task is created to run the user-data in the head-node on every boot. Running the userdata starts and configures MJS.

.NOTES
    Copyright 2024-2025 The MathWorks, Inc.
#>

function Register-ScheduledTaskIfNotAvailable {
    param(
        [string]$TaskName,
        [Microsoft.Management.Infrastructure.CimInstance]$Action,
        [Microsoft.Management.Infrastructure.CimInstance]$Trigger,
        [Microsoft.Management.Infrastructure.CimInstance]$Settings = $null
    )

    $OptionalParams = @{}
    if ($null -ne $Settings) {
        $OptionalParams['Settings'] = $Settings
    }

    try {
        Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop 2>$null
        Write-Output "The task $TaskName already exists"
    }
    catch {
        Write-Output "Creating task: $TaskName"

        Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -User 'SYSTEM' -RunLevel Highest @optionalParams

        Write-Output "The task $TaskName has been created."
    }
}


function Initialize-ClusterManagementProgram {
    param(
        [string]$TerminationPolicy,
        [string]$ClusterManagementDataFile,
        [string]$DesiredCapacity,
        [string]$MJSStatusLogFile
    )

    Write-Output 'Initializing the cluster management program data file...'

    # Set AutoTerminationFlag as true if user's choice is anything other than 'Disable auto-termination'
    $AutoTerminationFlag = $TerminationPolicy -ne 'Disable auto-termination'

    # Override termination policy to 'never' if auto-termination is disabled
    if ($TerminationPolicy -eq 'Disable auto-termination') {
        $TerminationPolicy = 'never'
    }

    # Read the cluster management data file into a PowerShell object
    $ClusterManagementProgramData = Get-Content -Path $ClusterManagementDataFile -Raw | ConvertFrom-Json

    $ConfigValues = @{
        'initial_desired_capacity'   = $DesiredCapacity
        'initial_termination_policy' = $TerminationPolicy
        'mjs_status_log_file'        = $MJSStatusLogFile
        'autotermination_enabled'    = $AutoTerminationFlag
    }

    # Update the config properties
    foreach ($key in $ConfigValues.Keys) {
        $ClusterManagementProgramData.config.$key = $ConfigValues[$key]
    }

    $ClusterManagementProgramData.state.last_termination_policy = $TerminationPolicy

    # Convert the object back to a JSON string
    $ClusterManagementProgramDataJSON = $ClusterManagementProgramData | ConvertTo-Json

    # Write the JSON string back to the file
    Set-Content -Path $ClusterManagementDataFile -Value $ClusterManagementProgramDataJSON

    Write-Output 'Initialization complete. Setting up a scheduled task to run the cluster management program in the head node...'

    # Creating a scheduled task to run the cluster management program every minute in the head-node
    $ClusterManagementProgramTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 1)
    $ClusterManagementProgramAction = New-ScheduledTaskAction -Execute 'cmd.exe' -Argument "/c `"$Env:ProgramFiles\MathWorks\cluster_management\cluster_management.py`""
    Register-ScheduledTaskIfNotAvailable -TaskName 'Cluster management Task for MATLAB Parallel Server' -Action $ClusterManagementProgramAction -Trigger $ClusterManagementProgramTrigger
}

function Set-UserdataTask {
    # Creating a scheduled task that will execute user-data on every boot of the VM.
    Write-Output 'Creating a scheduled task to run user-data on every boot of the head-node...'
    $RunUserDataTrigger = New-ScheduledTaskTrigger -AtStartup
    $RunUserDataTaskSettings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RunOnlyIfNetworkAvailable
    $RunUserDataAction = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-ExecutionPolicy Bypass -Command `"`$userDataEncoded = (Invoke-RestMethod -Headers @{`'Metadata`'=`'true`'} -Method GET -Uri `'http://169.254.169.254/metadata/instance/compute/userData?api-version=2021-01-01&format=text`'); `$userData = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(`$userDataEncoded)); `$scriptBlock = [scriptblock]::Create(`$userData); Invoke-Command -ScriptBlock `$scriptBlock`""
    Register-ScheduledTaskIfNotAvailable -TaskName 'RunUserDataAtStartup' -Action $RunUserDataAction -Trigger $RunUserDataTrigger -Settings $RunUserDataTaskSettings
}


try {
    if ($Env:NodeType -eq 'headnode') {
        Initialize-ClusterManagementProgram -TerminationPolicy $Env:TerminationPolicy -ClusterManagementDataFile $Env:ClusterManagementDataFile -DesiredCapacity $Env:DesiredCapacity -MJSStatusLogFile $Env:MJSStatusLogFile

        Set-UserdataTask
    }
}
catch {
    $ScriptPath = $MyInvocation.MyCommand.Path
    Write-Output "ERROR - An error occurred while running script '80_Initialize-ClusterManagementProgram': $ScriptPath. Error: $_"
    throw
}
