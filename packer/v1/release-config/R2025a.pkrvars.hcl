# Copyright 2025-2026 The MathWorks, Inc.

// Use this Packer configuration file to build an Azure managed image with MATLAB Parallel Server R2025a installed.
// For more information on these variables, see /packer/build-azure-parallel-server.pkr.hcl.
RELEASE = "R2025a"
STARTUP_SCRIPTS = [
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
RUNTIME_SCRIPTS = [
  "cluster_management",
  "mwplatforminterfaces"
]
BUILD_SCRIPTS = [
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
PRODUCTS                    = "5G_Toolbox AUTOSAR_Blockset Aerospace_Blockset Aerospace_Toolbox Antenna_Toolbox Audio_Toolbox Automated_Driving_Toolbox Bioinformatics_Toolbox Bluetooth_Toolbox C2000_Microcontroller_Blockset Communications_Toolbox Computer_Vision_Toolbox Control_System_Toolbox Curve_Fitting_Toolbox DDS_Blockset DSP_HDL_Toolbox DSP_System_Toolbox Database_Toolbox Datafeed_Toolbox Deep_Learning_HDL_Toolbox Deep_Learning_Toolbox Econometrics_Toolbox Embedded_Coder Financial_Instruments_Toolbox Financial_Toolbox Fixed-Point_Designer Fuzzy_Logic_Toolbox GPU_Coder Global_Optimization_Toolbox HDL_Coder HDL_Verifier Image_Acquisition_Toolbox Image_Processing_Toolbox Industrial_Communication_Toolbox Instrument_Control_Toolbox LTE_Toolbox Lidar_Toolbox MATLAB MATLAB_Coder MATLAB_Compiler MATLAB_Compiler_SDK MATLAB_Parallel_Server MATLAB_Report_Generator MATLAB_Test MATLAB_Web_App_Server Mapping_Toolbox Medical_Imaging_Toolbox Mixed-Signal_Blockset Model_Predictive_Control_Toolbox Motor_Control_Blockset Navigation_Toolbox Optimization_Toolbox Parallel_Computing_Toolbox Partial_Differential_Equation_Toolbox Phased_Array_System_Toolbox Powertrain_Blockset Predictive_Maintenance_Toolbox RF_Blockset RF_PCB_Toolbox RF_Toolbox ROS_Toolbox Radar_Toolbox Reinforcement_Learning_Toolbox Requirements_Toolbox Risk_Management_Toolbox Robotics_System_Toolbox Robust_Control_Toolbox Satellite_Communications_Toolbox Sensor_Fusion_and_Tracking_Toolbox SerDes_Toolbox Signal_Integrity_Toolbox Signal_Processing_Toolbox SimBiology SimEvents Simscape Simscape_Battery Simscape_Driveline Simscape_Electrical Simscape_Fluids Simscape_Multibody Simulink Simulink_3D_Animation Simulink_Check Simulink_Coder Simulink_Compiler Simulink_Control_Design Simulink_Coverage Simulink_Design_Optimization Simulink_Design_Verifier Simulink_Desktop_Real-Time Simulink_Fault_Analyzer Simulink_PLC_Coder Simulink_Real-Time Simulink_Report_Generator Simulink_Test SoC_Blockset Stateflow Statistics_and_Machine_Learning_Toolbox Symbolic_Math_Toolbox System_Composer System_Identification_Toolbox Text_Analytics_Toolbox UAV_Toolbox Vehicle_Dynamics_Blockset Vehicle_Network_Toolbox Vision_HDL_Toolbox WLAN_Toolbox Wavelet_Toolbox Wireless_HDL_Toolbox Wireless_Testbench"
POLYSPACE_PRODUCTS          = "Polyspace_Bug_Finder Polyspace_Bug_Finder_Server Polyspace_Code_Prover Polyspace_Code_Prover_Server Polyspace_Test"
SPKGS                       = "Deep_Learning_Toolbox_Model_for_AlexNet_Network Deep_Learning_Toolbox_Model_for_EfficientNet-b0_Network Deep_Learning_Toolbox_Model_for_GoogLeNet_Network Deep_Learning_Toolbox_Model_for_ResNet-101_Network Deep_Learning_Toolbox_Model_for_ResNet-18_Network Deep_Learning_Toolbox_Model_for_ResNet-50_Network Deep_Learning_Toolbox_Model_for_Inception-ResNet-v2_Network Deep_Learning_Toolbox_Model_for_Inception-v3_Network Deep_Learning_Toolbox_Model_for_DenseNet-201_Network Deep_Learning_Toolbox_Model_for_Xception_Network Deep_Learning_Toolbox_Model_for_MobileNet-v2_Network Deep_Learning_Toolbox_Model_for_Places365-GoogLeNet_Network Deep_Learning_Toolbox_Model_for_NASNet-Large_Network Deep_Learning_Toolbox_Model_for_NASNet-Mobile_Network Deep_Learning_Toolbox_Model_for_ShuffleNet_Network Deep_Learning_Toolbox_Model_for_DarkNet-19_Network Deep_Learning_Toolbox_Model_for_DarkNet-53_Network Deep_Learning_Toolbox_Model_for_VGG-16_Network Deep_Learning_Toolbox_Model_for_VGG-19_Network"
NVIDIA_DRIVER_INSTALLER_URL = "https://us.download.nvidia.com/tesla/538.15/538.15-data-center-tesla-desktop-winserver-2019-2022-dch-international.exe"
PYTHON_INSTALLER_URL        = "https://www.python.org/ftp/python/3.10.5/python-3.10.5-amd64.exe"
IMAGE_PUBLISHER             = "MicrosoftWindowsServer"
IMAGE_OFFER                 = "WindowsServer"
IMAGE_SKU                   = "2022-Datacenter"
