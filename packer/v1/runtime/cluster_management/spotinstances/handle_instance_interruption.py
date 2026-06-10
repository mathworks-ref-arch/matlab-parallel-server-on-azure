#!/usr/bin/env python3

# Copyright 2024-2026 The MathWorks, Inc.

from mwplatforminterfaces import CloudInterface
from mwplatforminterfaces import OSInterface

from datetime import datetime
import logging
from logging.handlers import RotatingFileHandler
import os
import sys
import time

# Add parent dir to path since constants file is in parent dir
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from constants import STATUS_SUCCESS, STATUS_CLUSTER_ISSUE


def main() -> int:
    """Check Spot VM status and handle interruption event.

    Returns:
        status (int): Status code of program.
                        0: Successful
                        1: Faced an issue
    """

    print("Retrieving spot VM interruption status ...")
    is_instance_marked_for_removal = (
        CloudInterface.is_spot_instance_marked_for_removal()
    )

    if not is_instance_marked_for_removal:
        print(
            "No action needed, because the VM is not flagged " "by Azure for removal."
        )
        return STATUS_SUCCESS

    print("The VM is flagged by Azure for removal. Stopping workers ...")
    print("Connecting to cluster ...")
    os_interface = OSInterface()
    sw_success = os_interface.stop_workers_locally()

    if sw_success:
        print("Stopped workers successfully.")
        return STATUS_SUCCESS

    print("Failed to stop workers.")
    return STATUS_CLUSTER_ISSUE


if __name__ == "__main__":
    # Create logger
    logger = logging.getLogger("mw.spot_interruption")
    log_file = "C:\\ProgramData\\MathWorks\\spot_interruption.log"
    log_handler = RotatingFileHandler(log_file, maxBytes=1e6, backupCount=5)
    log_handler.terminator = ""
    logger.addHandler(log_handler)
    logger.setLevel(logging.INFO)
    sys.stdout.write, sys.stderr.write = logger.info, logger.warning

    try:
        while True:
            print(f"## Starting: {datetime.now():%Y-%m-%d %H:%M:%S}")
            status = main()
            print(f"## Finished ({status}): {datetime.now():%Y-%m-%d %H:%M:%S}\n")
            time.sleep(10)
    except Exception as e:
        logger.exception(e)
        sys.exit(status)
