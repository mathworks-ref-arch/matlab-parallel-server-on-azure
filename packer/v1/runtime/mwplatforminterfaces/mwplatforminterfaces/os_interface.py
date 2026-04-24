# Copyright 2021-2026 The MathWorks, Inc.

from abc import ABC, abstractmethod
import asyncio
import json
from pathlib import Path
import re
import subprocess
import sys
from typing import Dict, NamedTuple, Set

# Limit the number of concurrent calls to MJS
MJS_SEM = asyncio.Semaphore(20)

# Seconds to wait for stopworker execution
STOPWORKER_TIMEOUT = 25

# Seconds to wait for nodestatus execution
NODESTATUS_TIMEOUT = 15


class ClusterCapacity(NamedTuple):
    """Class defining the cluster capacity information."""

    current_workers: int
    desired_workers: int
    maximum_workers: int


class AbstractOSInterface(ABC):
    """Class to interact with the MATLAB Job Scheduler"""

    def __init__(self) -> None:
        """Create OSInterface object."""
        pass

    def get_cluster_capacity(self) -> ClusterCapacity:
        """Get the job manager's desired and maximum
        number of workers.

        Returns:
            info (ClusterCapacity): Job manager's worker limits.
        """
        worker_os = self._get_worker_os()
        data = self._get_resize_status_output()
        if data:
            try:
                info = ClusterCapacity(
                    current_workers=len(data["workers"]),
                    desired_workers=data["desiredWorkers"][worker_os],
                    maximum_workers=data["maxWorkers"][worker_os],
                )
                return info

            except KeyError:
                print(f"Key error when accessing {data}.", file=sys.stderr)

        return None

    def get_nodes_idle_time_seconds(self) -> Dict[str, int]:
        """Get the idle duration of nodes in the cluster in seconds. A node's
        idle duration is the minimum idle duration of the workers running on
        it.

        Returns:
            seconds_idle (Dict[str, int]): Number of seconds each node has been
            idle for.
        """
        seconds_idle = {}

        data = self._get_resize_status_output()
        if data is not None:
            for worker in data["workers"]:
                host = worker["host"]
                idle_time = worker["secondsIdle"]
                if host not in seconds_idle:
                    seconds_idle[host] = idle_time
                else:
                    seconds_idle[host] = min(seconds_idle[host], idle_time)

        return seconds_idle

    def get_suspended_nodes(self, nodes_hostnames: Set[str]) -> Set[str]:
        """Get the nodes that are suspended. A node is suspended if workers
        have stopped running.

        Args:
            nodes_hostnames (Set[str]): Hostnames of the nodes.

        Returns:
            bad_nodes_hostnames (Set[str]): Hostnames of the nodes in a bad
            state.
        """
        good_nodes = self.get_worker_nodes()
        workergroup_status = self._get_workergroups_statuses(
            nodes_hostnames - good_nodes
        )

        bad_nodes = {
            host for host, status in workergroup_status.items() if status == "Suspended"
        }

        return bad_nodes

    def get_worker_nodes(self) -> Set[str]:
        """Get the current worker nodes registered in the cluster.

        Returns:
            nodes_hostnames (Set[str]): Hostnames of the nodes.
        """
        data = self._get_resize_status_output()
        if data:
            return {worker["host"] for worker in data["workers"]}

        return set()

    def set_cluster_capacity(self, maximum_workers: int) -> bool:
        """Update the job manager's maximum number of workers.

        Args:
            maximum_workers (int): Maximum number of workers.

        Returns:
            status (bool): Exit status of the process.
            True indicates that it ran successfully.
        """
        maxworkers_flag = self._get_maxworkers_flag()

        executable = self._get_resize_executable()
        args = ["update", maxworkers_flag, str(maximum_workers)]

        result = subprocess.run([executable, *args], capture_output=True)
        if result.returncode != 0:
            print(result.stdout, file=sys.stderr)

        return result.returncode == 0

    def stop_workers_on_nodes(self, nodes_hostnames: Set[str]) -> Set[str]:
        """Asynchronously stop the workers on multiple remote hosts.

        Args:
            nodes_hostnames (Set[str]):  Hostnames of the nodes.

        Returns:
            nodes_stopped (Set[str]): Hostname of nodes that were stoppped.
        """
        if not nodes_hostnames:
            return set()
        
        hostnames = list(nodes_hostnames)
        
        async def _run():
            # async function to be wrapped under asyncio.run(). asyncio.gather()
            # needs a requires a running event loop to schedule the coroutines.
            # Using this wrapper with run() ensures that the loop is created first
            tasks = [self._stop_workers_on_node(host) for host in hostnames]
            return await asyncio.gather(*tasks, return_exceptions=True)

        results = asyncio.run(_run())

        # Make sure the workers actually stopped.
        current_hosts = self.get_worker_nodes()

        nodes_stopped = {
            host
            for host, status in zip(hostnames, results)
            if status and (host not in current_hosts)
        }

        return nodes_stopped

    def is_mjs_running(self) -> bool:
        """Check if MJS is running or not.

        Returns:
            status (bool): True if MJS is running, False otherwise.
        """
        mjs_process_name = "mjsd.exe"

        try:
            output = subprocess.check_output(["tasklist"], text=True)
        except subprocess.CalledProcessError as e:
            print(f"Failed to get task list: {e}")
            return False

        # Search for the process name in the command output
        if re.search(rf"\b{mjs_process_name}\b", output, re.IGNORECASE):
            return True
        return False

    def is_jobmanager_running(self) -> bool:
        """Check if any job manager is running.

        Returns:
            status (bool): True if job manager is running, False otherwise.
        """
        nodestatus_executable = self._get_nodestatus_executable()
        args = ["-json"]
        result = subprocess.run(
            [nodestatus_executable, *args], capture_output=True, text=True
        )

        if result.returncode != 0:
            print(result.stdout, file=sys.stderr)
            return False

        try:
            data = json.loads(result.stdout)
            # Check if there is at least one job manager and get its status
            if data.get("jobManagers") and len(data["jobManagers"]) > 0:
                job_manager_status = data["jobManagers"][0].get("status", "").lower()
                return job_manager_status == "running"
        except json.JSONDecodeError:
            print("Error parsing nodestatus output data.", file=sys.stderr)

        return False

    def stop_mjs(self) -> bool:
        """Stop the MATLAB Job Scheduler (MJS).
        Returns:
            status (bool): Exit status of the process.
            True indicates that it ran successfully.
        """
        mjs_executable = self._get_mjs_executable()
        if not self.is_mjs_running():
            return True
        args = ["stop", "-cleanPreserveJobs"]
        result = subprocess.run([mjs_executable, *args], capture_output=True, text=True)
        if result.returncode != 0:
            return False

        return True

    def stop_workers_locally(self) -> bool:
        """Stops the workers running on the host.
        Returns:
            status (bool): Exit status of the process.
            True indicates that it ran successfully.
        """

        executable = self._get_stopworker_executable()
        args = ["-all"]

        result = subprocess.run([executable, *args], capture_output=True)
        if result.returncode == 0:
            return True

        else:
            print(f"Failed. Return code: {result.returncode}")
            print(result.stdout, file=sys.stderr)

        return False

    def stop_job_manager(self) -> bool:
        """Stop the associated job manager.

        Returns:
            status (bool): Exit status of the process.
            True indicates that it ran successfully.
        """
        stop_jobmanager_executable = self._get_stopjobmanager_executable()
        if self.is_jobmanager_running():
            data = self._get_resize_status_output()
            if data:
                jobmanager = data["name"]
                args = ["-name", jobmanager, "-cleanPreserveJobs"]
                result = subprocess.run(
                    [stop_jobmanager_executable, *args], capture_output=True, text=True
                )
                if result.returncode != 0:
                    return False
        return True

    @abstractmethod
    def _get_matlabroot(self) -> Path:
        """Get the directory in which MATLAB is installed."""
        pass

    @abstractmethod
    def _get_maxworkers_flag(self) -> str:
        """Get the worker operating system to set when using resize update.

        Returns:
            maxworkers_flag (str): Flag for resize update.
        """
        pass

    @abstractmethod
    def _get_nodestatus_executable(self) -> Path:
        """Get the path of the nodestatus executable"""
        pass

    def _get_parallel_bin_root(self) -> Path:
        """Get the directory containing the Parallel Computing Toolbox
        binaries."""
        return self._get_matlabroot() / "toolbox" / "parallel" / "bin"

    @abstractmethod
    def _get_resize_executable(self) -> Path:
        """Get the path of the resize executable"""
        pass

    def _get_resize_status_output(self) -> Dict:
        """Get the job manager's resize status output.

        Returns:
            data (Dict): resize status output.
        """
        executable = self._get_resize_executable()
        args = ["status"]

        result = subprocess.run([executable, *args], capture_output=True)
        if result.returncode == 0:
            output = json.loads(result.stdout)
            if output["jobManagers"]:
                return output["jobManagers"].pop()
        else:
            print(result.stdout, file=sys.stderr)

        return None

    @abstractmethod
    def _get_stopworker_executable(self) -> Path:
        """Get the path of the stopworker executable"""
        pass

    @abstractmethod
    def _get_worker_os(self) -> str:
        """Get the worker operating system to look for in the resize status
        output.

        Returns:
            worker_os (str): Operating system of the workers.
        """
        pass

    def _get_workergroups_statuses(self, nodes_hostnames: Set[str]) -> Dict[str, str]:
        """Asynchronously get the worker group status on multiple remote hosts.

        Args:
            nodes_hostnames (Set[str]):  Hostnames of the nodes.

        Returns:
            workergroup_status (Dict[str, str]): Mapping between hostname
            and status.
        """
        # Return early if no hostnames provided
        if not nodes_hostnames:
            return {}
        
        hostnames = list(nodes_hostnames)

        async def _run():
            # async function to be wrapped under asyncio.run(). asyncio.gather()
            # needs a requires a running event loop to schedule the coroutines.
            # Using this wrapper with run() ensures that the loop is created first
            tasks = [self._get_workergroup_status(host) for host in hostnames]
            return await asyncio.gather(*tasks, return_exceptions=True)

        results = asyncio.run(_run())

        statuses = {host: status for host, status in zip(hostnames, results)}

        return statuses

    async def _get_workergroup_status(self, hostname: str) -> str:
        """Get the worker group status on a remote host.

        Args:
            hostname (str): Hostname to probe.

        Returns:
            status (str): Worker group status (Not running, Running, Suspended)
        """
        executable = self._get_nodestatus_executable()
        args = ["-json", "-remotehost", hostname]

        async with MJS_SEM:
            proc = await asyncio.create_subprocess_exec(
                executable,
                *args,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            try:
                stdout, stderr = await asyncio.wait_for(
                    proc.communicate(), NODESTATUS_TIMEOUT
                )
                if proc.returncode == 0:
                    output = json.loads(stdout)
                    return output["workerGroup"]["status"]

                else:
                    # Bad host or MJS is not running (may be a new node)
                    print(stdout, stderr, file=sys.stderr)

            except asyncio.TimeoutError:
                print(
                    f"Command {executable} {args} timed-out after "
                    f"{NODESTATUS_TIMEOUT}s.",
                    file=sys.stderr,
                )

        return None

    async def _stop_workers_on_node(self, node_hostname: str) -> bool:
        """Stops the workers running on a node.

        Args:
            node_hostname (str): Hostname of the node.

        Returns:
            status (bool): Exit status of the process.
            True indicates that it ran successfully.
        """
        executable = self._get_stopworker_executable()
        args = ["-onidle", "-all", "-remotehost", node_hostname]

        async with MJS_SEM:
            proc = await asyncio.create_subprocess_exec(
                executable,
                *args,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            try:
                stdout, stderr = await asyncio.wait_for(
                    proc.communicate(), STOPWORKER_TIMEOUT
                )
                if proc.returncode == 0:
                    return True

                else:
                    print(stdout, stderr, file=sys.stderr)

            except asyncio.TimeoutError as te:
                print(
                    f"Command {executable} {args} timed-out after "
                    f"{STOPWORKER_TIMEOUT}s.",
                    file=sys.stderr,
                )

        return False
