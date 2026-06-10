#!/usr/bin/env python3

# Copyright 2024-2026 The MathWorks, Inc.

from mwplatforminterfaces import CloudInterface
from mwplatforminterfaces import OSInterface

from cluster_management_interface import ClusterManagementProgramInterface
from constants import (
    STATUS_SUCCESS,
    STATUS_CLOUD_ISSUE,
    STATUS_CLUSTER_ISSUE,
    STATUS_CLOUD_AND_CLUSTER_ISSUE,
    INITIAL_TERMINATION_POLICY,
    MJS_STATUS_LOG_FILE,
    LAST_TERMINATION_POLICY,
)

import os


def main(
    cloud_interface: CloudInterface,
    os_interface: OSInterface,
    cluster_management_interface: ClusterManagementProgramInterface,
) -> int:
    """
    Execute the terminate cluster routine.

    Args:
        cloud_interface (CloudInterface): The interface to interact with the cloud services.
        os_interface (OSInterface): The interface to interact with the operating system.
        cluster_management_interface (ClusterManagementProgramInterface): Class to read and update
        dictionary containing state and config of the cluster management program.

    Returns:
        status (int): Status code of program.
                        0: Successful
                        1: Faced an issue with cloud provider
                        2: Faced an issue with cluster
                        3: Faced an issue with both

    """
    # Initialize status variables
    cluster_issue, cloud_issue = False, False

    initial_termination_policy = (
        cluster_management_interface.cluster_management_config[
            INITIAL_TERMINATION_POLICY
        ]
        or "never"
    )

    # Get the worker nodes registered with MJS
    worker_nodes = os_interface.get_worker_nodes()
    if worker_nodes:
        nodes_stopped = os_interface.stop_workers_on_nodes(worker_nodes)
        if nodes_stopped:
            print(f"> Stopped workers on {len(nodes_stopped)} nodes")

        if worker_nodes != nodes_stopped:
            failed_nodes = worker_nodes - nodes_stopped
            print(
                f"~ Failed to stop workers on {len(failed_nodes)} nodes:"
                f" {failed_nodes}. Skipping cluster termination."
            )
            cluster_issue = True

    if not cluster_issue:
        cluster_scaled_to_zero = cloud_interface.scale_cluster_to_zero()
        if cluster_scaled_to_zero:
            print("> Successfully deleted all nodes in the VMSS.")
            print("> Stopping MATLAB Job Scheduler service...")
            jobmanager_stopped = os_interface.stop_job_manager()
            mjs_stopped = False
            if jobmanager_stopped:
                mjs_stopped = os_interface.stop_mjs()
            if not mjs_stopped or not jobmanager_stopped:
                print(
                    "~ Failed to stop MATLAB Job Scheduler on head-node. Skipping head-node termination."
                )
                cluster_issue = True
            else:
                print(
                    f"> Resetting the cluster termination policy to the initial choice: {initial_termination_policy}..."
                )
                policy_reset = cloud_interface.set_cluster_termination_policy(
                    initial_termination_policy
                )
                if policy_reset:
                    if os.path.exists(MJS_STATUS_LOG_FILE):
                        os.remove(MJS_STATUS_LOG_FILE)
                        print(f"> Deleting {MJS_STATUS_LOG_FILE} file...")

                    # Update the last termination policy in the cluster management data file as it might become stale
                    # by the time the headnode is restarted in case the policy is a time-stamp
                    cluster_management_interface.update_state(
                        {LAST_TERMINATION_POLICY: initial_termination_policy}
                    )

                    print("> Attempting to deallocate the head-node...")
                    headnode_deallocated = cloud_interface.deallocate_headnode()
                    if not headnode_deallocated:
                        print("~ Failed to deallocate the head-node...")
                        cloud_issue = True
                else:
                    cloud_issue = True
                    print(
                        "~ Failed to reset the cluster termination policy. Skipping head-node deallocation."
                    )
        else:
            print("~ Failed to scale VMSS down to zero.")
            cloud_issue = True

    if cloud_issue and cluster_issue:
        return STATUS_CLOUD_AND_CLUSTER_ISSUE
    elif cloud_issue:
        return STATUS_CLOUD_ISSUE
    elif cluster_issue:
        return STATUS_CLUSTER_ISSUE
    else:
        return STATUS_SUCCESS
