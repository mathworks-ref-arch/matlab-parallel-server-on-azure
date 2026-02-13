# Copyright 2024 The MathWorks, Inc.

from mwplatforminterfaces import CloudInterface

from terminationpolicies import terminate_on_idle, terminate_on_schedule
from cluster_management_interface import ClusterManagementProgramInterface

from constants import (
    CLUSTER_READY_FOR_TERMINATION,
    FIRST_RUN_AFTER_REBOOT,
    LAST_TERMINATION_POLICY,
    CLUSTER_AUTO_TERMINATED,
    AUTOSCALING_ENABLED,
    INITIAL_DESIRED_CAPACITY,
    INITIAL_TERMINATION_POLICY,
)

import sys
from datetime import datetime, timezone


def start_termination_routine(
    cloud_interface: CloudInterface,
    cluster_management_interface: ClusterManagementProgramInterface,
) -> int:
    """
    Actions:
        - If autoscaling not enabled and cluster is restarted post auto-termination with no nodes,
          resize the cluster to initial capacity
        - Retrieves tag value of mw-autoshutdown tag from the head-node
        - Saves the tag value in the cluster_management_data JSON
        - Starts the relevant termination routine.

    If mw-autoshutdown tag = 'on_idle' => Start terminate_on_idle routine.
    If mw-autoshutdown tag = '<timestamp/After x hours(s)>' => Start autoshutdown routine.
    If mw-autoshutdown tag = 'never' => No action.

    Args:
        cloud_interface (CloudInterface): The interface to interact with the cloud.
        cluster_management_interface (ClusterManagementProgramInterface): Class to read and update
        dictionary containing state and config of the cluster management program.

    Returns: (int) termination_routine_status: Exit status of the active termination routine.
    """
    termination_routine_status = 0

    if cluster_management_interface.cluster_management_state[
        CLUSTER_READY_FOR_TERMINATION
    ]:
        # If cluster already marked for termination, no action is required
        return termination_routine_status

    # Re-initialize cluster to its initial capacity if autoscaling not enabled and first run after auto-termination
    cluster_reintialized = initialize_cluster_after_reboot(
        cloud_interface, cluster_management_interface
    )
    if cluster_reintialized:

        print("Retrieving mw-autoshutdown tag from the head node...")

        termination_policy = cloud_interface.get_cluster_termination_policy()
        termination_policy = backup_policy(
            termination_policy, cloud_interface, cluster_management_interface
        )

        print(f"mw-autoshutdown tag value is set to {termination_policy}")

        if termination_policy == "never":
            print("No termination policy to be implemented.")
        else:
            termination_routine = (
                terminate_on_idle
                if termination_policy == "on_idle"
                else terminate_on_schedule
            )
            print_status("start", termination_routine.__name__)
            termination_routine_status = termination_routine.main(
                cloud_interface, cluster_management_interface
            )
            print_status("end", termination_routine.__name__)

    return termination_routine_status


def backup_policy(
    termination_policy: str,
    cloud_interface: CloudInterface,
    cluster_management_interface: ClusterManagementProgramInterface,
) -> str:
    """
    Actions:
            - Backup the termination policy if it has changed since the last run and
              update the same in cluster_management_data JSON.
            - Resets to the last known value if tag cannot be retrieved or is empty.
    Args:
        termination_policy (str): The current termination policy to be backed up.
        cloud_interface (CloudInterface): The interface to interact with the cloud.
        cluster_management_interface (ClusterManagementProgramInterface): Class to read and update
        dictionary containing state and config of the cluster management program.

    Returns:
        str: The termination policy that has been backed up or reset to the last known value.

    Note:
        This method does not automatically persist changes to the cluster_management_data file.
        The file will only be updated when
        cluster_management_interface.update_cluster_management_data_file() is called.
    """
    last_termination_policy = cluster_management_interface.cluster_management_state[
        LAST_TERMINATION_POLICY
    ]
    initial_termination_policy = (
        cluster_management_interface.cluster_management_config[
            INITIAL_TERMINATION_POLICY
        ]
        or "never"
    )
    if termination_policy == "":
        print(
            "mw-autoshutdown tag value is empty or invalid. Resetting it to last known value."
        )
        if last_termination_policy:
            termination_policy = last_termination_policy
        else:
            # If last known policy is empty, the final choice for termination is set to the initial policy.
            termination_policy = initial_termination_policy

        policy_reset = cloud_interface.set_cluster_termination_policy(
            termination_policy
        )
        if not policy_reset:
            print(
                f"~ Failed to update mw-autoshutdown tag to {termination_policy}.",
                file=sys.stderr,
            )

    else:
        # If last_termination_policy is different from the current one, save the current one as backup
        if termination_policy != last_termination_policy:
            print(
                f"Backing up termination policy {termination_policy} in the cluster management data file."
            )
            cluster_management_interface.update_state(
                {LAST_TERMINATION_POLICY: termination_policy}
            )

    return termination_policy


def initialize_cluster_after_reboot(
    cloud_interface: CloudInterface,
    cluster_management_interface: ClusterManagementProgramInterface,
) -> bool:
    """
    Resize the cluster to initial desired capacity on first run after auto-shutdown.

    This is only run if autoscaling is not enabled and the cluster has zero worker nodes.

    Args:
        cloud_interface (CloudInterface): The interface to interact with the cloud.
        cluster_management_interface (ClusterManagementProgramInterface): Class to read and update
        dictionary containing state and config of the cluster management program.

    Returns:
        bool: True if the cluster was successfully resized or if no resizing was needed,
        False otherwise.
    """
    if cluster_management_interface.cluster_management_config[AUTOSCALING_ENABLED]:
        return True

    if not (
        cluster_management_interface.cluster_management_state[FIRST_RUN_AFTER_REBOOT]
        and cluster_management_interface.cluster_management_state[
            CLUSTER_AUTO_TERMINATED
        ]
    ):
        return True

    cloud_capacity = cloud_interface.get_cloud_capacity()

    if cloud_capacity is None:
        print(
            "~ There was an issue retrieving cloud capacities, exiting.",
            file=sys.stderr,
        )
        return False

    if cloud_capacity.current_nodes:
        return True

    initial_desired_capacity = cluster_management_interface.cluster_management_config[
        INITIAL_DESIRED_CAPACITY
    ]
    print(
        f"> Cluster was terminated by auto-shutdown. Setting the cloud capacity to initial desired capacity of {initial_desired_capacity} nodes."
    )
    set_cloud_capacity_status = cloud_interface.set_cloud_capacity(
        int(initial_desired_capacity)
    )
    if set_cloud_capacity_status:
        print(f"> Successfully set the cloud capacity to {initial_desired_capacity}.")
    else:
        print(
            f"~ Failed to set the cloud capacity to {initial_desired_capacity}.",
            file=sys.stderr,
        )
        return False

    cluster_management_interface.update_state({CLUSTER_AUTO_TERMINATED: False})

    return True


def print_status(start_or_end: str, policy_type: str) -> None:
    """
    Helper function to print time-stamps before and after starting a termination routine/autoscaling.
    """
    current_time = (datetime.now(timezone.utc)).strftime("%Y-%m-%d %H:%M:%S %Z")
    if start_or_end == "start":
        print(f"## Starting {policy_type}: {current_time} ##")
    elif start_or_end == "end":
        print(f"## Finished {policy_type}: {current_time} ##\n")
