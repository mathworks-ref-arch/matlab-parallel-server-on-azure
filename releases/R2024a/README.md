# MATLAB Parallel Server on Azure (Windows VM)

## Step 1. Deploy the Template

Click the **Deploy to Azure** button below to deploy the cloud resources on Azure&reg;. This opens the Azure Portal in your web browser.

| Create Virtual Network | Use Existing Virtual Network |
| --- | --- |
| Use this option to deploy the resources in a new virtual network<br><br><a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fmathworks-ref-arch%2Fmatlab-parallel-server-on-azure%2Fmaster%2Freleases%2FR2024a%2Fazuredeploy-R2024a.json" target="_blank"><img src="https://aka.ms/deploytoazurebutton"/></a></br></br> | Use this option to deploy the resources in an existing virtual network <br><br><a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fmathworks-ref-arch%2Fmatlab-parallel-server-on-azure%2Fmaster%2Freleases%2FR2024a%2Fazuredeploy-existing-vnet-R2024a.json" target="_blank"><img src="https://aka.ms/deploytoazurebutton"/></a></br></br> |

> Cluster Platform: Windows Server 2019

> MATLAB&reg; Release: R2024a

## Step 2. Configure the Cloud Resources
Clicking the **Deploy to Azure** button opens the "Custom deployment" page in your browser. You can configure the parameters on this page. It is easier to complete the steps if you position these instructions and the Azure Portal window side by side. Create a new resource group by clicking **Create New**. Alternatively, you can select an existing resource group, but this can cause conflicts if resources are already deployed in it.

1. Specify and check the defaults for these resource parameters:

| Parameter label | Description |
| --------------- | ----------- |
| **Cluster Name** | Name to use for this cluster. This name is shown in MATLAB as the cluster profile name. |
| **Num Worker Nodes** | Number of Azure Virtual Machines to start for the workers to run on. |
| **Min Worker Nodes** | Minimum number of running Azure Virtual Machines. |
| **Max Worker Nodes** | Maximum number of running Azure Virtual Machines. |
| **Num Workers Per Node** | Number of MATLAB worker processes to start on each Virtual Machine (VM). Specify 1 worker for every 2 vCPUs, because this results in 1 worker per physical core. For example, a Standard_D64s_v3 VM has 64 vCPUs, so can support 32 MATLAB workers. See https://learn.microsoft.com/azure/virtual-machines/sizes for details on vCPUs for each VM size. |
| **Head Node Vm Size** | Azure VM size to use for the headnode, which runs the job manager. No workers are started on this node, so this can be a smaller VM type than the worker nodes. By default, the heap memory for the job manager is set between 1024 MiB and a maximum of half of the VM memory, depending on the total number of MATLAB workers. See  https://learn.microsoft.com/azure/virtual-machines/sizes for a list of VMs. |
| **Worker Vm Size** | Azure VM size to use for the workers. By default, the heap memory for all worker process is set between 1024 MiB and a maximum of a quarter of the VM memory, depending on the number of MATLAB workers on the VM. See https://learn.microsoft.com/azure/virtual-machines/sizes for a list of VMs. |
| **Database Volume Size** | Size in GB of the volume to store the database files. All job and task information, including input and output data is stored on this volume and should therefore have enough capacity to store the expected amount of data. If set to 0, no volume is created and the root volume of the VM is used for the database. |
| **Client IP Address** | IP address range that can be used to access the cluster from MATLAB. This must be a valid IP CIDR range of the form x.x.x.x/x. Use the value &lt;your_public_ip_address&gt;/32 to restrict access to only your computer. |
| **Admin Username** | Admin username for the cluster. To avoid any deployment errors, check the list of [disallowed values](https://learn.microsoft.com/rest/api/compute/virtual-machines/create-or-update?tabs=HTTP#osprofile) for adminUsername. |
| **Admin Password** | Choose the password for the admin user of the cluster. This password and the chosen admin username are required to login into any VM in the cluster using RDP. For the deployment to succeed, your password must meet Azure's password requirements. See [Password requirements when creating a VM](https://learn.microsoft.com/azure/virtual-machines/windows/faq?WT.mc_id=Portal-fx#what-are-the-password-requirements-when-creating-a-vm-) for information on the password requirements. |
| **Virtual Network Resource ID** | Resource ID of an existing virtual network to deploy your cluster into. You can find this under the Properties of your virtual network. Specify this parameter only when deploying with the Existing Virtual Network option. |
| **Subnet Name** | Name of an existing subnet within your virtual network to deploy your cluster into. Specify this parameter only when deploying with the Existing Virtual Network option. |
| **License Server** | Optional License Manager for MATLAB, specified as a string in the form port@hostname. If not specified, online licensing is used. Otherwise, license manager must be accessible from the specified virtual network and subnets. For more information, see https://github.com/mathworks-ref-arch/license-manager-for-matlab-on-azure. |
| **MJS Security Level** | Security level for the cluster. Level 0: Any user can access any jobs and tasks. Level 1: Accessing other users' jobs and tasks issues a warning. However, all users can still perform all actions. Level 2: Users must enter a password to access their jobs and tasks. The job owner can grant access to other users. |
| **Enable Autoscaling** | Option indicating whether VM autoscaling is enabled. For more information about autoscaling, refer to the 'Use Autoscaling' section in the deployment README. |
| **MJS Scheduling Algorithm** | Scheduling algorithm for the job manager. 'standard' spreads communicating jobs across as few worker machines as possible to reduce communication overheads and fills in unused spaces on worker machines with independent jobs. Suitable for good behaviour for a wide range of uses including autoscaling. 'loadBalancing' distributes load evenly across the cluster to give as many resources as possible to running jobs and tasks when the cluster is underutilized. |
| **Optional User Command** | Provide an optional inline PowerShell command to run on machine launch. For example, to set an environment variable CLOUD=AZURE, use this command excluding the angle brackets: &lt;[System.Environment]::SetEnvironmentVariable("CLOUD","AZURE", "Machine");&gt;. You can use either double quotes or two single quotes. To run an external script, use this command excluding the angle brackets: &lt;Invoke-WebRequest "https://www.example.com/script.ps1" -OutFile script.ps1; .\script.ps1&gt;. Find the logs at '$Env:ProgramData\MathWorks\startup.log'. |


**NOTE**: If you are using network license manager, the port and hostname of the network license manager must be reachable from the MATLAB Parallel Server&trade; Virtual Machines (VMs). It is therefore recommended that you deploy into a subnet within the same virtual network as the network license manager.

2. Click the **Review + create** button to review the Azure Marketplace terms and conditions.

3. Click the **Create** button.

When you click the **Create** button, the resources are created using Azure template deployments. Template deployment can take several minutes.

# Step 3: Connect to Your Cluster From MATLAB

1. After clicking **Create**, you are taken to the Deployment Details page, where you can monitor the progress of your deployment. Wait for the message **Your deployment is complete**.
2. Go to your resource group, and select the Storage Account ending with **storage**. The screen should look like the one in Figure 1.

    ![Resource Group On Completion](../../img/Deployment_Complete_Select_Storage.png)

    *Figure 1: Resource Group On Completion*

3. Under **Data Storage** on the left panel, click **File shares**, and select the file share named "shared".
4. Click **Browse** on the left panel, then open the "cluster" folder.
5. Download the file, `<NAME>.mlsettings`, where NAME is the name of your MATLAB job scheduler.
6. Open MATLAB.
7. In the Parallel drop-down menu in the MATLAB toolstrip select **Create and Manage Clusters**.
8. Click **Import**.
9. Select the downloaded profile and click open.
10. Click **Set as Default**.
11. (Optional) Validate your cluster by clicking the **Validate** button.

After setting the cloud cluster as default, the next time you run a parallel language command (such as `parfor`, `spmd`, `parfeval` or `batch`), MATLAB connects to the cluster. The first time you connect, you are prompted for your MathWorks&reg; account login. The first time you run a task on a worker, it takes several minutes for the worker MATLAB to start. This delay is due to provisioning the instance disk. This is a one-time operation, and subsequent tasks begin much faster.

Your cluster is now ready to use. 

**NOTE**: Use the profile and client IP address range to control access to your cloud resources. Anyone with this file can connect to your resources from a machine within the specified IP address range and run jobs on it.

Your cluster remains running after you close MATLAB. To delete your cluster, follow these instructions.

## Delete Your Cloud Resources
You can remove the resource group and all associated resources when you are done with them. Note that you cannot recover resources once they are deleted. After you delete the cloud resources, you cannot use the downloaded profile again.
1. Login to the Azure Portal.
2. Select the resource group containing your resources.
3. Select the "Delete resource group" icon to destroy all resources deployed in this group.
4. You are prompted to enter the name of the resource group to confirm the deletion.

    ![Resource Group Delete](../../img/Resource_Group_Delete.png)

# Additional Information

## Port requirements for accessing MATLAB Parallel Server

To access a MATLAB Parallel Server cluster from your client MATLAB, your client machine must be able to communicate on specific ports. Make sure that the network firewall allows the following outgoing connections:

| Required ports | Description |
| -------------- | ----------- |
| TCP 27350 to 27358 + 4*N | Ports 27350 to 27358 + 4*N, where N is the maximum number of workers on a single node |
| TCP 443 | HTTPS access to (at least) *.mathworks and *.microsoft.com |
| TCP 3389 | Remote Desktop Protocol to access to cluster nodes |

*Table 1: Outgoing port requirements*

By default, MATLAB Parallel Server is configured with the public hostname of each machine to allow the MATLAB client to access both the scheduler and workers. If you modify the Azure Resource Manager (ARM) template provided, ensure that a public hostname is provided for the headnode and the worker nodes.

## Use Autoscaling

To optimize the number of Virtual Machines running MATLAB workers, enable autoscaling by setting `Enable Autoscaling` to `Yes` when you deploy the template. Autoscaling is optional and is disabled by default.

When autoscaling is disabled, the Virtual Machine Scale Set (VMSS) deploys `Num Worker Nodes` instances. To change the number of worker nodes, use the Azure Portal.

If you enable autoscaling, the capacity of the VMSS is regulated by the number of workers needed by the cluster. The number of Virtual Machines is initially set at `Num Worker Nodes`. It then fluctuates between `Min` and `Max Worker Nodes`. To change these limits after the deployment, use the Azure Portal and modify the tags on the VMSS. To change the amount of time for which idle nodes are preserved, adjust the value of the tag `mwWorkerIdleTimeoutMinutes`. Do not use the "manual scale" option to change the instance count, as this can lead to the unsafe termination of MATLAB workers.

Ensure that the `Max Worker Nodes` parameter is within your Azure subscription quotas for the specific instance type. To learn about setting quotas, see [Azure subscription and service limits, quotas, and constraints](https://learn.microsoft.com/azure/azure-resource-manager/management/azure-subscription-service-limits).

To disable autoscaling after the deployment, redeploy the template with autoscaling disabled.

## MATLAB Job Scheduler Configuration

By default, MATLAB Job Scheduler (MJS) is configured to manage a wide range of cluster uses.

To change the MJS configuration for advanced use cases, replace the default `mjs_def` with your own file using the template parameter `OptionalUserCommand`. This overwrites all MJS startup parameters, except for *DEFAULT_JOB_MANAGER_NAME*, *HOSTNAME*, and *SHARED_SECRET_FILE*. To learn more about the MJS startup parameters and to edit them, see [Define MATLAB Job Scheduler Startup Parameters](https://www.mathworks.com/help/matlab-parallel-server/define-startup-parameters.html).
For example, to retrieve and use your edited `mjs_def` from a storage service (e.g. Azure blob storage), set the `OptionalUserCommand` to the following:
```
Invoke-WebRequest "https://<your_storage_account>.blob.core.windows.net/<container_name>/mjs_def.bat" -OutFile $Env:MJSDefFile
```

## Troubleshooting
If your resource group fails to deploy, check the Deployments section of the Resource Group. This section indicates which resource deployments failed and allow you to navigate to the causing error message.

If the resource group deployed successfully but you are unable to validate the cluster, check the logs on the instances to diagnose the error. The deployment logs are output to C:\ProgramData\MathWorks\MDCSLog-*.log on the instance nodes. The cluster logs are output to C:\ProgramData\MJS\Log.

----

Copyright 2018 - 2024 The MathWorks, Inc.

----