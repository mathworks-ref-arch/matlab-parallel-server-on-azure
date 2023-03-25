# MATLAB Parallel Server on Microsoft Azure

# Requirements

Before starting, you will need the following:

* A MATLAB&reg; Parallel Server&trade; license. For more information on how to configure your license for cloud use, see [Configure MATLAB Parallel Server Licensing for Cloud Platforms](https://mathworks.com/help/matlab-parallel-server/configure-matlab-parallel-server-licensing-for-cloud-platforms.html). You can use either of:
    * A MATLAB Parallel Server license configured to use online licensing for MATLAB.
    * A network license manager for MATLAB hosting sufficient MATLAB Parallel Server licenses for your cluster. MathWorks&reg; provides a reference architecture to deploy a suitable [Network License Manager for MATLAB on Azure](https://github.com/mathworks-ref-arch/license-manager-for-matlab-on-azure) or you can use an existing license manager.
* MATLAB&reg; and Parallel Computing Toolbox&trade; on your desktop.
* An Azure&reg; account.

# Costs
You are responsible for the cost of the Azure services used when you create cloud resources using this guide. Resource settings, such as instance type, will affect the cost of deployment. For cost estimates, see the pricing pages for each Azure service you will be using. Prices are subject to change.

# Introduction
The following guide will help you automate the process of launching a Parallel Server for MATLAB, using your Azure account. The cloud resources are created using Azure Resource Manager (ARM) templates. For information about the architecture of this solution, see [Learn About Cluster Architecture](#learn-about-cluster-architecture).

# Deployment Steps

To view instructions for deploying the MATLAB Parallel Server reference architecture, select a MATLAB release:

| Linux | Windows |
| ----- | ------- |
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

Parallel Computing Toolbox and MATLAB Parallel Server software let you solve computationally and data-intensive programs using MATLAB and Simulink on computer clusters, clouds, and grids. Parallel processing constructs such as parallel-for loops and code blocks, distributed arrays, parallel numerical algorithms, and message-passing functions let you implement task-parallel and data-parallel algorithms at a high level in MATLAB. To learn more see the documentation: [Parallel Computing Toolbox](https://www.mathworks.com/help/parallel-computing/) and [MATLAB Parallel Server](https://www.mathworks.com/help/matlab-parallel-server).

The MATLAB Job Scheduler is a built-in scheduler that ships with MATLAB Parallel Server. The scheduler coordinates the execution of jobs, and distributes the tasks for evaluation to the server’s individual MATLAB sessions called workers.

Microsoft Azure is a set of cloud services which allow you to build, deploy, and manage applications hosted in Microsoft’s global network of data centres. This document will help you launch a compute cluster using compute, storage, and network services hosted by Azure. For more information about the range of services offered by Microsoft Azure, see [Azure Services](https://azure.microsoft.com/en-gb/services/). Services launched in Azure can be created, managed, and deleted using the Azure Portal UI. For more information about the Azure Portal, see [Azure Portal](https://azure.microsoft.com/en-gb/features/azure-portal/).

The MATLAB Job Scheduler and the resources required by it are created using [Azure Resource Manager templates](https://docs.microsoft.com/en-gb/azure/azure-resource-manager/resource-group-overview). The architecture of the cluster resources created by the template is illustrated in Figure 2. For more information about each resource, see the [Azure template reference.](https://docs.microsoft.com/en-us/azure/templates/)

![Cluster Architecture](img/Azure_Solution_Scale_Set.png?raw=true)

*Figure 2: Cluster Architecture*

The following resources are created.

### Networking resources
* Virtual Network (Microsoft.Network/virtualNetworks) The Virtual Network includes the following components:
    * Subnet (Microsoft.Network/virtualNetworks/subnets)
    * Network Security Group (Microsoft.Network/networkSecurityGroups)
* Each instance deployed to the Virtual Network will create the following:
    * Network interface (Microsoft.Network/networkInterfaces)
    * Public IP Address (Microsoft.Network/publicIPAddresses)

### Instances
* Headnode instance (Microsoft.Compute/virtualMachines): A Compute instance for the cluster headnode. The MATLAB install is part of the VM image and the job database is stored either locally on the root volume, or optionally, a separate data disk can be used. Communication between clients and the headnode is secured using SSL.
  * Database Volume (optional) (Microsoft.Compute/disks): A separate data disk to store the MJS job database. This is optional, and if not chosen the root volume will be used for the job database.
  * Custom Script Extension (Microsoft.Compute/virtualMachines/extensions): An extension which configures this instance at deployment time as the headnode of the cluster.
* Worker Scaling Set (Microsoft.Compute/virtualMachineScaleSets): A scale set for worker instances to be launched into. The scaling features are not currently used. The scale set is configured to attach an extension to each instance which configures the instance at deployment time as a worker node of the cluster. Communication between clients and workers is secured using SSL.

### Storage
* Storage Account (Microsoft.Storage/storageAccounts): A standard locally redundant storage (LRS) Storage Account which hosts the File Share used to distribute files amongst cluster instances.
* File Share created inside Storage Account. Created by the headnode and accessible by all instances.
    * Used to distribute the Shared Secret created by headnode to all worker VMs. The Shared Secret is required for worker instances to register and establish a secure connection with the job scheduler.
    * Used to distribute the Cluster Profile to clients. The Cluster Profile is required to authenticate that a user has permission to connect to the cluster.
    * Files uploaded to this File Share will be available to all workers.

## FAQ

### What skills or specializations do I need to use this Reference Architecture?

No programming or cloud experience required. 

### How long does this process take?

If you already have an Azure account set up and ready to use, you can start a MATLAB Parallel Server Reference Architecture cluster in less than 15 minutes. Startup time will vary depending on the size of your cluster.

### How do I manage limits? 

To learn about setting quotas, see [Azure subscription and service limits](https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/azure-subscription-service-limits).

# Technical Support
If you require assistance or have a request for additional features or capabilities, please contact [MathWorks Technical Support](https://www.mathworks.com/support/contact_us.html).