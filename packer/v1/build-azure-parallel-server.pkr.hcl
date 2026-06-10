# Copyright 2024-2026 The MathWorks, Inc.
packer {
  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = "~> 2"
    }
  }
}

# The following variables may have different values across MATLAB releases.
# MathWorks recommends that you modify them via the configuration file specific to each release.
# To see the release-specific values, open the configuration file
# in the /packer/v1/release-config/ folder.
variable "PRODUCTS" {
  type        = string
  description = "Target products to install in the machine image, e.g. MATLAB MATLAB_Parallel_Server."
  default     = "5G_Toolbox AUTOSAR_Blockset Aerospace_Blockset Aerospace_Toolbox Antenna_Toolbox Audio_Toolbox Automated_Driving_Toolbox Bioinformatics_Toolbox Bluetooth_Toolbox C2000_Microcontroller_Blockset Communications_Toolbox Computer_Vision_Toolbox Control_System_Toolbox Curve_Fitting_Toolbox DDS_Blockset DSP_HDL_Toolbox DSP_System_Toolbox Database_Toolbox Datafeed_Toolbox Deep_Learning_HDL_Toolbox Deep_Learning_Toolbox Econometrics_Toolbox Embedded_Coder Financial_Instruments_Toolbox Financial_Toolbox Fixed-Point_Designer Fuzzy_Logic_Toolbox GPU_Coder Global_Optimization_Toolbox HDL_Coder HDL_Verifier Image_Acquisition_Toolbox Image_Processing_Toolbox Industrial_Communication_Toolbox Instrument_Control_Toolbox LTE_Toolbox Lidar_Toolbox MATLAB MATLAB_Coder MATLAB_Compiler MATLAB_Compiler_SDK MATLAB_Parallel_Server MATLAB_Report_Generator MATLAB_Test MATLAB_Web_App_Server Mapping_Toolbox Medical_Imaging_Toolbox Mixed-Signal_Blockset Model_Predictive_Control_Toolbox Motor_Control_Blockset Navigation_Toolbox Optimization_Toolbox Parallel_Computing_Toolbox Partial_Differential_Equation_Toolbox Phased_Array_System_Toolbox Powertrain_Blockset Predictive_Maintenance_Toolbox RF_Blockset RF_PCB_Toolbox RF_Toolbox ROS_Toolbox Radar_Toolbox Reinforcement_Learning_Toolbox Requirements_Toolbox Risk_Management_Toolbox Robotics_System_Toolbox Robust_Control_Toolbox Satellite_Communications_Toolbox Sensor_Fusion_and_Tracking_Toolbox SerDes_Toolbox Signal_Integrity_Toolbox Signal_Processing_Toolbox SimBiology SimEvents Simscape Simscape_Battery Simscape_Driveline Simscape_Electrical Simscape_Fluids Simscape_Multibody Simulink Simulink_3D_Animation Simulink_Check Simulink_Coder Simulink_Compiler Simulink_Control_Design Simulink_Coverage Simulink_Design_Optimization Simulink_Design_Verifier Simulink_Desktop_Real-Time Simulink_Fault_Analyzer Simulink_PLC_Coder Simulink_Real-Time Simulink_Report_Generator Simulink_Test SoC_Blockset Stateflow Statistics_and_Machine_Learning_Toolbox Symbolic_Math_Toolbox System_Composer System_Identification_Toolbox Text_Analytics_Toolbox UAV_Toolbox Vehicle_Dynamics_Blockset Vehicle_Network_Toolbox Vision_HDL_Toolbox WLAN_Toolbox Wavelet_Toolbox Wireless_HDL_Toolbox Wireless_Testbench Wireless_Network_Toolbox Simulink_FMU_Builder Raspberry_Pi_Blockset STM32_Microcontroller_Blockset"
}

variable "SPKGS" {
  type        = string
  description = "Target support packages to install in the machine image, e.g. Deep_Learning_Toolbox_Model_for_AlexNet_Network."
  default     = "Deep_Learning_Toolbox_Model_for_AlexNet_Network Deep_Learning_Toolbox_Model_for_EfficientNet-b0_Network Deep_Learning_Toolbox_Model_for_GoogLeNet_Network Deep_Learning_Toolbox_Model_for_ResNet-101_Network Deep_Learning_Toolbox_Model_for_ResNet-18_Network Deep_Learning_Toolbox_Model_for_ResNet-50_Network Deep_Learning_Toolbox_Model_for_Inception-ResNet-v2_Network Deep_Learning_Toolbox_Model_for_Inception-v3_Network Deep_Learning_Toolbox_Model_for_DenseNet-201_Network Deep_Learning_Toolbox_Model_for_Xception_Network Deep_Learning_Toolbox_Model_for_MobileNet-v2_Network Deep_Learning_Toolbox_Model_for_Places365-GoogLeNet_Network Deep_Learning_Toolbox_Model_for_NASNet-Large_Network Deep_Learning_Toolbox_Model_for_NASNet-Mobile_Network Deep_Learning_Toolbox_Model_for_ShuffleNet_Network Deep_Learning_Toolbox_Model_for_DarkNet-19_Network Deep_Learning_Toolbox_Model_for_DarkNet-53_Network Deep_Learning_Toolbox_Model_for_VGG-16_Network Deep_Learning_Toolbox_Model_for_VGG-19_Network"
}

variable "POLYSPACE_PRODUCTS" {
  type        = string
  description = "Target product names for Polyspace"
  default     = "Polyspace_Bug_Finder Polyspace_Bug_Finder_Server Polyspace_Code_Prover Polyspace_Code_Prover_Server Polyspace_Test"
}

variable "RELEASE" {
  type        = string
  default     = "R2026a"
  description = "Target MATLAB release to install in the machine image, must start with \"R\"."

  validation {
    condition     = can(regex("^R20[0-9][0-9](a|b)(U[0-9])?$", var.RELEASE))
    error_message = "The RELEASE value must be a valid MATLAB release, starting with \"R\"."
  }
}

variable "MATLAB_INSTALL_PATH" {
  type        = string
  default     = "C:/Program Files/MATLAB"
  description = "Target path that will contain MATLAB installation."
}

variable "MSA_URL" {
  type        = string
  description = "URL pointing to a valid MATLAB Startup Accelerator file. If left unset, a default URL will be constructed based on the RELEASE variable."
  default     = null
}

variable "MATLAB_SOURCE_LOCATION" {
  type        = string
  default     = ""
  description = "Optional parameter which holds the location from which to install MATLAB and toolboxes, for use with the mpm --source option."
}

variable "BUILD_SCRIPTS" {
  type = list(string)
  default = [
    "Install-Dependencies.ps1",
    "Install-StartupScripts.ps1",
    "Install-RuntimeScripts.ps1",
    "Install-NVIDIADrivers.ps1",
    "Initialize-SourceLocation.ps1",
    "Install-MATLAB.ps1",
    "Install-Polyspace.ps1",
    "Install-SupportPackages.ps1",
    "Initialize-MATLAB.ps1",
    "Initialize-Polyspace.ps1",
    "Optimize-MATLAB.ps1",
    "Remove-IE.ps1",
    "Disable-Popups.ps1"
  ]
  description = "The list of installation scripts Packer will use when building the image."
}

variable "STARTUP_SCRIPTS" {
  type = list(string)
  default = [
    "env.ps1",
    "00_Set-CustomDNSSuffix.ps1",
    "10_Setup-Disk.ps1",
    "20_Setup-MATLAB.ps1",
    "30_Setup-Polyspace.ps1",
    "40_Warmup-MATLAB.ps1",
    "50_Edit-MJS-Def.ps1",
    "60_Setup-MJS.ps1",
    "70_Start-MJS.ps1",
    "80_Initialize-ClusterManagementProgram.ps1",
    "90_Add-SpotInstanceMonitoring.ps1",
    "Setup-MJSHostname.ps1"
  ]
  description = "The list of startup scripts Packer will copy to the remote machine image builder, which can be used during resource group creation."
}

variable "RUNTIME_SCRIPTS" {
  type = list(string)
  default = [
    "cluster_management",
    "mwplatforminterfaces"
  ]
  description = "The list of runtime script directories Packer will copy to the remote machine image builder, which can be used after resource group creation."
}

variable "NVIDIA_DRIVER_INSTALLER_URL" {
  type        = string
  default     = "https://us.download.nvidia.com/tesla/538.15/538.15-data-center-tesla-desktop-winserver-2019-2022-dch-international.exe"
  description = "The URL to install NVIDIA drivers into the target machine image."
}

variable "PYTHON_INSTALLER_URL" {
  type        = string
  default     = "https://www.python.org/ftp/python/3.10.5/python-3.10.5-amd64.exe"
  description = "The URL to install python into the target machine image."
}

variable "TENANT_ID" {
  type        = string
  description = "The Microsoft Entra ID tenant identifier with which your client_id and subscription_id are associated."
  sensitive   = true
}

variable "SUBSCRIPTION_ID" {
  type        = string
  description = "Subscription under which the build will be performed."
  sensitive   = true
}

variable "CLIENT_ID" {
  type        = string
  description = "The Microsoft Entra ID service principal associated with your builder."
  sensitive   = true
}

variable "CLIENT_SECRET" {
  type        = string
  description = "The password or secret for your service principal."
  sensitive   = true
}

variable "USER_ASSIGNED_MANAGED_IDENTITIES" {
  type        = list(string)
  default     = []
  description = "List of resource IDs of user-assigned managed identities to assign to the Packer builder Virtual Machine."
  sensitive   = true
}

variable "AZURE_KEY_VAULT" {
  type        = string
  default     = ""
  description = "Optional parameter to enter an Azure Key Vault name that can be used to store or retrieve sensitive information during Packer builds."
  sensitive   = true
}

variable "RESOURCE_GROUP_NAME" {
  type        = string
  default     = ""
  description = "Resource group under which the final artifact will be stored"
}


variable "AZURE_TAGS" {
  type = map(string)
  default = {
    Name  = "Packer Build"
    Build = "MATLAB Parallel Server"
    Type  = "Windows"
  }
  description = "The tags Packer applies to every deployed resource."
}

variable "MANIFEST_OUTPUT_FILE" {
  type        = string
  default     = "manifest.json"
  description = "The name of the resultant manifest file."
}

variable "PACKER_ADMIN_USERNAME" {
  type        = string
  default     = "packer"
  description = "Username for the build instance."
}

variable "IMAGE_PUBLISHER" {
  type        = string
  default     = "MicrosoftWindowsServer"
  description = "The publisher of the base image used for customization."
}

variable "IMAGE_OFFER" {
  type        = string
  default     = "WindowsServer"
  description = "The offer of the base image used for customization."
}

variable "IMAGE_SKU" {
  type        = string
  default     = "2022-Datacenter"
  description = "Version of the base image used for customization."
}

variable "VM_SIZE" {
  type        = string
  default     = "Standard_NC4as_T4_v3"
  description = "Size of base Azure VM to be used for the Packer build."

}

# Optional networking configuration for the Packer Builder VM
variable "VIRTUAL_NETWORK_NAME" {
  type        = string
  default     = ""
  description = "(Optional) The name of the virtual network to use for the Packer builder VM."
}

variable "SUBNET_NAME" {
  type        = string
  default     = ""
  description = "(Optional) The name of the subnet within the virtual network to use for the Packer builder VM."
}

variable "VIRTUAL_NETWORK_RESOURCE_GROUP" {
  type        = string
  default     = ""
  description = "(Optional) Name of the resource group containing the virtual network to use for the Packer builder VM."
}

# Optional SSH Bastion host configuration
variable "SSH_BASTION_HOST" {
  type        = string
  default     = ""
  description = "(Optional) A bastion host to use for the actual SSH connection."
}

variable "SSH_BASTION_USERNAME" {
  type        = string
  default     = ""
  description = "(Optional) The username to use when connecting to the bastion host via SSH."
}

variable "SSH_BASTION_PASSWORD" {
  type        = string
  default     = ""
  description = "(Optional) The password to use when connecting to the bastion host via SSH."
}

# Set up local variables used by provisioners.
locals {
  image_uuid            = uuidv4()
  matlab_release_number = replace(replace(replace(var.RELEASE, "a", "1"), "b", "2"), "R", "")
  matlab_root           = "${trim(var.MATLAB_INSTALL_PATH, "/")}/${var.RELEASE}"
  build_scripts         = [for s in var.BUILD_SCRIPTS : format("build/%s", s)]
  startup_scripts       = [for s in var.STARTUP_SCRIPTS : format("startup/%s", s)]
  runtime_scripts       = [for s in var.RUNTIME_SCRIPTS : format("runtime/%s", s)]
  # This local variable decides which URL to use.
  # If var.MSA_URL is not null (meaning the user provided an override), use that value.
  # Otherwise, construct the URL using var.RELEASE.
  effective_msa_url = var.MSA_URL != null ? var.MSA_URL : "https://raw.githubusercontent.com/mathworks-ref-arch/iac-building-blocks/refs/heads/main/common/artifacts/msa/${var.RELEASE}/Windows/msa.ini"
}

# Configure the AZURE instance that is used to build the machine image.
source "azure-arm" "Image_Builder" {
  communicator = "ssh"
  ssh_username = "${var.PACKER_ADMIN_USERNAME}"
  # Inject SSH setup script as base64 encoded user-data
  user_data = base64encode(file("./build/config/packer/Enable-OpenSSH.ps1"))
  # Use custom script extension for Windows VMs to run the user-data
  custom_script = "powershell.exe -Command \"$UserData = [scriptblock]::Create([System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String((Invoke-RestMethod -Headers @{Metadata='true'} -Method GET -Uri 'http://169.254.169.254/metadata/instance/compute/userData?api-version=2021-01-01&format=text')))); Invoke-Command -ScriptBlock $UserData\""

  # Optional configuration for SSH Bastion Host setup
  ssh_bastion_host     = "${var.SSH_BASTION_HOST}"
  ssh_bastion_username = "${var.SSH_BASTION_USERNAME}"
  ssh_bastion_password = "${var.SSH_BASTION_PASSWORD}"

  # Optional networking setup for the Packer Builder VM
  virtual_network_name                = "${var.VIRTUAL_NETWORK_NAME}"
  virtual_network_resource_group_name = "${var.VIRTUAL_NETWORK_RESOURCE_GROUP}"
  virtual_network_subnet_name         = "${var.SUBNET_NAME}"

  # Assigning a Public IP to the Packer Builder VM for internet connectivity
  private_virtual_network_with_public_ip = "true"

  client_id                         = "${var.CLIENT_ID}"
  client_secret                     = "${var.CLIENT_SECRET}"
  managed_image_resource_group_name = "${var.RESOURCE_GROUP_NAME}"
  subscription_id                   = "${var.SUBSCRIPTION_ID}"
  tenant_id                         = "${var.TENANT_ID}"
  user_assigned_managed_identities  = "${var.USER_ASSIGNED_MANAGED_IDENTITIES}"
  managed_image_name                = "parallelserverwin-${var.RELEASE}-${local.image_uuid}"
  os_type                           = "Windows"
  image_publisher                   = "${var.IMAGE_PUBLISHER}"
  image_offer                       = "${var.IMAGE_OFFER}"
  image_sku                         = "${var.IMAGE_SKU}"
  azure_tags                        = "${var.AZURE_TAGS}"
  location                          = "East US"
  vm_size                           = "${var.VM_SIZE}"
  os_disk_size_gb                   = "128"
}

# Build the machine image.
build {
  sources = ["source.azure-arm.Image_Builder"]
  provisioner "file" {
    destination = "C:/Windows/Temp/"
    source      = "build/config"
  }

  provisioner "powershell" {
    inline = [
      "New-Item -Path 'C:/Windows/Temp/startup' -ItemType Directory -Force",
      "New-Item -Path 'C:/Windows/Temp/runtime' -ItemType Directory -Force"
    ]
  }

  provisioner "file" {
    destination = "C:/Windows/Temp/startup/"
    sources     = "${local.startup_scripts}"
  }

  provisioner "file" {
    destination = "C:/Windows/Temp/runtime/"
    sources     = "${local.runtime_scripts}"
  }

  provisioner "powershell" {
    environment_vars = [
      "RELEASE=${var.RELEASE}",
      "PRODUCTS=${var.PRODUCTS}",
      "SPKGS=${var.SPKGS}",
      "POLYSPACE_PRODUCTS=${var.POLYSPACE_PRODUCTS}",
      "NVIDIA_DRIVER_INSTALLER_URL=${var.NVIDIA_DRIVER_INSTALLER_URL}",
      "PYTHON_INSTALLER_URL=${var.PYTHON_INSTALLER_URL}",
      "MATLAB_ROOT=${local.matlab_root}",
      "MSA_URL=${local.effective_msa_url}",
      "MATLAB_SOURCE_LOCATION=${var.MATLAB_SOURCE_LOCATION}",
      "AZURE_KEY_VAULT=${var.AZURE_KEY_VAULT}"
    ]
    scripts = "${local.build_scripts}"
  }
  provisioner "powershell" {
    environment_vars = [
      "RELEASE=${var.RELEASE}"
    ]
    scripts = ["build/Remove-TemporaryFiles.ps1"]
  }
  provisioner "windows-restart" {
    restart_check_command = "powershell -command \"& {Write-Output 'restarted.'}\""
    restart_timeout       = "10m"
  }
  provisioner "powershell" {
    pause_before = "90s"
    scripts      = ["build/Invoke-Sysprep.ps1"]
  }
  post-processor "manifest" {
    output     = "${var.MANIFEST_OUTPUT_FILE}"
    strip_path = true
    custom_data = {
      release                           = "MATLAB ${var.RELEASE}"
      specified_products                = "${var.PRODUCTS}"
      specified_polyspace_products      = "${var.POLYSPACE_PRODUCTS}"
      specified_support_packages        = "${var.SPKGS}"
      build_scripts                     = join(", ", "${var.BUILD_SCRIPTS}")
      resource_group_name               = "${var.RESOURCE_GROUP_NAME}"
      managed_image_resource_group_name = "${var.RESOURCE_GROUP_NAME}"
    }
  }
}
