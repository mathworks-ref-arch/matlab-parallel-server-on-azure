# Copyright 2022-2026 The MathWorks, Inc.

from mwplatforminterfaces import CloudInterface
from mwplatforminterfaces import OSInterface

from constants import (
    STATUS_SUCCESS,
    STATUS_CLOUD_ISSUE,
    HEALTH_CHECK_GRACE_PERIOD_SECONDS,
)


def main(cloud_interface: CloudInterface, os_interface: OSInterface) -> int:
    """Evaluate orphaned nodes in the cluster.

    This routine looks for nodes that have been running for atleast 
    idle_timeout_seconds and are not registered with MJS or are in a suspended state. 
    These could be unhealthy nodes that are orphaned from MJS due to unexpected 
    reasons (user data execution failure, etc.).

    The routine will try to set their health status as Unhealthy. The cloud platform will
    then automatically replace the nodes with new ones to match the desired capacity.

    Args:
        cloud_interface (CloudInterface): Cloud provider specific
        implementation of AbstractCloudInterface.
        os_interface (OSInterface): Operating system specific implementation
        of AbstractOSInterface.

    Returns:
        status (int): Status code of program.
                        0: Successful
                        1: Faced an issue with cloud provider
    """
    # The idle timeout for workers is defined by the mwWorkerIdleTimeoutMinutes
    # tag defined in the cluster VMSS resource
    idle_timeout_seconds = cloud_interface.get_idle_timeout_seconds()
    print(f"Idle timeout is {idle_timeout_seconds}s")

    # We must wait for at least HEALTH_CHECK_GRACE_PERIOD_SECONDS before evaluate
    # health of the worker nodes
    health_check_grace_period = max(HEALTH_CHECK_GRACE_PERIOD_SECONDS, idle_timeout_seconds)
    print(f"Health check grace period is {health_check_grace_period}s")

    # Retrieve current nodes in the cluster that are running for
    # at least health_check_grace_period
    current_nodes = cloud_interface.get_worker_nodes(
        grace_period_seconds = health_check_grace_period
    )

    if not current_nodes:
        print(f"There are no worker nodes running for more than {health_check_grace_period} seconds.")
        print("No worker nodes to evaluate for health checks.")
        return STATUS_SUCCESS

    print(f"{len(current_nodes)} nodes running for more than {health_check_grace_period} seconds: {current_nodes}")

    # Worker nodes where MATLAB workers have been suspended or stopped
    suspended_nodes = os_interface.get_suspended_nodes(current_nodes)

    print(f"{len(suspended_nodes)} suspended nodes: {suspended_nodes}")

    # Retrieve nodes that are registered with MJS
    registered_worker_nodes = os_interface.get_worker_nodes()

    # We target nodes that are not registered with MJS
    current_unregistered_nodes = current_nodes - registered_worker_nodes

    print(f"{len(current_unregistered_nodes)} unregistered nodes: {current_unregistered_nodes}")

    nodes_to_mark_unhealthy = suspended_nodes.union(current_unregistered_nodes)

    if not nodes_to_mark_unhealthy:
        print("All nodes are healthy")
        return STATUS_SUCCESS

    print(f"Marking suspended and unregistered nodes as unhealthy: {nodes_to_mark_unhealthy}")
    nodes_were_marked = cloud_interface.set_nodes_unhealthy(nodes_to_mark_unhealthy)

    if not nodes_were_marked:
        print("Failed to mark nodes as unhealthy")
        return STATUS_CLOUD_ISSUE

    return STATUS_SUCCESS
