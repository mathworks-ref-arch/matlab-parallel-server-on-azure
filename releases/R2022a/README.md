# MATLAB Parallel Server on Azure (Windows VM)

## Step 1. Launch the Template

Click the **Deploy to Azure** button below to deploy the cloud resources on Azure. This will open the Azure Portal in your web browser.

| Create Virtual Network | Use Existing Virtual Network |
| --- | --- |
| Use this option to deploy the resources in a new virtual network<br><br><a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fmathworks-ref-arch%2Fmatlab-parallel-server-on-azure%2Fmaster%2Freleases%2FR2022a%2Fazuredeploy-R2022a.json" target="_blank"><img src="https://aka.ms/deploytoazurebutton"/></a></br></br> | Use this option to deploy the resources in an existing virtual network <br><br><a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fmathworks-ref-arch%2Fmatlab-parallel-server-on-azure%2Fmaster%2Freleases%2FR2022a%2Fazuredeploy-existing-vnet-R2022a.json" target="_blank"><img src="https://aka.ms/deploytoazurebutton"/></a></br></br> |

> Cluster Platform: Windows Server 2019

> MATLAB Release: R2022a

## Step 2. Configure the Cloud Resources
Clicking the Deploy to Azure button opens the "Custom deployment" page in your browser. You can configure the parameters on this page. It is easier to complete the steps if you position these instructions and the Azure Portal window side by side.

1. Specify and check the defaults for these resource parameters:

| Parameter label | Description |
| --------------- | ----------- |
| **Cluster Name** | Name to use for this cluster. This name will be shown in MATLAB as the cluster profile name. |
| **Num Worker Nodes** | The number of Azure instances to start for the workers to run on. |
| **Num Workers Per Node** | The number of MATLAB workers to start on each instance. Specify 1 worker for every 2 vCPUs, because this results in 1 worker per physical core. For example a Standard_D64s_v3 instance has 64 vCPUs, so can support 32 MATLAB workers. See https://docs.microsoft.com/en-us/azure/virtual-machines/sizes for details on vCPUs for each instance type. |
| **Head Node Vm Size** | The Azure instance type to use for the headnode, which will run the job manager. No workers will be started on this node, so this can be a smaller instance type than the worker nodes. See  https://docs.microsoft.com/en-us/azure/virtual-machines/sizes. for a list of instance types. |
| **Worker Vm Size** | The Azure instance type to use for the workers. See https://docs.microsoft.com/en-us/azure/virtual-machines/sizes for a list of instance types. |
| **Database Volume Size** | The size of the volume in Gigabytes used to store the database files. If set to 0, a separate volume will not be created and the root volume will be used for the database. |
| **Client IP Address** | The IP address range that can be used to access the cluster from MATLAB. This must be a valid IP CIDR range of the form x.x.x.x/x. Use the value &lt;your_public_ip_address&gt;/32 to restrict access to only your computer. |
| **Admin Password** | Choose the admin password for the user "matlab" for all instances. This password is required when logging into any instance using remote desktop protocol. For the deployment to succeed, your password must meet Azure's password requirements. See https://docs.microsoft.com/en-us/azure/virtual-machines/windows/faq#what-are-the-password-requirements-when-creating-a-vm- for information on the password requirements. |
| **Virtual Network Resource ID** | The Resource ID of an existing virtual network to deploy your cluster into. You can find this under the Properties of your virtual network. Specify this parameter only when deploying with the Existing Virtual Network option. |
| **Subnet Name** | The name of an existing subnet within your virtual network to deploy your cluster into. Specify this parameter only when deploying with the Existing Virtual Network option. |
| **License Server** | Optional License Manager for MATLAB string in the form port@hostname. If not specified, online licensing is used. If specified, the license manager must be accessible from the specified virtual network and subnets. |


**NOTE**: If you are using network license manager, the port and hostname of the network license manager must be reachable from the MATLAB Parallel Server VMs. It is therefore recommended that you deploy into a subnet within the same virtual network as the network license manager.

2. Tick the box to accept the Azure Marketplace terms and conditions.

3. Click the **Create** button.

When you click the **Create** button, the resources are created using Azure template deployments. Template deployment can take several minutes.

# Step 3: Connect to Your Cluster From MATLAB

1. After clicking **Create** you will be taken to the Azure Portal Dashboard. To montior the progress of your deployment, select your resource group from the Resource Groups panel. Wait for the all **Deployments** to reach **Succeeded**.
2. Select the Storage Account ending with **storage**. The screen should look like the one in Figure 1.

    ![Resource Group On Completion](../../img/Deployment_Complete_Select_Storage.png)

    *Figure 1: Resource Group On Completion*

3. Select the Files container type.
4. Select the File Share named "shared".
5. Download the file, `cluster/<NAME>.settings`, where NAME is the name of your MATLAB job scheduler.
6. Open MATLAB.
7. In the Parallel drop-down menu in the MATLAB toolstrip select **Create and Manage Clusters...**.
8. Click **Import**.
9. Select the downloaded profile and click open.
10. Click **Set as Default**.
11. (Optional) Validate your cluster by clicking the **Validate** button.

After setting the cloud cluster as default, the next time you run a parallel language command (such as `parfor`, `spmd`, `parfeval` or `batch`) MATLAB connects to the cluster. The first time you connect, you will be prompted for your MathWorks account login. The first time you run a task on a worker it will take several minutes for the worker MATLAB to start. This delay is due to provisioning the instance disk. This is a one-time operation, and subsequent tasks begin much faster.

Your cluster is now ready to use. It will remain running after you close MATLAB.

**NOTE**: Use the profile and client IP address range to control access to your cloud resources. Anyone with this file can connect to your resources from a machine within the specified IP address range and run jobs on it.

# Additional Information

## Port requirements for accessing MATLAB Parallel Server

To access a MATLAB Parallel Server cluster from your client MATLAB, your client machine must be able to communicate on specific ports. Make sure that the network firewall allows the following outgoing connections:

| Required ports | Description |
| -------------- | ----------- |
| TCP 27350 to 27358 + 4*N | Ports 27350 to 27358 + 4*N, where N is the maximum number of workers on a single node |
| TCP 443 | HTTPS access to (at least) *.mathworks and *.microsoft.com |
| TCP 3389 | Remote Desktop Protocol to access to cluster nodes |

*Table 1: Outgoing port requirements*

## Delete Your Cloud Resources
You can remove the Resource Group and all associated resources when you are done with them. Note that you cannot recover resources once they are deleted. After you delete the cloud resources you cannot use the downloaded profile again.
1. Login to the Azure Portal.
2. Select the Resource Group containing your resources.
3. Select the "Delete resource group" icon to destroy all resources deployed in this group.
4. You will be prompted to enter the name of the resource group to confirm the deletion.

    ![Resource Group Delete](../../img/Resource_Group_Delete.png)

## Troubleshooting
If your resource group fails to deploy, check the Deployments section of the Resource Group. It will indicate which resource deployments failed and allow you to navigate to the causing error message.

If the resource group deployed successfully but you are unable to validate the cluster, you may need to view the logs on the instances to diagnose the error. The deployment logs are output to C:/Windows/Temp/MDCSLog*.txt on the instance nodes. The cluster logs are output to C:/Windows/Temp/MDCE/Log.