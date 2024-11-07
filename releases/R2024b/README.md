# MATLAB Parallel Server on Azure (Windows VM)

## Step 1. Deploy the Template

Click the **Deploy to Azure** button below to deploy the cloud resources on Azure&reg;. Doing so opens the Azure Portal in your web browser.

| Create Virtual Network | Use Existing Virtual Network |
| --- | --- |
| Use this option to deploy the resources in a new virtual network<br><br><a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fmathworks-ref-arch%2Fmatlab-parallel-server-on-azure%2Fmaster%2Freleases%2FR2024b%2Fazuredeploy-R2024b.json" target="_blank"><img src="https://aka.ms/deploytoazurebutton"/></a></br></br> | Use this option to deploy the resources in an existing virtual network <br><br><a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fmathworks-ref-arch%2Fmatlab-parallel-server-on-azure%2Fmaster%2Freleases%2FR2024b%2Fazuredeploy-existing-vnet-R2024b.json" target="_blank"><img src="https://aka.ms/deploytoazurebutton"/></a></br></br> |

> Cluster Platform: Windows Server 2022

> MATLAB&reg; Release: R2024b

## Step 2. Configure the Cloud Resources
Clicking the **Deploy to Azure** button opens the "Custom deployment" page in your browser. You can configure the parameters on this page. It is easier to complete the steps if you position these instructions and the Azure Portal window side by side. Create a new resource group by clicking **Create New**. Alternatively, you can select an existing resource group, but doing so can cause conflicts if resources are already deployed in it.

1. Specify and check the default settings for these resource parameters.

| Parameter Label | Description |
| --------------- | ----------- |
| **Cluster Name** | Name to use for this cluster. This name is shown in MATLAB as the cluster profile name. |
| **Num Worker Nodes** | Number of Azure virtual machines to start for the workers to run on. |
| **Min Worker Nodes** | Minimum number of running Azure virtual machines. |
| **Max Worker Nodes** | Maximum number of running Azure virtual machines. |
| **Num Workers Per Node** | Number of MATLAB worker processes to start on each virtual machine (VM). Specify 1 worker for every 2 vCPUs so that each physical core has 1 worker. For example, a Standard_D64s_v3 VM has 64 vCPUs, so it can support 32 MATLAB workers. See https://learn.microsoft.com/azure/virtual-machines/sizes for details on vCPUs for each VM size. |
| **Head Node Vm Size** | Azure virtual machine (VM) size to use for the head node, which runs the job manager. No workers are started on this node, so this node can be a smaller VM type than the worker nodes. By default, the heap memory for the job manager is set between 1024 MiB and a maximum of half of the VM memory, depending on the total number of MATLAB workers. See https://learn.microsoft.com/azure/virtual-machines/sizes for a list of VMs. |
| **Worker Vm Size** | Azure virtual machine (VM) size to use for the workers. By default, the heap memory for all worker process is set between 1024 MiB and a maximum of a quarter of the VM memory, depending on the number of MATLAB workers on the VM. See https://learn.microsoft.com/azure/virtual-machines/sizes for a list of VMs. |
| **Use Spot Instances For Worker Nodes** | Option indicating whether to enable Azure Spot Virtual Machines for worker nodes. For more information, refer to the FAQ section in the deployment README. |
| **Database Volume Size** | Size in GB of the volume to store the database files. All job and task information, including input and output data, is stored on this volume and so it must have enough capacity to store the expected amount of data. If set to 0, no volume is created and the root volume of the VM is used for the database. |
| **Client IP Address** | IP address range that can be used to access the cluster from MATLAB. This range must be a valid IP CIDR range of the form x.x.x.x/x. Use the value &lt;your_public_ip_address&gt;/32 to restrict access to only your computer. |
| **Admin Username** | Admin username for the cluster. To avoid any deployment errors, check the list of [disallowed values](https://learn.microsoft.com/rest/api/compute/virtual-machines/create-or-update?tabs=HTTP#osprofile) for adminUsername. |
| **Admin Password** | Choose the password for the admin user of the cluster. This password and the chosen admin username are required to log in into any VM in the cluster using RDP. For the deployment to succeed, your password must meet Azure's password requirements. See [Password requirements when creating a VM](https://learn.microsoft.com/azure/virtual-machines/windows/faq?WT.mc_id=Portal-fx#what-are-the-password-requirements-when-creating-a-vm-) for information on the password requirements. |
| **Virtual Network Resource ID** | Resource ID of an existing virtual network to deploy your cluster into. You can find ID this under the properties of your virtual network. Specify this parameter only when deploying with the Existing Virtual Network option. |
| **Subnet Name** | Name of an existing subnet within your virtual network to deploy your cluster into. Specify this parameter only when deploying with the Existing Virtual Network option. |
| **License Server** | License manager for MATLAB, specified as a string in the form port@hostname. If not specified, online licensing is used. Otherwise, license manager must be accessible from the specified virtual network and subnets. For more information, see https://github.com/mathworks-ref-arch/license-manager-for-matlab-on-azure. |
| **MJS Security Level** | Security level for the cluster. Level 0: Any user can access any jobs and tasks. Level 1: Accessing other users' jobs and tasks issues a warning. However, all users can still perform all actions. Level 2: Users must enter a password to access their jobs and tasks. The job owner can grant access to other users. |
| **Enable Autoscaling** | Option indicating whether VM autoscaling is enabled. For more information about autoscaling, refer to the 'Use Autoscaling' section in the deployment README. |
| **Automatically Terminate Cluster** | Option to autoterminate the cluster after a few hours or when idle. When the cluster is terminated, all worker nodes are deleted and the headnode is deallocated. Select 'Never' to disable auto-termination now but you can enable it later. Select 'Disable auto-termination' to fully disable this feature or if you do not have the permissions to create and assign roles in your subscription. For more information, see [Automatically terminate the MATLAB Parallel Server cluster](https://github.com/mathworks-ref-arch/matlab-parallel-server-on-azure-lin#automatically-terminate-the-matlab-parallel-server-cluster). |
| **MJS Scheduling Algorithm** | Scheduling algorithm for the job manager. 'standard' spreads communicating jobs across as few worker machines as possible to reduce communication overheads and fills in unused spaces on worker machines with independent jobs. Suitable for good behavior for a wide range of uses including autoscaling. 'loadBalancing' distributes load evenly across the cluster to give as many resources as possible to running jobs and tasks when the cluster is underutilized. |
| **Optional User Command** | Provide an optional inline PowerShell command to run on machine launch. For example, to set an environment variable CLOUD=AZURE, use this command excluding the angle brackets: &lt;[System.Environment]::SetEnvironmentVariable("CLOUD","AZURE", "Machine");&gt;. You can use either double quotes or two single quotes. To run an external script, use this command excluding the angle brackets: &lt;Invoke-WebRequest "https://www.example.com/script.ps1" -OutFile script.ps1; .\script.ps1&gt;. Find the logs at 'C:\ProgramData\MathWorks\startup.log'. |


**NOTE**: If you are using the network license manager, the port and hostname of the network license manager must be reachable from the MATLAB Parallel Server&trade; virtual machines (VMs). Deploying into a subnet within the same virtual network as the network license manager is a best practice.

2. Click the **Review + create** button to review the Azure Marketplace terms and conditions.

3. Click the **Create** button.

When you click the **Create** button, the resources are created using Azure template deployments. Template deployment can take several minutes.

# Step 3: Connect to Your Cluster From MATLAB

1. Clicking **Create** opens the Deployment Details page, where you can monitor the progress of your deployment. Wait for the message **Your deployment is complete**.
2. Go to your resource group, and select the Storage Account starting with **mwstorage**. The screen must look like the one in Figure 1.

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

After you set the cloud cluster as default, the next time you run a parallel language command (such as `parfor`, `spmd`, `parfeval` or `batch`), MATLAB connects to the cluster. The first time you connect, you are prompted for your MathWorks&reg; account login. The first time you run a task on a worker, it takes several minutes for the worker MATLAB to start. This delay is due to provisioning the instance disk. This is a one-time operation, and subsequent tasks begin faster.

Your cluster is now ready to use. 

**NOTE**: Use the profile and client IP address range to control access to your cloud resources. Anyone with this file can connect to your resources from a machine within the specified IP address range and run jobs on it.

Your cluster remains running after you close MATLAB.

## Delete Your Cloud Resources
You can remove the resource group and all associated resources when you are done with them. Note that you cannot recover resources once they are deleted. After you delete the cloud resources, you cannot use the downloaded profile again.
1. Log in to the Azure Portal.
2. Select the resource group containing your resources.
3. Select the "Delete resource group" icon to destroy all resources deployed in this group.
4. You are prompted to enter the name of the resource group to confirm the deletion.

    ![Resource Group Delete](../../img/Resource_Group_Delete.png)

# Additional Information

## Port Requirements 

Before you can use your MATLAB Parallel Server cluster, you must configure certain required ports on the cluster and client firewall. These ports allow your client machine to connect to the cluster headnode and facilitate communication between the cluster nodes. 

### Cluster Nodes 

For details about the port requirements for cluster nodes, see this information from MathWorks® Support Team on MATLAB Answers: [How do I configure MATLAB Parallel Server using the MATLAB Job Scheduler to work within a firewall?]( https://www.mathworks.com/matlabcentral/answers/94254-how-do-i-configure-matlab-parallel-server-using-the-matlab-job-scheduler-to-work-within-a-firewall). 

Additionally, if your client machine is outside the cluster’s network, then you must configure the network security group of your cluster to allow incoming traffic from your client machine on the following ports. For information on how to configure your network security group, see [Create a security rule](https://learn.microsoft.com/azure/virtual-network/manage-network-security-group). To troubleshoot, see this [page](https://learn.microsoft.com/troubleshoot/azure/virtual-machines/windows/troubleshoot-rdp-nsg-problem).  

| Required ports | Description |
| -------------- | ----------- |
| TCP 27350 to 27358 + 4*N | For connecting to the job manager on the cluster headnode and to the worker nodes for parallel pools. Calculate the required ports based on N, the maximum number of workers on any single node across the entire cluster.  |
| TCP 443 | If you are using online licensing, you must open this port for outbound communication from all cluster machines. If you’re using Network License Manager instead, then you must configure ports as listed on [Network License Manager for MATLAB on Microsoft Azure](https://github.com/mathworks-ref-arch/license-manager-for-matlab-on-azure?tab=readme-ov-file#networking-resources).   |
| TCP 3389 | Remote Desktop Protocol to access to cluster nodes. |

*Table 1: Outgoing port requirements*

By default, MATLAB Parallel Server is configured with the public hostname of each machine to allow the MATLAB client to access both the scheduler and workers. If you modify the Azure Resource Manager (ARM) template provided, make sure that you provide a public hostname for the head node and the worker nodes.

## Use Autoscaling

To optimize the number of virtual machines running MATLAB workers, enable autoscaling by setting `Enable Autoscaling` to `Yes` when you deploy the template. Autoscaling is optional and is disabled by default.

When autoscaling is disabled, the Virtual Machine Scale Set (VMSS) deploys `Num Worker Nodes` instances. To change the number of worker nodes, use the Azure Portal.

If you enable autoscaling, the capacity of the VMSS is regulated by the number of workers needed by the cluster. The number of virtual machines is initially set to `Num Worker Nodes`. It then fluctuates between `Min` and `Max Worker Nodes`. To change these limits after deployment, use the Azure Portal and modify the tags on the VMSS. To change the amount of time for which idle nodes are preserved, adjust the value of the tag `mwWorkerIdleTimeoutMinutes`. Do not use the "manual scale" option to change the instance count, as doing so can lead to the unsafe termination of MATLAB workers.

Ensure that the `Max Worker Nodes` parameter is within your Azure subscription quotas for the specific instance type. To learn about setting quotas, see [Azure subscription and service limits, quotas, and constraints](https://learn.microsoft.com/azure/azure-resource-manager/management/azure-subscription-service-limits).

To disable autoscaling after the deployment, redeploy the template with autoscaling disabled.

## Automatically Terminate the MATLAB Parallel Server Cluster

Use the `Automatically Terminate Cluster` parameter while deploying the resource group to manage costs efficiently. You can choose one of these options:

* `Never` (default): No auto-termination but can be enabled after deployment.
* `When cluster is idle`: Terminates the cluster when it is idle for about 10 minutes (30 minutes at startup).
* `After x hours`: Terminates the cluster after 'x' hours (where `x` is between 1 and 24).
* `Disable auto-termination`: No auto-termination. Use this option to fully disable this feature or if you do not have the permissions to create and assign roles in your subscription.

When the cluster is auto-terminated, the head node virtual machine is deallocated and all worker virtual machines are deleted. To use the cluster again, restart the head node.

To modify the termination policy after deploying the resource group, edit the value of the tag `mw-autoshutdown` that is attached to the head node. Set the value of the tag to either `never`, `on_idle`, or `After x hours`, where x must be an integer between 1 and 24.

## MATLAB Job Scheduler Configuration

By default, MATLAB Job Scheduler (MJS) is configured to manage a wide range of cluster uses.

To change the MJS configuration for advanced use cases, replace the default `mjs_def` file with your own file using the template parameter `OptionalUserCommand`. Doing so overwrites all MJS startup parameters, except for *DEFAULT_JOB_MANAGER_NAME*, *HOSTNAME*, and *SHARED_SECRET_FILE*. For more information about the MJS startup parameters and to edit them, see [Define MATLAB Job Scheduler Startup Parameters](https://www.mathworks.com/help/matlab-parallel-server/define-startup-parameters.html).
For example, to retrieve and use your edited `mjs_def` from a storage service (such as Azure blob storage), set the `OptionalUserCommand` to the following:
```
Invoke-WebRequest "https://<your_storage_account>.blob.core.windows.net/<container_name>/mjs_def.bat" -OutFile $Env:MJSDefFile
```

## Troubleshooting
If your resource group fails to deploy, check the Deployments section of the Resource Group. This section indicates which resource deployments failed and allow you to navigate to the causing error message.

If the resource group deployed successfully but you are unable to validate the cluster, check the logs on the instances to diagnose the error. The deployment logs are output to C:\ProgramData\MathWorks\MDCSLog-*.log on the instance nodes. The cluster logs are output to C:\ProgramData\MJS\Log. The system startup logs are output to C:\ProgramData\MathWorks\startup.log on every instance of the cluster.

----

Copyright 2018-2024 The MathWorks, Inc.

----