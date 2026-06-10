# Copyright 2024-2026 The MathWorks, Inc.

from typing import Dict, Type

# File to store constants that are used throughout modules of the Cluster Management program.

# Return statuses (int): Status code of the cluster management program.
STATUS_SUCCESS = 0
STATUS_CLOUD_ISSUE = 1
STATUS_CLUSTER_ISSUE = 2
STATUS_CLOUD_AND_CLUSTER_ISSUE = 3
STATUS_INTERNAL_READ_WRITE_ISSUE = 4

# Cluster management program state variables
CLUSTER_READY_FOR_TERMINATION = "cluster_ready_for_termination"
WAS_MJS_BUSY = "was_mjs_busy"
FIRST_RUN_AFTER_REBOOT = "first_run_after_reboot"
LAST_TERMINATION_POLICY = "last_termination_policy"
LAST_OS_BOOT_TIME = "last_os_boot_time"
CLUSTER_AUTO_TERMINATED = "cluster_auto_terminated"

# Type information for cluster management program state variables (needed for validation)
STATE_VARIABLES_TYPES: Dict[str, Type] = {
    CLUSTER_READY_FOR_TERMINATION: bool,
    WAS_MJS_BUSY: bool,
    FIRST_RUN_AFTER_REBOOT: bool,
    LAST_TERMINATION_POLICY: str,
    LAST_OS_BOOT_TIME: str,
    CLUSTER_AUTO_TERMINATED: bool,
}

# Cluster management program config variables. These are configuration parameters that should not be modified by the program.
AUTOSCALING_ENABLED = "autoscaling_enabled"
AUTOTERMINATION_ENABLED = "autotermination_enabled"
INITIAL_TERMINATION_POLICY = "initial_termination_policy"
INITIAL_DESIRED_CAPACITY = "initial_desired_capacity"
CUSTOM_DNS_SUFFIX = "custom_dns_suffix"
USE_PRIVATE_IP_MAPPING = "use_private_ip_mapping"

# Cluster management program related variables
CLUSTER_MANAGEMENT_LOG_FILE = "C:\\ProgramData\\MathWorks\\clustermanagement.log"
MJS_STATUS_LOG_FILE = "C:\\ProgramData\\MathWorks\\mjs_status_transitions.log"
MAX_LOG_FILE_SIZE = 1e6
MAX_LOG_BACKUP_FILES = 5
HEALTH_CHECK_GRACE_PERIOD_SECONDS = 600
