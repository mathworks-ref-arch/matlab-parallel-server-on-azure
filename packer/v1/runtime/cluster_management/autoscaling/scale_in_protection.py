# Copyright 2022-2026 The MathWorks, Inc.

from mwplatforminterfaces import CloudInterface
from mwplatforminterfaces import OSInterface


from constants import (
    STATUS_SUCCESS,
    STATUS_CLOUD_ISSUE,
    STATUS_CLUSTER_ISSUE,
    STATUS_CLOUD_AND_CLUSTER_ISSUE,
)


def main(cloud_interface: CloudInterface, os_interface: OSInterface) -> int:
    """Execute scale-in protection routine.

    The routine unprotects idle nodes if the desired capacity is lower than the
    current capacity. A node is idle if all of its workers have been idle for
    more than the idle timeout.

    Args:
        cloud_interface (CloudInterface): Cloud provider specific
        implementation of AbstractCloudInterface.
        os_interface (OSInterface): Operating system specific implementation
        of AbstractOSInterface.

    Returns:
        status (int): Status code of program.
                        0: Successful
                        1: Faced an issue with cloud provider
                        2: Faced an issue with cluster
                        3: Faced an issue with both
    """
    # Retrieving capacity information
    cloud_capacity = cloud_interface.get_cloud_capacity()
    if cloud_capacity is None:
        print("There was an issue retrieving cloud capacities, exiting.")
        return STATUS_CLOUD_ISSUE

    print(f"Current cloud capacities: {cloud_capacity}")

    node_difference = cloud_capacity.current_nodes - cloud_capacity.desired_nodes

    cluster_issue, cloud_issue = False, False
    if node_difference == 0:
        print("(=) The desired capacity matches the current capacity")

    elif node_difference < 0:
        print("(>) The desired capacity is higher than the current capacity")

    elif node_difference > 0:
        print(
            "(<) The desired capacity is lower than the current capacity by "
            f"{node_difference} nodes"
        )

        idle_timeout_seconds = cloud_interface.get_idle_timeout_seconds()
        print(f"Idle timeout is {idle_timeout_seconds}s")

        nodes_seconds_idle = os_interface.get_nodes_idle_time_seconds()

        nodes_to_stop = set()
        for node, seconds_idle in nodes_seconds_idle.items():
            print(f"- {node}: {seconds_idle}s idle")
            if seconds_idle > idle_timeout_seconds:
                print("  pick")
                nodes_to_stop.add(node)
                if len(nodes_to_stop) >= node_difference:
                    break

            else:
                print("  skip")

        if nodes_to_stop:
            nodes_stopped = os_interface.stop_workers_on_nodes(nodes_to_stop)
            if nodes_to_stop != nodes_stopped:
                failed_nodes = nodes_to_stop - nodes_stopped
                print(
                    f"~ Failed to stop workers on {len(failed_nodes)} nodes:"
                    f" {failed_nodes}"
                )
                cluster_issue = True

            if nodes_stopped:
                print(f"> Stopped workers on {len(nodes_stopped)} nodes")

                nodes_unprotected = cloud_interface.set_nodes_protection(
                    nodes_stopped, False
                )
                if nodes_stopped != nodes_unprotected:
                    failed_nodes = nodes_stopped - nodes_unprotected
                    print(
                        f"~ Failed to unprotect {len(failed_nodes)} nodes: "
                        f"{failed_nodes}"
                    )
                    cloud_issue = True

                if nodes_unprotected:
                    print(f"> Unprotected {len(nodes_unprotected)} nodes")

        else:
            print("> No nodes to stop")

    if cloud_issue and cluster_issue:
        return STATUS_CLOUD_AND_CLUSTER_ISSUE
    elif cloud_issue:
        return STATUS_CLOUD_ISSUE
    elif cluster_issue:
        return STATUS_CLUSTER_ISSUE
    else:
        return STATUS_SUCCESS
