<#
.SYNOPSIS
Initializes the MATLAB Job Scheduler (MJS) environment, including security setup, profile creation, and file sharing configuration.

.DESCRIPTION
The Initialize-MJS function configures the necessary security files, certificates, and MATLAB Job Scheduler profile for a cluster environment. On the headnode, it creates or reuses shared secret and certificate files, generates a MATLAB profile, and uploads required files to an Azure File Share. On worker nodes, it waits for the shared secret to become available in the file share and downloads it for local use.

.EXAMPLE
Initialize-MJS

.NOTES
    Copyright 2022-2026 The MathWorks, Inc.
#>

function Initialize-MJS {
    $FileShareName = 'shared'
    $FileShareFolder = 'cluster'

    if (-not (Test-Path $Env:SecurityRoot)) {
        New-Item -Path $Env:SecurityRoot -ItemType Directory
    }

    # Create shared secret file and set MATLAB client verification
    # https://www.mathworks.com/help/matlab-parallel-server/set-matlab-job-scheduler-cluster-security.html
    if ($Env:NodeType -eq 'headnode') {
        if ( -not (Test-Path $Env:SecretFile) -or -not (Test-Path $Env:CertFile) ) {
            Write-Output '===Creating secret and certificate==='
            & "$Env:ParallelToolBoxRoot\createSharedSecret.bat" -file $Env:SecretFile
            & "$Env:ParallelToolBoxRoot\generateCertificate.bat" -secretfile $Env:SecretFile -certfile $Env:CertFile
        }
        else {
            Write-Output '===Using existing secret and certificate==='
        }

        Write-Output '===Creating profile==='
        $WinTemp = [System.Environment]::GetEnvironmentVariable('TEMP', 'Machine')
        $MJSHostname = $Env:ExternalHostname
        $ProfileFile = "$WinTemp\$Env:JobManagerName.mlsettings"
        & "$Env:ParallelToolBoxRoot\createProfile.bat" -name "$Env:JobManagerName" -host $MJSHostname -certfile $Env:CertFile -outfile "$ProfileFile"

        Write-Output '===Uploading files to File Share==='
        # Creating File share if we cannot find it in the storage account
        if ($(az storage share exists --name "$FileShareName" --output tsv) -eq 'False') {
            Write-Output "Creating file share: $FileShareName"
            if ($(az storage share create --name "$FileShareName" --output tsv) -eq 'False') {
                Write-Output 'Failed to create file share.'
                exit 1
            }
        }
        else {
            Write-Output "Using existing file share: $FileShareName"
        }

        # Create directory under the File Share
        az storage directory create --share-name "$FileShareName" --name "$FileShareFolder"

        # List of files to be uploaded
        $FilesToUpload = @("$ProfileFile")

        # Check if the admin password file exists and add it to the list
        if (Test-Path $Env:MJSAdminPasswordFile) {
            $FilesToUpload += $Env:MJSAdminPasswordFile
        }

        # Check if the files are already present in the file share
        $ExistingFiles = $(az storage file list --share-name $FileShareName --account-name $Env:AZURE_STORAGE_ACCOUNT --path $FileShareFolder --output json) | ConvertFrom-Json

        # List of secret and certificate file names
        $SecretsAndCertificateFiles = @("$Env:SecretFile", "$Env:CertFile")

        # Check if the secret and/or certificate files are already present in the file share
        foreach ($File in $SecretsAndCertificateFiles) {
            $FileName = $(Split-Path -Path $File -Leaf)
            $FileExists = $ExistingFiles | Where-Object { $_.name -eq "$FileName" }
            if ($FileExists) {
                Write-Output "File $FileName already exists in the file share. Upload skipped."
            }
            else {
                $FilesToUpload += $File
            }
        }

        # Asynchronously upload files to the file share
        $UploadScriptBlock = {
            param($FileShareName, $FileShareFolder, $Source)
            az storage file upload --share-name $FileShareName --path $FileShareFolder --source $Source
            Write-Output "Uploaded $Source to $FileShareName."
        }

        # Initialize an empty array to hold jobs for async execution of the upload
        $jobs = @()

        foreach ($source in $FilesToUpload) {
            # Start a background job for each upload using Start-Job and passing the script block and parameters
            $job = Start-Job -ScriptBlock $UploadScriptBlock -ArgumentList $FileShareName, $FileShareFolder, $source
            # Append the job to the $jobs array for tracking
            $jobs += $job
        }

        # Wait for all jobs to complete and then retrieve the results
        $jobs | Wait-Job

        # Output the results and clean up
        $jobs | ForEach-Object {
            Receive-Job -Job $_
            Remove-Job -Job $_
        }
    }

    else {
        Write-Output '===Retrieving secret from File Share==='
        # Wait for up to 10 minutes for the shared secret
        # to appear before giving up.
        $TimeoutSeconds = 600
        $StartTime = Get-Date
        while ($(az storage file exists --share-name "$FileShareName" --path "$FileShareFolder/secret" --output tsv) -eq 'False') {
            Start-Sleep -Seconds 1
            if (((Get-Date) - $StartTime).TotalSeconds -gt $TimeoutSeconds) {
                Write-Output "The shared secret was not found in $FileShareFolder/$FileShareName within $TimeoutSeconds seconds."
                exit 1
            }
        }
        az storage file download --share-name "$FileShareName" --path "$FileShareFolder/secret" --dest "$Env:SecretFile"
    }
}

try {
    Initialize-MJS
}
catch {
    $ScriptPath = $MyInvocation.MyCommand.Path
    Write-Output "ERROR - An error occurred while running script '60_Setup-MJS': $ScriptPath. Error: $_"
    throw
}
