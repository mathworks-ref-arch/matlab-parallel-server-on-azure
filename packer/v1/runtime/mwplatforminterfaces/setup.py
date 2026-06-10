# Copyright 2024-2026 The MathWorks, Inc.

from setuptools import setup

setup(
    name="mwplatforminterfaces",
    version="0.1.0",
    install_requires=[
        # Common dependencies
        "requests",
        "psutil",
    ],
    extras_require={
        "aws": ["boto3"],
        "azure": [
            "azure-identity~=1.25.0",
            "azure-mgmt-compute~=38.0.0",
            "azure-mgmt-resource~=25.0.0",
            "azure-mgmt-network~=30.2.0",
        ],
    },
)
