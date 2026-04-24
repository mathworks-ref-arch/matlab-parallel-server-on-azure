# **Build Your Own Machine Image**

## **Introduction**
This guide shows how to build your own Azure&reg; Virtual Machine (VM) Image using the same scripts that form the basis of the build process for MathWorks&reg; prebuilt images.
You can use the scripts to install MATLAB&reg; Parallel Server&trade;, MATLAB toolboxes, and the other features detailed below.

A HashiCorp&reg; Packer template generates the machine image.
The template is an HCL2 file that tells Packer which plugins (builders, provisioners, post-processors) to use, how to configure each of those plugins, and what order to run them in.
For more information about templates, see [Packer Templates](https://www.packer.io/docs/templates#packer-templates).

## **Requirements**
Before starting, you need:
* [Packer](https://www.packer.io/downloads) 1.15.0 or later.
* [Azure credentials](https://learn.microsoft.com/en-us/azure/virtual-machines/linux/build-image-with-packer#create-azure-credentials). For details about how Packer authenticates Azure clients, see [Azure authentication for Packer](https://www.packer.io/plugins/builders/azure#authentication).

## **Costs**
You are responsible for the cost of the Azure services used when you create cloud resources using this guide. Resource settings, such as virtual machine size, will affect the cost of deployment. For cost estimates, see the pricing pages for each Azure service you will be using. Prices are subject to change.

## **Quick Start Instructions**
This section shows how to build the latest MATLAB Parallel Server machine image in your Azure account. 

Pull the source code and navigate to the Packer folder.
```bash
git clone https://github.com/mathworks-ref-arch/matlab-parallel-server-on-azure.git
cd matlab-parallel-server-on-azure/packer/v1
```

Initialize Packer to install the required plugins.
You only need to do this once.
For more information, see [init command reference (Packer)](https://developer.hashicorp.com/packer/docs/commands/init).
```bash
packer init build-azure-parallel-server.pkr.hcl
```

To allow Packer to create resources in your account, you need to provide the credentials `client_id`, `client_secret`, `tenant_id`, and `subscription_id`.
For instructions on obtaining these credentials, see [Create Azure credentials](https://learn.microsoft.com/azure/virtual-machines/linux/build-image-with-packer#create-azure-credentials).

You also need to specify a resource group to store the custom artifact under.
For more information on these options, see [Configuration Reference](https://developer.hashicorp.com/packer/integrations/hashicorp/azure/latest/components/builder/arm#configuration-reference).

The command below shows you how to provide these values to Packer as command line parameters.
You can also [specify them in the Packer template](https://learn.microsoft.com/azure/virtual-machines/linux/build-image-with-packer#define-packer-template)
or in a variables definition file, as described in [Customize Multiple Variables](#customize-multiple-variables).

Deploy the Packer build with the default settings, specifying the authentication and storage details.
```bash
packer build \
    -var CLIENT_ID = <client_id> \
    -var CLIENT_SECRET = <client_secret> \
    -var TENANT_ID = <tenant_id> \
    -var SUBSCRIPTION_ID = <subscription_id> \
    -var RESOURCE_GROUP_NAME = <resource_group> \
    build-azure-parallel-server.pkr.hcl
```

The Packer build can take about an hour to complete.
Packer writes its output, including the resource ID of the generated machine image, to a `manifest.json` file.
To use this resource ID to deploy the built image, see [Deploy Machine Image](#deploy-machine-image).


## **Customize Packer Build**
This section describes the different options for customising the build and the Packer build process.

### **Build-Time Variables**
The [Packer template](./build-azure-parallel-server.pkr.hcl)
supports these build-time variables.
| Argument Name | Default Value | Description |
|---|---|---|
| PRODUCTS            | MATLAB, MATLAB Parallel Server and all available toolboxes | Products to install, specified as a list of product names separated by spaces. For example, `MATLAB Simulink MATLAB_Parallel_Server Deep_Learning_Toolbox Parallel_Computing_Toolbox`. For details, see [Customize Products to Install](#customize-products-to-install). |
| [POLYSPACE_PRODUCTS](#customize-polyspace-products-to-install)| Polyspace® Bug Finder™ Server™ and Polyspace Code Prover™ Server™ | Polyspace products to install, specified as a list of product names separated by spaces. For example, `Polyspace_Bug_Finder_Server Polyspace_Code_Prover_Server`.<br/>If no products are specified, the Packer build will install Polyspace with Polyspace Bug Finder Server and Polyspace Code Prover Server. For more information, see [MATLAB Package Manager](https://github.com/mathworks-ref-arch/matlab-dockerfile/blob/main/MPM.md).|
| SPKGS | List of Deep Learning Support Packages, specified in [release-config](https://github.mathworks.com/development/parallel-server-aws-refarch/tree/dev/packer/v1/release-config) | A list of support packages to install, specified as a list of support package names separated by spaces. For example, `Deep_Learning_Toolbox_Model_for_GoogLeNet_Network Deep_Learning_Toolbox_Model_for_ResNet-101_Network` |
| CLIENT_ID           | *unset* | Client ID of Azure service principal. For more information on obtaining Azure service principal credentials, see [Create Azure credentials](https://learn.microsoft.com/en-us/azure/virtual-machines/linux/build-image-with-packer#create-azure-credentials). |
| CLIENT_SECRET       | *unset* | Client secret of Azure service principal. |
| TENANT_ID           | *unset* | Tenant ID of Azure service principal. |
| SUBSCRIPTION_ID     | *unset* | Azure subscription to use for the build. |
| RESOURCE_GROUP_NAME | *unset* | Resource group that will store the built image. |
| AZURE_TAGS          | {Name="Packer Build", Build="MATLAB Parallel Server", Type="matlab-parallel-server-on-azure"} | Tags applied by Packer to each deployed resource. |

For a full list of the variables used in the build, see the description fields in the
[Packer template](./build-azure-parallel-server.pkr.hcl).

### **Customize Products to Install**
Use the Packer build-time variable `PRODUCTS` to specify the list of products you want to install on the machine image.
If you do not specify any products, Packer installs MATLAB, MATLAB Parallel Server, and all the available toolboxes with the default toolboxes. To see the default toolboxes, go to the
[release-config](./release-config) folder, open the variable definition file for your release, and see the definition for the variable `PRODUCTS`.

For example, install the latest version of MATLAB and Deep Learning Toolbox.
This example assumes Azure authentication and storage details have been set in `build-azure-parallel-server.pkr.hcl`.
```bash
packer build -var="PRODUCTS=MATLAB MATLAB_Parallel_Server Deep_Learning_Toolbox" build-azure-parallel-server.pkr.hcl
```

Packer installs products using MATLAB Package Manager (mpm). For more information, see [MATLAB Package Manager (mpm)](https://github.com/mathworks-ref-arch/matlab-dockerfile/blob/main/MPM.md). 

### **Customize MATLAB Parallel Server Release to Install**
By default, the Packer build uses the latest MATLAB release. To install an earlier MATLAB release, use one of the variable definition files in the [release-config](./release-config) folder.

The following examples assume Azure authentication and storage details have been set in `build-azure-parallel-server.pkr.hcl`, or added to the `var-file`.

For example, install R2022b for MATLAB, MATLAB Parallel Server, and all available toolboxes.
```bash
packer build -var-file="release-config/R2022b.pkrvars.hcl" build-azure-parallel-server.pkr.hcl
```
Command line arguments can also be combined. For example, install R2022b for MATLAB, MATLAB Parallel Server, and the Parallel Computing Toolbox&trade; only.
```bash
packer build -var-file="release-config/R2022b.pkrvars.hcl" -var="PRODUCTS=MATLAB Parallel_Computing_Toolbox" build-azure-parallel-server.pkr.hcl
```
### **Customize Multiple Variables**
You can set multiple variables in a [Variable Definition File](https://developer.hashicorp.com/packer/docs/templates/hcl_templates/variables#standard-variable-definitions-files).

For example, to generate a machine image with the most recent MATLAB installed with additional toolboxes in a custom resource group,
create a variable definition file named `custom-variables.pkrvars.hcl` containing these variable definitions.
```
RESOURCE_GROUP_NAME = <resource_group>
PRODUCTS            = "MATLAB Deep_Learning_Toolbox Parallel_Computing_Toolbox"
```

Save the variable definition file and include it in the Packer build command.
The following example assumes Azure authentication and storage details have been set in `build-azure-parallel-server.pkr.hcl`, or added to `custom-variables.pkrvars.hcl`.
```bash
packer build -var-file="custom-variables.pkrvars.hcl" build-azure-parallel-server.pkr.hcl
```

## **Installation, Runtime, and Startup Scripts**
The Packer build executes scripts on the image builder instance during the build.
These scripts perform tasks such as installing tools needed by the build, installing MATLAB Parallel Server, MATLAB and toolboxes on the image using [MATLAB Package Manager (mpm)](https://github.com/mathworks-ref-arch/matlab-dockerfile/blob/main/MPM.md), and cleaning up build leftovers.

For the full list of scripts that the Packer build executes during the build, see the `BUILD_SCRIPTS` parameter in the [Packer template](https://github.com/mathworks-ref-arch/matlab-parallel-server-on-azure/blob/master/packer/v1/build-azure-parallel-server.pkr.hcl). The prebuilt images that MathWorks provides are built using these scripts as a base.

These scripts perform tasks such as mounting available storage, performing MATLAB startup acceleration, setting up MATLAB Job Scheduler, and setting up autoscaling scripts and cluster management scripts, among other utility tasks.

In addition to the build scripts above, the Packer build copies further scripts to the machine image, to be used during startup and at runtime.

For the full list of startup and runtime scripts, see the `STARTUP_SCRIPTS` and the `RUNTIME_SCRIPTS` parameters in the
[Packer template](https://github.com/mathworks-ref-arch/matlab-parallel-server-on-azure/blob/master/packer/v1/build-azure-parallel-server.pkr.hcl).

## Validate Packer Template
To validate the syntax and configuration of a Packer template, use the `packer validate` command. This command also checks whether the provided input variables meet the custom validation rules defined by MathWorks. For more information, see [validate command](https://www.packer.io/docs/commands/validate#validate-command).

You can also use command line interfaces provided by Packer to inspect and format the template. For more information, see [Packer Commands (CLI)](https://www.packer.io/docs/commands).

## Deploy Machine Image
When the build completes, Packer writes
the output to a `manifest.json` file, which contains these fields:
```json
{
  "builds": [
    {
      "name":,
      "builder_type": ,
      "build_time": ,
      "files": ,
      "artifact_id": ,
      "packer_run_uuid": ,
      "custom_data": {
        "build_scripts": ,
        "managed_image_resource_group_name": ,
        "release": ,
        "resource_group_name": ,
        "specified_polyspace_products": ,
        "specified_products": ,
        "specified_support_packages": ,
      }
    }
  ],
  "last_run_uuid": ""
}
```

The `artifact_id` section shows the resource ID of the custom managed image generated by each Packer build.

To deploy the custom machine image, see [Build and Deploy Your Own Machine Image](https://github.com/mathworks-ref-arch/matlab-parallel-server-on-azure/blob/master/README.md#build-and-deploy-your-own-machine-image).

If the build has been customized, for example by removing or modifying one or more of the included scripts, the resultant machine image might no longer be compatible with the provided ARM template. You can restore compatibility by making corresponding modifications to the ARM template.

If the image has been built from the [MATLAB on Azure](https://github.com/mathworks-ref-arch/matlab-on-azure-win) offering, then the resultant machine image **may not be compatible** due to missing autoscaling scripts, job scheduler setup, and other customizations.

## Technical Support
If you require assistance or have a request for additional features or capabilities, please contact [MathWorks Technical Support](https://www.mathworks.com/support/contact_us.html).

----

Copyright 2025-2026 The MathWorks, Inc.

----