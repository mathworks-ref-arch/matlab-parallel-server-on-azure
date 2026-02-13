#!/usr/bin/env python3

# Copyright 2024 The MathWorks, Inc.

from mwplatforminterfaces import CloudInterface

from cluster_management_interface import ClusterManagementProgramInterface
from constants import (
    STATUS_SUCCESS,
    STATUS_CLUSTER_ISSUE,
    WAS_MJS_BUSY,
    MJS_STATUS_LOG_FILE,
    CLUSTER_READY_FOR_TERMINATION,
    CLUSTER_AUTO_TERMINATED,
)

import os
import re
from datetime import datetime, timezone

UNUSED_CLUSTER_TIMEOUT_SECONDS = 1800
LOG_DATE_FORMAT = "%a %m/%d/%Y %H:%M:%S"
IDLE_TIMESTAMP_PATTERN = r"MJS\s+idle\s+since:\s+([A-Za-z]{3}\s+\d{2}/\d{2}/\d{4}\s+\d{1,2}:\d{2}:\d{2})\.\d{2}"
MJS_STATE_UNKNOWN_PROMPT = "Skipping cluster termination as MJS state is not known"


def main(
    cloud_interface: CloudInterface,
    cluster_management_interface: ClusterManagementProgramInterface,
) -> int:
    """Execute terminate on idle routine.

    The routine checks the last line of the mjs_status_transitions.log file. If it says that MJS is idle, calculate the time delta
    between now and the timestamp in the last line. If the time delta is greater than the idle timeout, then terminate
    the cluster i.e. delete all the nodes in the cluster and then deallocate the head-node.

    Args:
        cloud_interface (CloudInterface): Cloud provider specific
        implementation of AbstractCloudInterface.
        cluster_management_interface (ClusterManagementProgramInterface): Class to read and update
        dictionary containing state and config of the cluster management program.

    Returns:
        status (int): Status code of program.
                        0: Successful
                        1: Faced an issue with cloud provider
                        2: Faced an issue with cluster
                        3: Faced an issue with both
    """
    mjs_status_log_path = cluster_management_interface.cluster_management_config[
        MJS_STATUS_LOG_FILE
    ]
    # If MJS was never busy, then we set the idle timeout to at least UNUSED_CLUSTER_TIMEOUT_SECONDS
    # This is done to ensure that the user gets enough time to submit their first job before termination begins.
    idle_timeout_seconds = cloud_interface.get_idle_timeout_seconds()
    if not cluster_management_interface.cluster_management_state[WAS_MJS_BUSY]:
        idle_timeout_seconds = max(idle_timeout_seconds, UNUSED_CLUSTER_TIMEOUT_SECONDS)

    if not os.path.isfile(mjs_status_log_path):
        print(
            f"~ Failed to find file {mjs_status_log_path}. {MJS_STATE_UNKNOWN_PROMPT}."
        )
        return STATUS_CLUSTER_ISSUE

    # Proceed only if the mjs status transitions log file contains at least one non-empty line
    last_line = read_last_non_empty_line(mjs_status_log_path)
    if not last_line:
        print(f"~ {mjs_status_log_path} file is empty. {MJS_STATE_UNKNOWN_PROMPT}.")
        return STATUS_CLUSTER_ISSUE

    idle_timestamp = extract_idle_timestamp(last_line)
    if not idle_timestamp:
        print("> MJS is busy. Skipping cluster termination.")
        return STATUS_SUCCESS

    current_timestamp = (datetime.now(timezone.utc)).strftime(LOG_DATE_FORMAT)
    time_difference = calculate_cluster_idle_time(idle_timestamp, current_timestamp)
    print(
        f"> MJS has been idle for {time_difference} seconds. Total timeout is {idle_timeout_seconds} seconds."
    )

    if time_difference > idle_timeout_seconds:
        print(
            "> MJS has been idle for more than the timeout. Marking cluster as ready for termination in the cluster management data file."
        )
        cluster_management_interface.update_state(
            {
                CLUSTER_READY_FOR_TERMINATION: True,
                CLUSTER_AUTO_TERMINATED: True,
            }
        )
    else:
        print(
            "> MJS has been idle for less than the timeout. Skipping cluster termination."
        )

    return STATUS_SUCCESS


def read_last_non_empty_line(file_path):
    with open(file_path, "r") as file:
        # Go through each line in reverse to find the last non-empty line
        for line in reversed(file.readlines()):
            if line.strip():
                return line.strip()
    return None


def extract_idle_timestamp(last_line):
    # Use the defined regular expression pattern to extract the timestamp
    match = re.search(IDLE_TIMESTAMP_PATTERN, last_line)
    if match:
        return match.group(1)
    return None


def calculate_cluster_idle_time(idle_timestamp, current_timestamp):
    # Convert both timestamps to datetime objects
    log_time = datetime.strptime(idle_timestamp, LOG_DATE_FORMAT)
    current_time = datetime.strptime(current_timestamp, LOG_DATE_FORMAT)
    # Calculate the difference
    return (current_time - log_time).total_seconds()
