<#
.SYNOPSIS
startmjs:                 Configure the current VM as part of an MJS cluster

# Copyright 2018 The MathWorks, Inc.

.DESCRIPTION
Usage:                    startmjs [-Role vm_role]
                                   [-NumWorkers number_of_workers]
                                   [-ClusterName mjs_name]
                                   [-StorageAccountName storage_account_name]
                                   [-StorageAccountKey storage_account_key]
                                   [-HeadnodeInternalHostname headnode_internal_hostname]
                                   [-HeadnodeExternalHostname headnode_external_hostname]
                                   [-HeadnodeInternalIPAddress headnode_internal_ip_address]

-Role                      Role of VM in MJS cluster. Allowed values are "headnode" or "worker".
                           Only a single headnode VM is allowed.

-NumWorkers                Number of worker processes to start on VM. To select as many workers as
                           cores on the VM select -1.

-ClusterName               Name of the MJS scheduler service. If the role is "headnode" a job manager
                           service with this name will be started. Any worker processes started will 
                           attempt to connect to a job manager service with this name.

-StorageAccountName        Name of Storage Account to create File Share.

-StorageAccountKey         Key to Storage Account to create File Share.

-HeadnodeInternalHostname  The private internal hostname of the headnode VM.

-HeadnodeExternalHostname  The publicly visible external hostname of the headnode VM.

-HeadnodeInternalIPAddress The private internal ip address of the headnode VM.

.EXAMPLE
startmjs -Role worker -NumWorkers 2 -ClusterName myCluster
    -StorageAccountName store -StorageAccountKey exampleabcdef123456==
    -HeadnodeInternalHostname headnode -HeadnodeExternalHostname headnode.example.com
    -HeadnodeInternalIPAddress 10.0.0.4
#>

Param (
    [Parameter(Mandatory=$True)][ValidateSet('headnode','worker')][string]$Role,
    [Parameter(Mandatory=$True)][ValidateRange(-1, [int]::MaxValue)][string]$NumWorkers,
    [Parameter(Mandatory=$True)][string]$ClusterName,
    [Parameter(Mandatory=$True)][string]$StorageAccountName,
    [Parameter(Mandatory=$True)][string]$StorageAccountKey,
    [Parameter(Mandatory=$True)][string]$HeadnodeInternalHostname,
    [Parameter(Mandatory=$True)][string]$HeadnodeExternalHostname,
    [Parameter(Mandatory=$True)][string]$HeadnodeInternalIPAddress
)

Function StartTranscript() {
    $Datetimestr = (Get-Date).ToString('yyyy-MM-dd-HH-mm-ss')
    $Script:Logfile = "$Env:Windir\Temp\MDCSLog-$Datetimestr.log"
    Start-Transcript -Path $Script:Logfile -Force
}

Function StopTranscript() {
    Stop-Transcript
}

Function FindMatlabRoot() {
    $Computername = $Env:Computername
    $MatlabKey="SOFTWARE\\MathWorks\\MATLAB"
    $Reg=[microsoft.win32.registrykey]::OpenRemoteBaseKey('LocalMachine',$Computername) 
    $Regkey=$Reg.OpenSubKey($MatlabKey)
    If ($Regkey) {
        # MATLAB install found
        $Subkeys=$Regkey.GetSubKeyNames() 
        $Matlabroot = ""
        Foreach($Key In $Subkeys){
            $ThisKey=$MatlabKey + "\\" + $Key 
            $ThisSubKey=$Reg.OpenSubKey($ThisKey)
            $Thisroot = $ThisSubKey.GetValue("MATLABROOT")
            If($Matlabroot -lt $Thisroot) {
                $Matlabroot = $Thisroot
            }
        }
        Return $Matlabroot
    } Else {
        # Searching for attached volume with name "matlab" to use as matlab root.
        $Matlabvolume = Get-WmiObject win32_logicaldisk | Where-Object -FilterScript {$_.VolumeName -Eq "matlab"}
        $Matlabroot = $Matlabvolume.DeviceID
        Return $Matlabroot
    }
}

Function RunCommand() {
    Param(
    [Parameter(
        Position=0,
        Mandatory=$True,
        ValueFromPipeline=$True)
    ]
    [String[]]$Command
    )

    $Output = Invoke-Expression -Command "$Command"
    Echo $Output
    If($LASTEXITCODE -ne 0) {
        Throw "Error executing command ${Command}: $Output"
    }
}

Function GetPublicIP() {
    # Curl VM MetaData for public IP address
    $Url = "http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0/publicIpAddress?api-version=2017-04-02&format=text";
    
    $PollAttempts = 0
    While ($PollAttempts -lt 10) {
        $IpAddress = Invoke-RestMethod -Headers @{"Metadata"="true"} -URI $Url -Method get
        $PollAttempts ++
        # Test that the address given is valid, otherwise try again.
        Try {
            $ResolvedIP = [ipaddress]$IpAddress
            Return $IpAddress
        } Catch {
            Echo "Failed to resolve public ip address, $IpAddress"
        }
        Start-Sleep -s 5
    }
    Throw "Unable to obtain a valid public ip address using Azure VM metadata"
}

Function PollUntilTrue() {
    param(
        [Parameter(Mandatory=$True)]
        [scriptblock]
        $ScriptBlock,
        [Parameter(Mandatory=$False)]
        [int]
        $TimeoutMinutes = 30
    )
    # Poll for existence
    $PollPeriodSeconds = 10
    $MaxPollAttempts = (60 * $TimeoutMinutes)/$PollPeriodSeconds
    $PollAttempts = 0
    While ($PollAttempts -lt $MaxPollAttempts) {
        $Result = Invoke-Command -ScriptBlock $ScriptBlock
        If ($Result) {
            Return $True
        }
        Start-Sleep -s $PollPeriodSeconds;
        $PollAttempts ++
    }
    Return $False
}

Function WaitForPathToExist() {
    param(
        [Parameter(Mandatory=$True)]
        [string]
        $Path,
        [Parameter(Mandatory=$False)]
        [int]
        $TimeoutMinutes = 30
    )
    Echo "Waiting for $Path to exist ..."
    If (-Not (PollUntilTrue -TimeoutMinutes $TimeoutMinutes -ScriptBlock {Test-Path $Path})) {
        Throw "$Path does not exist after waiting for $TimeoutMinutes minutes. Unable to continue."
    }
}

Function DoesFileShareExist() {
    param(
        [Parameter(Mandatory=$True)]
        [string]
        $StorageAccountName,
        [Parameter(Mandatory=$True)]
        [string]
        $StorageAccountKey,
        [Parameter(Mandatory=$True)]
        [string]
        $FileShareName
    )
    $listFileSharesScript = Join-Path $PSScriptRoot "listFileShares.ps1"
    $Shares = . $listFileSharesScript -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey
    ForEach ($Share in $Shares) {
        If ($Share.Name -eq $FileShareName) {
            Return $True
        }
    }
    Return $False
}

Function WaitForFileShareToExist() {
    param(
        [Parameter(Mandatory=$True)]
        [string]
        $StorageAccountName,
        [Parameter(Mandatory=$True)]
        [string]
        $StorageAccountKey,
        [Parameter(Mandatory=$True)]
        [string]
        $FileShareName,
        [Parameter(Mandatory=$False)]
        [int]
        $TimeoutMinutes = 30
    )
    Echo "Waiting for $FileShareName File Share to exist ..."
    If (-Not (PollUntilTrue -TimeoutMinutes $TimeoutMinutes -ScriptBlock {DoesFileShareExist `
    -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey -FileShareName $FileShareName})) {
        Throw "$FileShareName File Share does not exist after waiting for $TimeoutMinutes minutes. Unable to continue."
    }
}

#******************************************************************************
# Script body
# Execution begins here
#******************************************************************************

# Set default behaviour to stop on error
$ErrorActionPreference = "Stop"

# Start logging output
StartTranscript
$Currentdir = $Pwd

# Log current user
$User = whoami
Echo "Current user is: $User"
# Log node type information
Echo "VM role is: $Role"

$ReleaseDate = "20180530"
$MHLMContext = "MDCS_Azure_${ReleaseDate}"
Echo "setenv MHLM_CONTEXT=$MHLMContext"
[Environment]::SetEnvironmentVariable("MHLM_CONTEXT", $MHLMContext, "Machine")

#******************************************************************************
# Configure network parameters
#******************************************************************************

# Log host information
$InternalHostname = Hostname
$ExternalIP = GetPublicIP
Echo "VM EXTERNAL IP is: $ExternalIP"
Echo "VM INTERNAL NAME is: $InternalHostname"
Echo "Headnode EXTERNAL NAME is: $HeadnodeExternalHostname"
Echo "Headnode INTERNAL NAME is: $HeadnodeInternalHostname"
Echo "Headnode INTERNAL IP Address is: $HeadnodeInternalIPAddress"

# Open all firewall ports. Rely on external network security group to protect subnet.
Echo "Configure firewall"
Get-NetFirewallRule | ?{$_.Name -like "RemoteSvcAdmin*"} | Enable-NetFirewallRule
New-NetFirewallRule -Name "mdcs_inbound" -DisplayName "mdcs_inbound" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 0-65535 -ErrorAction SilentlyContinue
New-NetFirewallRule -Name "mdcs_outbound" -DisplayName "mdcs_outbound" -Direction Outbound -Action Allow -Protocol TCP -LocalPort 0-65535 -ErrorAction SilentlyContinue

# Map headnode external hostname to internal hostname
$HostsFile = "$Env:Windir\System32\drivers\etc\hosts"
If (-Not (Select-String -Path $HostsFile -Pattern $HeadnodeExternalHostname)) {
    $HostsLine = "$HeadnodeInternalIPAddress`t$HeadnodeExternalHostname"
    Echo "Adding $HostsLine to hosts file: $HostsFile"
    Add-Content $HostsFile "$HostsLine"
}

# Set hostname override environment variables. The forces communication between MDCS services to use the
# internal addresses.
Echo "Override internal and external hostnames"
Echo "setenv MDCE_OVERRIDE_INTERNAL_HOSTNAME=$InternalHostname"
Echo "setenv MDCE_OVERRIDE_EXTERNAL_HOSTNAME=$ExternalIP"
[Environment]::SetEnvironmentVariable("MDCE_OVERRIDE_INTERNAL_HOSTNAME", $InternalHostname, "Machine")
[Environment]::SetEnvironmentVariable("MDCE_OVERRIDE_EXTERNAL_HOSTNAME", $ExternalIP, "Machine")

#******************************************************************************
# Configure external storage
#******************************************************************************

# Check for database disk, and if so mount it to M drive.
$CheckpointDir = "$Env:Windir\Temp\MDCE\Checkpoint"
$LogDir = "$Env:Windir\Temp\MDCE\Log"
$DBDriveLetter = "M"
$Disks = Get-Disk | Where partitionstyle -eq 'raw' | sort number
If ($Disks) {
    # Always mount the first data disk as the database. If more data disks are found, there is
    # no way of distinguishing which is which.
    $DBDisk = $Disks[0]
    $DBDriveLabel = "database"
    $DBDisk | 
    Initialize-Disk -PartitionStyle MBR -PassThru -Confirm:$False |
    New-Partition -UseMaximumSize -DriveLetter $DBDriveLetter |
    Format-Volume -FileSystem NTFS -NewFileSystemLabel $DBDriveLabel -Confirm:$False -Force -ErrorAction SilentlyContinue
}
If (Test-Path "${DBDriveLetter}:\") {
    # Set checkpoint directory to mounted disk
    $CheckpointDir = "${DBDriveLetter}:\MDCE\Checkpoint"
}

# If the headnode, create File Share. If a worker, wait for File Share to exist
$FileShareHost = "$StorageAccountName.file.core.windows.net"
$FileShareName = "shared"
$MountPath = "\\${FileShareHost}\$FileShareName"
If (0 -eq $Role.ToLower().CompareTo("headnode")) {
    # Create File Share if it does not already exist
    $FileShareAlreadyExists = DoesFileShareExist -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey -FileShareName $FileShareName
    If ($FileShareAlreadyExists -eq $False) {
        $CreateFileShareScript = Join-Path $PSScriptRoot "createFileShare.ps1"
        Echo "Creating file share: $FileShareName"
        . $CreateFileShareScript -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey -ShareName $FileShareName
    } Else {
        Echo "Using existing file share: $FileShareName"
    }
} Else {
    # Poll for existence of File Share
    WaitForFileShareToExist -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey -FileShareName $FileShareName -TimeoutMinutes 30
}

# Mount File Share
. cmdkey /add:$FileShareHost /user:Azure\$StorageAccountName /pass:$StorageAccountKey
. net use K: /delete
. net use K: $MountPath
[Environment]::SetEnvironmentVariable("SHARED_DRIVE", $MountPath, "Machine")

#******************************************************************************
# Create shared files
#******************************************************************************

# Change directory to MATLAB script bin
$Matlabroot = FindMatlabRoot
Echo "Using matlab root $Matlabroot"
$Mdcsdir = $Matlabroot + "\toolbox\distcomp\bin"
Set-Location $Mdcsdir

$SharedFolder = "K:\cluster"
If(-Not (Test-Path $SharedFolder)) {
    New-Item $SharedFolder -Type Directory -Force
}
$SharedSecretFile = Join-Path $SharedFolder "secret"
$SharedCertFile = Join-Path $SharedFolder "cert"
$SharedProfile = Join-Path $SharedFolder "$ClusterName.settings"
$LocalCertFile = "cert"
$LocalSharedSecretFile = "secret"

If (0 -eq $Role.ToLower().CompareTo("headnode")) {   
    If(-Not (Test-Path $SharedSecretFile)) {
        # Create shared secret for SSL connections
        Echo "Creating shared secret"
        $SharedSecretCommand = ".\createSharedSecret.bat -file $SharedSecretFile"
        Echo "RunCommand: $SharedSecretCommand"
        RunCommand $SharedSecretCommand
    }

    If(-Not (Test-Path $SharedCertFile)) {
        # Create client certificate
        Echo "Creating certificate"
        $GenerateCertificateCommand = ".\generateCertificate.bat -secretfile $SharedSecretFile -certfile $SharedCertFile"
        Echo "RunCommand: $GenerateCertificateCommand"
        RunCommand $GenerateCertificateCommand
    }

    If(-Not (Test-Path $SharedProfile)) {
        # Generate profile
        Echo "Creating cluster profile $SharedProfile"
        $CreateProfileCommand = ".\createProfile.bat -name $ClusterName -host $HeadnodeExternalHostname -outfile $SharedProfile -certfile $SharedCertFile"
        Echo "RunCommand: $CreateProfileCommand"
        RunCommand $CreateProfileCommand
    }
} Else {
    # Workers simply wait for the required files in File Share
    WaitForPathToExist -Path $SharedSecretFile -TimeoutMinutes 10
    WaitForPathToExist -Path $SharedCertFile -TimeoutMinutes 10
}

# Copy file Share items to local disk
Copy-Item $SharedSecretFile $LocalSharedSecretFile -Force
Copy-Item $SharedCertFile $LocalCertFile -Force 

#******************************************************************************
# Start Cluster
#******************************************************************************

# Uninstall any existing mdce service
Echo "Uninstall any existing mdce service"
$MdceUnInstallCommand = ".\mdce.bat uninstall -cleanPreserveJobs -disableelevate -checkpointbase $CheckpointDir"
Echo "RunCommand: $MdceUnInstallCommand"
RunCommand $MdceUnInstallCommand -ErrorAction SilentlyContinue

# Install mdce service
Echo "Install mdce service"
$MdceInstallCommand = ".\mdce.bat install -cleanPreserveJobs -disableelevate -checkpointbase $CheckpointDir"
Echo "RunCommand: $MdceInstallCommand"
RunCommand $MdceInstallCommand

# Start MDCE service.
If(0 -eq $Role.ToLower().CompareTo("headnode")) { 
    # For headnode use external name to be discoverable
    $HostnameToUse = $HeadnodeExternalHostname
} Else {
    # For workers use internal name
    $HostnameToUse = $InternalHostname
}

$LogLevel = "2"
$MdceCommand = "-cleanPreserveJobs"
$MdceCommand = "-loglevel " + $LogLevel
$MdceCommand = $MdceCommand + " -disableelevate"
$MdceCommand = $MdceCommand + " -usemhlm"
$MdceCommand = $MdceCommand + " -workerproxiespoolconnections"
$MdceCommand = $MdceCommand + " -enablepeerlookup"
$MdceCommand = $MdceCommand + " -hostname " + $HostnameToUse
$MdceCommand = $MdceCommand + " -untrustedclients"
$MdceCommand = $MdceCommand + " -usesecurecommunication"
$MdceCommand = $MdceCommand + " -sharedsecretfile " + $LocalSharedSecretFile
$MdceCommand = $MdceCommand + " -checkpointbase " + $CheckpointDir

Echo "Start mdce service"
$MdceStartCommand = ".\mdce.bat start $MdceCommand"
Echo "RunCommand: $MdceStartCommand"
RunCommand $MdceStartCommand

# Install MJS - headnode only.
If(0 -eq $Role.ToLower().CompareTo("headnode")) {
    # - Start MJS job manager
    $JobManagerCommand = "-name $ClusterName"
    $JobManagerCommand = $JobManagerCommand + " -certificate " + $LocalCertFile

    Echo "Starting job manager $ClusterName"
    $StartJobManagerCommand = ".\startjobmanager.bat $JobManagerCommand"
    Echo "RunCommand: $StartJobManagerCommand"
    RunCommand $StartJobManagerCommand
}

# Launch any workers
# If NumWorkers = -1, set the number of workers to the number of cores.
If($NumWorkers -eq -1) {
    $NumWorkers = (Get-WmiObject -Class win32_processor -Property "numberOfCores").NumberOfCores
}

If($NumWorkers -gt 0) {
    Echo "Starting workers (numworkers = $NumWorkers)"
    $StartWorkerCommand = ".\startworker.bat -name $InternalHostname -jobmanagerhost $HeadnodeExternalHostname -jobmanager $ClusterName -num $NumWorkers"
    Echo "RunCommand: $StartWorkerCommand"
    RunCommand $StartWorkerCommand
}

Set-Location $Currentdir
StopTranscript
Exit
