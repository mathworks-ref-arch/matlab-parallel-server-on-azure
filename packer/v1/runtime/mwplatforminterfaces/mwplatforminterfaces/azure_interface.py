# Copyright 2022-2026 The MathWorks, Inc.

from .cloud_interface import (
    AbstractCloudInterface,
    CloudCapacity,
    IDLE_TIMEOUT_TAG,
    IDLE_TIMEOUT_DEFAULT,
)

from azure.core.exceptions import HttpResponseError
from azure.identity import ManagedIdentityCredential
from azure.mgmt.compute import ComputeManagementClient
from azure.mgmt.resource import ResourceManagementClient
from azure.mgmt.network import NetworkManagementClient
from azure.mgmt.resource.resources.models import TagsPatchResource
from azure.mgmt.compute.models import (
    VirtualMachineScaleSet,
    VirtualMachineScaleSetVM,
    VirtualMachineScaleSetVMInstanceRequiredIDs,
)

import requests
import sys, re
from datetime import datetime, timezone
from typing import Any, Dict, Iterable, List, Set

IMDS_URL = "http://169.254.169.254"


WORKER_PER_NODE_TAG = "mwWorkersPerNode"
DESIRED_NODES_TAG = "mwDesiredCount"
MIN_NODES_TAG = "mwMinCount"
MAX_NODES_TAG = "mwMaxCount"
CLUSTER_TERMINATION_TAG = "mw-autoshutdown"


class AzureInterface(AbstractCloudInterface):
    """Class to interact with Microsoft's cloud computing platform.

    Attributes:
        compute_client (ComputeManagementClient): Interface with Azure compute api.
        resource_client (ResourceManagementClient): Interface with Azure resource management api.
        resource_group (str): Name of the resource group with all resources.
        vmss_name (str): Name of the Virtual Machine Scale Set.
        workers_per_node (int): Number of MATLAB workers per instance.
    """

    _compute_client: ComputeManagementClient
    _resource_client: ResourceManagementClient
    _network_client: NetworkManagementClient

    _resource_group: str
    _vmss_name: str

    _workers_per_node: int

    def __init__(self, custom_dns_suffix: str = None,
        use_private_ip_mapping: bool = False,) -> None:
        """Create AzureInterface object and set all necessary attributes.

        Resource group information is retrieved from the instance meta-data
        url.

        The headnode virtual machine and the Virtual Machine Scale Set
        are found in the resource group.
        """

        # Reading instance metadata.
        def get_imds(query: str) -> Any:
            url = f"{IMDS_URL}{query}?api-version=2021-02-01"
            headers = {"Metadata": "True"}
            proxies = {"http": None, "https": None}
            return requests.get(url, headers=headers, proxies=proxies).json()

        # Turn headnode tags from a string into a dictionary
        def get_headnode_tags_dict(tags: str) -> dict:
            return dict(pair.split(":", 1) for pair in tags.split(";") if ":" in pair)

        data = get_imds("/metadata/instance/compute")

        # Setting all necessary attributes
        identity = ManagedIdentityCredential()
        self._compute_client = ComputeManagementClient(identity, data["subscriptionId"])
        self._network_client = NetworkManagementClient(
            identity, data["subscriptionId"]
        )

        self._resource_client = ResourceManagementClient(
            identity, data["subscriptionId"]
        )

        self._resource_group = data["resourceGroupName"]

        self._headnode_name = data["name"]
        self._headnode_tags = get_headnode_tags_dict(data["tags"])

        self._headnode_resource_id = data["resourceId"]

        self._custom_dns_suffix = custom_dns_suffix
        self._use_private_ip_mapping = use_private_ip_mapping

        self._vmss_name = next(
            vmss.name
            for vmss in self._compute_client.virtual_machine_scale_sets.list(
                self._resource_group
            )
        )

        self._workers_per_node = self.__get_workers_per_node()

    def get_cloud_capacity(self) -> CloudCapacity:
        """Get the Virtual Machine Scale Set capacity info
        as well as the number of workers per node.

        Returns:
            info (CloudCapacity): Auto Scaling group limits.
        """
        vmss = self._get_vmss_instance()
        if vmss:
            tags = vmss.tags

            if MIN_NODES_TAG not in tags:
                print(
                    "Minimum capacity tag not defined, setting to 0.", file=sys.stderr
                )
                tags = self.__update_vmss_tags({MIN_NODES_TAG: 0})

            if DESIRED_NODES_TAG not in tags:
                print(
                    "Desired capacity tag not defined, setting to current" " capacity.",
                    file=sys.stderr,
                )
                tags = self.__update_vmss_tags({DESIRED_NODES_TAG: vmss.sku.capacity})

            if MAX_NODES_TAG not in tags:
                print(
                    "Maximum capacity tag not defined, setting to desired" " capacity.",
                    file=sys.stderr,
                )
                tags = self.__update_vmss_tags({MAX_NODES_TAG: tags[DESIRED_NODES_TAG]})

            info = CloudCapacity(
                desired_nodes=int(tags[DESIRED_NODES_TAG]),
                minimum_nodes=int(tags[MIN_NODES_TAG]),
                maximum_nodes=int(tags[MAX_NODES_TAG]),
                current_nodes=sum(
                    1
                    for vm in self._get_vm_instances()
                    if vm.provisioning_state in ("Creating", "Succeeded")
                ),
                workers_per_node=self._workers_per_node,
            )
            return info

        return None

    def get_idle_timeout_seconds(self) -> int:
        """Get the idle timeout specified on the Virtual Machine Scale Set.
        This timeout specifies the minimum idle time to consider a worker to be
        idle.

        Returns:
            timeout (int): Idle timeout in seconds.
        """
        vmss = self._get_vmss_instance()
        if vmss:
            tags = vmss.tags
            try:
                timeout_minutes = tags[IDLE_TIMEOUT_TAG]
                timeout_seconds = int(float(timeout_minutes) * 60)
                if timeout_seconds >= 0:
                    return timeout_seconds

                else:
                    print(f'Value "{timeout_minutes}" is negative.', file=sys.stderr)

            except KeyError:
                print(f'Tag "{IDLE_TIMEOUT_TAG}" was not found.', file=sys.stderr)

            except ValueError:
                print(f'Value "{timeout_minutes}" is not a number.', file=sys.stderr)

            print(f"Applying default {IDLE_TIMEOUT_DEFAULT}.", file=sys.stderr)
            self.__update_vmss_tags({IDLE_TIMEOUT_TAG: IDLE_TIMEOUT_DEFAULT})

        return IDLE_TIMEOUT_DEFAULT * 60

    def get_worker_nodes(self, grace_period_seconds: int = 300) -> Set[str]:
        """Get the current worker nodes running in the VMSS.
        Only the nodes in a good state (online and healthy) will be
        returned.

        online=provisioning_state:Succeeded

        Returns:
            nodes_hostnames (Set[str]): Hostnames of the nodes.
        """
        nodes_hostnames = set()
        current_time = datetime.now(timezone.utc)
        host_to_id = self._get_host_to_id()
        for hostname, instance_id in host_to_id.items():
            vm = self._compute_client.virtual_machine_scale_set_vms.get(
                self._resource_group, self._vmss_name, instance_id
            )

            vm_uptime = (current_time - vm.time_created).total_seconds()

            if (
                vm.provisioning_state == "Succeeded"
                and vm_uptime > grace_period_seconds
            ):
                nodes_hostnames.add(hostname)

        return nodes_hostnames

    def get_cluster_termination_policy(self) -> str:
        """Get the termination policy for the cluster. This policy is
        specified as a tag on the head node.

        Returns:
            policy (str): Termination policy.
        """
        termination_policy = self._extract_termination_policy()
        return self._valid_termination_policy(termination_policy)

    def scale_cluster_to_zero(self) -> bool:
        """Scale down the cloud cluster to 0 nodes.

        Returns:
            status(bool): True if Cluster scaled to zero, else, False
        """
        # Get host names of all VMs in the VMSS
        host_to_id = self._get_host_to_id()
        host_names = set(host_to_id.keys())

        if host_names:
            # Delete all nodes retrieved
            nodes_unprotected = self.set_nodes_protection(host_names, False)
            if nodes_unprotected != host_names:
                return False

        return True

    def set_cluster_termination_policy(self, policy: str) -> bool:
        """Set/Update the termination policy tag for the cluster.

        Returns:
            True if update tag request succeeded, else False.
        """
        validated_policy = self._valid_termination_policy(policy)
        if not validated_policy:
            print(f"Invalid policy: {policy}.")
            return False

        tag_to_update = {CLUSTER_TERMINATION_TAG: policy}
        tag_patch_resource = TagsPatchResource(
            operation="Merge", properties={"tags": tag_to_update}
        )
        try:
            self._resource_client.tags.begin_update_at_scope(
                self._headnode_resource_id,
                tag_patch_resource,
            )
        except HttpResponseError as e:
            print(e, file=sys.stderr)
            return False
        return True

    def set_cloud_capacity(self, desired_nodes: int) -> bool:
        """Update the Virtual Machine Scale Set desired capacity tag.

        Args:
            desired_nodes (int): Desired number of Auto Scaling instances.

        Returns:
            status (bool): Exit status of the process.
            True indicates that it ran successfully.
        """
        vmss = self._get_vmss_instance()
        if vmss:
            min_nodes = int(vmss.tags[MIN_NODES_TAG])
            max_nodes = int(vmss.tags[MAX_NODES_TAG])
            if min_nodes <= desired_nodes <= max_nodes:

                self.__update_vmss_tags({DESIRED_NODES_TAG: desired_nodes})
                # Only set the actual capacity when scaling out.
                if desired_nodes > vmss.sku.capacity:
                    try:
                        self._compute_client.virtual_machine_scale_sets.begin_update(
                            self._resource_group,
                            self._vmss_name,
                            {"sku": {"capacity": desired_nodes}},
                        )

                    except HttpResponseError as e:
                        print(e, file=sys.stderr)
                        return False

                return True

        return False

    def set_nodes_unhealthy(self, nodes_hostnames: Set[str]) -> bool:
        """Indicate to VMSS that multiple nodes are no
        longer healthy. The nodes will be removed from the VMSS.

        Due to Azure limitations we delete the node instead of changing the
        health status.

        Args:
            nodes_hostnames (Set[str]): Hostnames of the nodes to mark.

        Returns:
            status (bool): Exit status of the process.
            True indicates that it ran successfully.
        """
        status = True

        host_to_id = self._get_host_to_id()
        nodes_ids = list(filter(None, map(host_to_id.get, nodes_hostnames)))

        if len(nodes_ids) != len(nodes_hostnames):
            unknown = [host for host in nodes_hostnames if host not in host_to_id]
            print(f"Unknown hostnames: {unknown}", file=sys.stderr)
            status = False

        status &= self._delete_vm_instances(nodes_ids)

        # When deleting a node, the VMSS decreases its capacity by 1. Hence,
        # we need to reset the desired capacity so that new nodes appear.
        capacity = self.get_cloud_capacity()
        self.set_cloud_capacity(capacity.desired_nodes)

        return status

    def set_nodes_protection(
        self,
        nodes_hostnames: Set[str],
        protect: bool,
    ) -> Set[str]:
        """Update multiple nodes' protection status. When a node is
        protected, the Virtual Machine Scale Set cannot terminate it
        automatically.

        Due to Azure limitations, we delete the node instead of changing the
        protection status.

        Args:
            nodes_hostnames (Set[str]): Hostnames of the nodes.
            protect (bool): Protection state to set.

        Returns:
            nodes_success (Set[str]): Hostnames of the nodes for which the
            operation was successful.
        """
        host_to_id = self._get_host_to_id()
        id_to_host = {i: h for h, i in host_to_id.items()}

        nodes_ids = list(filter(None, map(host_to_id.get, nodes_hostnames)))

        if not protect:
            if self._delete_vm_instances(nodes_ids):
                return set(map(id_to_host.get, nodes_ids))

        return set()

    def deallocate_headnode(self) -> bool:
        try:
            self._compute_client.virtual_machines.begin_deallocate(
                self._resource_group, self._headnode_name
            )
            return True

        except HttpResponseError as e:
            print(e, file=sys.stderr)

        return False

    @staticmethod
    def is_spot_instance_marked_for_removal() -> bool:
        """Checks whether the Spot instance node will be removed by Azure.
        Achieves this by retrieving the status from VM event notification service.
        Returns:
            True: When the Spot instance is identified by the cloud provider
            to be removed.
            False: When the Spot instance is not marked for removal
            by the cloud provider.
        """

        events_data = AzureInterface._get_azure_vm_scheduled_events()

        if events_data and "Events" in events_data:
            for event in events_data["Events"]:
                if (
                    event["EventType"] == "Preempt"
                    and event["ResourceType"] == "VirtualMachine"
                ):
                    print(f"Spot instance marked for eviction: {event}")
                    return True
        return False

    @staticmethod
    def _get_azure_vm_scheduled_events() -> Any:
        url = f"{IMDS_URL}/metadata/scheduledevents?api-version=2020-07-01"
        headers = {"Metadata": "true"}

        try:
            response = requests.get(url, headers=headers)
            response.raise_for_status()  # Raises a HTTPError if the response status code is 4XX/5XX
            data = response.json()

            return data
        except requests.exceptions.RequestException as e:
            print(
                f"Request failed while getting azure VM scheduled events from metadata endpoint: {e}"
            )
            return None

    def _delete_vm_instances(self, instance_ids: List[str]) -> bool:
        try:
            az_instance_ids = VirtualMachineScaleSetVMInstanceRequiredIDs(
                instance_ids=instance_ids
            )
            self._compute_client.virtual_machine_scale_sets.begin_delete_instances(
                self._resource_group, self._vmss_name, az_instance_ids
            )
            return True

        except HttpResponseError as e:
            print(e, file=sys.stderr)

        return False

    def _get_vmss_instance(self) -> VirtualMachineScaleSet:
        """Get the Auto Scaling group description."""
        try:
            vmss = self._compute_client.virtual_machine_scale_sets.get(
                self._resource_group, self._vmss_name
            )
            return vmss

        except HttpResponseError as e:
            print(e, file=sys.stderr)

        return None

    def _get_vm_instances(self) -> Iterable[VirtualMachineScaleSetVM]:
        try:
            vms = self._compute_client.virtual_machine_scale_set_vms.list(
                self._resource_group, self._vmss_name
            )
            return vms

        except HttpResponseError as e:
            print(e, file=sys.stderr)

        return []

    def _get_host_to_id(self) -> dict:
        """Get a mapping between instances private hostname
            or IP addresses and their instance ids.

        Returns:
            host_to_id (dict): Hostname or private IPs to
            instance id dictionary.
        """
        if self._use_private_ip_mapping:
            return self.__get_private_ip_to_id()

        host_to_id = {}

        for vm in self._get_vm_instances():
            hostname = vm.os_profile.computer_name

            if self._custom_dns_suffix:
                # If a custom DNS suffix is configured, append it to the hostname
                hostname = f"{hostname}.{self._custom_dns_suffix}"

            host_to_id[hostname] = vm.instance_id

        return host_to_id

    def _extract_termination_policy(self) -> str:
        """Extract the termination policy from the headnode tags.

        Returns:
            policy (str): Extracted termination policy or empty string if not found.
        """
        headnode_tags_dict = self._headnode_tags
        return headnode_tags_dict.get(CLUSTER_TERMINATION_TAG, "")

    def _valid_termination_policy(self, policy: str) -> str:
        """Validate and return the extracted termination policy.

        Args:
            policy (str): The termination policy to validate.

        Returns:
            policy (str): Validated termination policy or empty string if invalid.
        """
        policy_lower = policy.lower()
        if policy_lower in ["on_idle", "never"]:
            return policy_lower
        if self.__is_valid_after_hours_format(policy):
            return policy
        if self.__is_valid_rfc1123_date(policy):
            return policy
        return ""

    def __is_valid_after_hours_format(self, policy: str) -> bool:
        """Check if the policy is in a valid "After x hours" format.

        Args:
            policy (str): The termination policy to check.

        Returns:
            is_valid (bool): True if the policy is valid, False otherwise.
        """
        match = re.match(r"^After (\d{1,2}) hours?$", policy, re.IGNORECASE)
        if match:
            hours = int(match.group(1))
            return 1 <= hours <= 24
        return False

    def __is_valid_rfc1123_date(self, policy: str) -> bool:
        """Check if the policy is a valid RFC1123 date format.

        Args:
            policy (str): The termination policy to check.

        Returns:
            is_valid (bool): True if the policy is valid, False otherwise.
        """
        try:
            datetime.strptime(policy, "%a, %d %b %Y %H:%M:%S %Z")
            return True
        except ValueError:
            return False

    def __get_workers_per_node(self) -> int:
        """Get number of workers per node from the vmss tags."""
        vmss = self._get_vmss_instance()
        workers_per_node = vmss.tags[WORKER_PER_NODE_TAG]

        return int(workers_per_node)

    def __update_vmss_tags(self, new_tags: Dict[str, Any]) -> Dict[str, str]:
        """Update the VMSS tags."""
        vmss = self._get_vmss_instance()
        if vmss:
            tags = vmss.tags
            tags.update(new_tags)

            try:
                self._compute_client.virtual_machine_scale_sets.begin_update(
                    self._resource_group, self._vmss_name, {"tags": tags}
                )
                return tags

            except HttpResponseError as e:
                print(e, file=sys.stderr)

        return None
    
    def __get_private_ip_to_id(self) -> dict:
        """Creates a dictionary mapping private IP addresses of VMSS instances
        to their instance IDs.

        Returns:
            private_ip_to_id: Mapping of private IP addresses to instance IDs
        """
        private_ip_to_id = {}
        try:
            # List all NICs for the VMSS
            nic_list = self._network_client.network_interfaces.list_virtual_machine_scale_set_network_interfaces(
                self._resource_group, self._vmss_name
            )

            # Pattern used to extract instance ID from the resource ID of the VM that is attached to the NIC
            instance_id_pattern = re.compile(r"/virtualMachines/(\d+)")

            for nic in nic_list:
                instance_id = None
                if not nic.virtual_machine:
                    continue

                # Extract the instance_id from the virtual_machine.id string
                match = instance_id_pattern.search(nic.virtual_machine.id)

                if not match:
                    continue

                instance_id = match.group(1)

                primary_ip = next(
                    (
                        ip_config.private_ip_address
                        for ip_config in nic.ip_configurations
                        if ip_config.primary
                    ),
                    None,
                )

                if primary_ip and instance_id:
                    private_ip_to_id[primary_ip] = instance_id

        except HttpResponseError as e:
            print(e, file=sys.stderr)

        return private_ip_to_id


def get_kv(iterable, key, val, filt):
    """Helper function to retrieve a key,value pair in an iterable."""
    return next(x[val] for x in iterable if x[key] == filt)
