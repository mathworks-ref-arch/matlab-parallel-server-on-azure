# Copyright 2024-2026 The MathWorks, Inc.

from mwplatforminterfaces import CloudInterface
from mwplatforminterfaces import OSInterface

from autoscaling import autoscaling
from utils import helpers
from utils import terminate_cluster
from cluster_management_interface import ClusterManagementProgramInterface

import logging
from logging.handlers import RotatingFileHandler
import sys

from constants import (
    STATUS_SUCCESS,
    STATUS_INTERNAL_READ_WRITE_ISSUE,
    CLUSTER_READY_FOR_TERMINATION,
    AUTOSCALING_ENABLED,
    AUTOTERMINATION_ENABLED,
    CLUSTER_MANAGEMENT_LOG_FILE,
    MAX_LOG_FILE_SIZE,
    MAX_LOG_BACKUP_FILES,
    CUSTOM_DNS_SUFFIX,
    USE_PRIVATE_IP_MAPPING,
)


def main() -> int:
    """Execute the cluster management program.

    The program has two routines that are executed according to the user's choice:
        1. Auto-scaling: Resize cluster based on workload. Executed if data['config']['autoscaling_enabled'] is True.
           This choice is saved in cluster management data JSON file.

        2. Termination policy routine:
            - Termination when idle: Terminate the whole cluster if MJS is idle for a certain amount of time, or,
            - Termination on schedule: Terminate the whole cluster after a certain amount of time decided by the user.

    Termination policies are dictated by the tag mw-autoshutdown in the head-node.

        1. Auto-scaling: Resize cluster based on workload. Executed if cluster_management_config[AUTOSCALING_ENABLED] is True.
           This choice is saved in cluster management data JSON file.

    Returns:
        status (int): Status code of program.
            0: Successful
            1: Faced an issue with cloud provider
            2: Faced an issue with cluster
            3: Faced an issue with both
            4: Faced an issue while reading/writing cluster management data json
    """
    # Initialize status variables
    autoscaling_status = STATUS_SUCCESS
    termination_routine_status = STATUS_SUCCESS
    cluster_termination_status = STATUS_SUCCESS

    print("Reading the cluster management program data file...")
    cluster_management_interface = ClusterManagementProgramInterface()

    if not cluster_management_interface.class_init_success:
        print("Cluster management data file is empty. Read failed.")
        return STATUS_INTERNAL_READ_WRITE_ISSUE
    
    # The custom_dns_suffix variable contains the custom DNS search 
    # suffix used to identify worker nodes
    custom_dns_suffix = cluster_management_interface.cluster_management_config[
        CUSTOM_DNS_SUFFIX
    ]

    # The use_private_ip_mapping boolean variable determines whether 
    # private IP addresses should be used
    # to identify worker nodes, instead of hostnames
    use_private_ip_mapping = cluster_management_interface.cluster_management_config[
        USE_PRIVATE_IP_MAPPING
    ]

    print("Connecting to the cloud computing platform...")
    cloud_interface = CloudInterface(
        custom_dns_suffix=custom_dns_suffix,
        use_private_ip_mapping=use_private_ip_mapping,
    )

    print("Connecting to cluster...")
    os_interface = OSInterface()


    # Start autoscaling if it is enabled
    if (
        cluster_management_interface.cluster_management_config[AUTOSCALING_ENABLED]
        and not cluster_management_interface.cluster_management_state[
            CLUSTER_READY_FOR_TERMINATION
        ]
        and os_interface.is_mjs_running()
    ):
        helpers.print_status("start", "autoscaling")
        autoscaling_status = autoscaling.main(cloud_interface, os_interface)
        helpers.print_status("end", "autoscaling")

    if cluster_management_interface.cluster_management_config[AUTOTERMINATION_ENABLED]:
        # Assess the termination policy set on the head-node and execute if set
        termination_routine_status = helpers.start_termination_routine(
            cloud_interface,
            cluster_management_interface,
        )

    if not cluster_management_interface.update_cluster_management_data_file():
        print("Unable to update cluster management data file. Exiting...")
        return STATUS_INTERNAL_READ_WRITE_ISSUE

    if cluster_management_interface.cluster_management_state[
        CLUSTER_READY_FOR_TERMINATION
    ]:
        print(
            "Cluster marked as ready for termination in the cluster management data file. Starting cluster termination..."
        )
        cluster_termination_status = terminate_cluster.main(
            cloud_interface,
            os_interface,
            cluster_management_interface,
        )

    return max(
        autoscaling_status, termination_routine_status, cluster_termination_status
    )


if __name__ == "__main__":
    # Create logger
    logger = logging.getLogger("mw.clustermanagement")
    log_file = "C:\\ProgramData\\MathWorks\\clustermanagement.log"
    log_handler = RotatingFileHandler(
        CLUSTER_MANAGEMENT_LOG_FILE,
        maxBytes=MAX_LOG_FILE_SIZE,
        backupCount=MAX_LOG_BACKUP_FILES,
    )
    log_handler.terminator = ""
    logger.addHandler(log_handler)
    logger.setLevel(logging.INFO)
    sys.stdout.write, sys.stderr.write = logger.info, logger.warning

    helpers.print_status("start", "cluster management program")
    status = main()
    helpers.print_status("end", "cluster management program")

    sys.exit(status)
