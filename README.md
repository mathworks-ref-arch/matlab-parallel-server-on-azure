# MATLAB Parallel Server on Microsoft Azure

This repository helps you automate the process of deploying MATLAB&reg; Parallel Server&trade; and MATLAB Job Scheduler (MJS) using your Azure&reg; account. 

Use this repository to deploy a compute cluster using compute, storage, and network resources hosted by Azure. The cloud resources are created using Azure Resource Manager (ARM) templates. For information about the architecture of this solution, see [Learn About Cluster Architecture](#learn-about-cluster-architecture).

# Requirements

Before starting, you need the following:

* A MATLAB Parallel Server license. You can use either:
    * A MATLAB Parallel Server license configured to use online licensing for MATLAB. For information on how to configure your license for cloud use, see [Configure MATLAB Parallel Server Licensing for Cloud Platforms](https://www.mathworks.com/help/matlab-parallel-server/configure-matlab-parallel-server-licensing-for-cloud-platforms.html).
    * A network license manager for MATLAB hosting sufficient MATLAB Parallel Server licenses for your cluster. MathWorks&reg; provides a reference architecture to deploy a suitable [Network License Manager for MATLAB on Azure](https://github.com/mathworks-ref-arch/license-manager-for-matlab-on-azure) or you can use an existing license manager.
* MATLAB and Parallel Computing Toolbox&trade; on your desktop.
* An Azure account. To configure your account to enable autoscaling (since R2022b), see [Configure Azure Account](#configure-azure-account).

# Costs
You are responsible for the cost of the Azure services you use when you create cloud resources using this repository. Resource settings, such as Virtual Machine (VM) type, affects the cost of deployment. For cost estimates, see the pricing pages for each Azure service you use. Prices are subject to change.

# Deployment Steps

To view instructions for deploying the MATLAB Parallel Server reference architecture, select a MATLAB release:

| Linux | Windows |
| ----- | ------- |
| [R2024a](https://github.com/mathworks-ref-arch/matlab-parallel-server-on-azure-lin/tree/master/releases/R2024a/README.md) | [R2024a](releases/R2024a/README.md) |
| [R2023b](https://github.com/mathworks-ref-arch/matlab-parallel-server-on-azure-lin/tree/master/releases/R2023b/README.md) | [R2023b](releases/R2023b/README.md) |
| [R2023a](https://github.com/mathworks-ref-arch/matlab-parallel-server-on-azure-lin/tree/master/releases/R2023a/README.md) | [R2023a](releases/R2023a/README.md) |
| [R2022b](https://github.com/mathworks-ref-arch/matlab-parallel-server-on-azure-lin/tree/master/releases/R2022b/README.md) | [R2022b](releases/R2022b/README.md) |
| [R2022a](https://github.com/mathworks-ref-arch/matlab-parallel-server-on-azure-lin/tree/master/releases/R2022a/README.md) | [R2022a](releases/R2022a/README.md) |
|  | [R2021b](releases/R2021b/README.md) |
|  | [R2021a](releases/R2021a/README.md) |
|  | [R2020b](releases/R2020b/README.md) |
|  | [R2020a](releases/R2020a/README.md) |
|  | [R2019b](releases/R2019b/README.md) |
|  | [R2019a\_and\_older](releases/R2019a_and_older/README.md) |


# Learn About Cluster Architecture

This diagram illustrates the cluster architecture created by the template. When you use the Azure Resource Manager templates in this repository, it creates the [MATLAB Job Scheduler](#what-is-matlab-job-scheduler) and the following resources. For more information about each resource, see the [Azure template reference.](https://learn.microsoft.com/azure/templates/)

![Cluster Architecture](img/Azure_Solution_Scale_Set.png?raw=true)

*Figure 2: Cluster Architecture*

The following resources are created.

### Networking Resources
* Virtual Network (Microsoft.Network/virtualNetworks) The Virtual Network includes the following components:
    * Subnet (Microsoft.Network/virtualNetworks/subnets)
    * Network Security Group (Microsoft.Network/networkSecurityGroups)
* Each VM deployed to the Virtual Network creates the following:
    * Network interface (Microsoft.Network/networkInterfaces)
    * Public IP Address (Microsoft.Network/publicIPAddresses)

### Compute Resources
* Headnode VM (Microsoft.Compute/virtualMachines): A Compute VM for the cluster headnode. The MATLAB install is part of the VM image, and the job database is stored either locally on the root volume, or optionally, on a separate data disk. The headnode communicates with the clients using a secure SSL connection.
  * Database Volume (optional): An optional separate data disk to store the MJS job database.
* Worker Scaling Set (Microsoft.Compute/virtualMachineScaleSets): A scale set for worker VMs to be deployed into. Clients and workers communicate using a secure SSL connection.

### Storage Resources
* Storage Account (Microsoft.Storage/storageAccounts): A standard locally redundant storage (LRS) Storage Account which hosts the File Share used to distribute files amongst cluster VMs.
* File Share created inside Storage Account: A file share inside the storage account.
    * Contains the Shared Secret created by headnode to all worker VMs. The worker VMs require the Shared Secret to register and establish a secure connection with the job scheduler.
    * Contains the Cluster Profile. The client machine requires the Cluster Profile to authenticate and establish a connection with the headnode.

## Configure Azure Account

To enable autoscaling for your cluster, you must have the following permissions:

1. `Microsoft.Authorization/roleDefinitions/write`
2. `Microsoft.Authorization/roleAssignments/write`

To check if you have these permissions, see [Check access for a user to Azure resources](https://learn.microsoft.com/azure/role-based-access-control/check-access).

If you do not have these permissions, the Administrator or [Owners of the Subscription](https://learn.microsoft.com/azure/role-based-access-control/role-assignments-list-portal#list-owners-of-a-subscription) can either:

1. Assign you the built-in Azure role [User Access Administrator](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#user-access-administrator) in addition to your existing role. see [Assign Azure roles](https://learn.microsoft.com/azure/role-based-access-control/role-assignments-portal).
2. Create a custom role containing these permissions and attach it along with your existing role. see [Create Custom roles](https://learn.microsoft.com/azure/role-based-access-control/custom-roles-portal).

## FAQ

### What can I do with MATLAB Parallel Server?

Parallel Computing Toolbox and MATLAB Parallel Server let you solve computationally and data-intensive programs using MATLAB and Simulink on computer clusters, clouds, and grids. Parallel processing constructs such as parallel-for loops and code blocks, distributed arrays, parallel numerical algorithms, and message-passing functions let you implement task-parallel and data-parallel algorithms at a high level in MATLAB. To learn more, see the documentation: [Parallel Computing Toolbox](https://www.mathworks.com/help/parallel-computing/) and [MATLAB Parallel Server](https://www.mathworks.com/help/matlab-parallel-server).

### What is MATLAB Job Scheduler?

MATLAB Job Scheduler is a scheduler that ships with MATLAB Parallel Server. The scheduler coordinates the execution of jobs and distributes the tasks for evaluation to the server’s individual MATLAB sessions called workers. For more details, see [How Parallel Computing Toolbox Runs a Job](https://www.mathworks.com/help/parallel-computing/how-parallel-computing-products-run-a-job.html). The MATLAB Job Scheduler and the resources required by it are created using [Azure Resource Manager templates](https://learn.microsoft.com/azure/azure-resource-manager/management/overview).

### What is Microsoft Azure?

Microsoft Azure is a set of cloud services which allow you to build, deploy, and manage applications hosted in Microsoft’s global network of data centers. For more information about the range of services offered by Microsoft Azure, see [Azure Services](https://azure.microsoft.com/products/). Services deployed in Azure can be created, managed, and deleted using the Azure Portal UI. For more information about the Azure Portal, see [Azure Portal](https://azure.microsoft.com/get-started/azure-portal/).

### What skills or specializations do I need to use this Reference Architecture?

No programming or cloud experience required. 

### How long does it take to deploy the Reference Architecture?

If you already have an Azure account set up and ready to use, you can start a MATLAB Parallel Server Reference Architecture cluster in less than 15 minutes. Startup time varies depending on the size of your cluster.

### How do I manage limits for Azure services? 

To learn about setting quotas, see [Azure subscription and service limits](https://learn.microsoft.com/azure/azure-resource-manager/management/azure-subscription-service-limits).

# Technical Support
If you require assistance or have a request for additional features or capabilities, contact [MathWorks Technical Support](https://www.mathworks.com/support/contact_us.html).

----

Copyright 2018 - 2024 The MathWorks, Inc.

----