#!/bin/bash

detect_ec2() {
    # Attempt to access the EC2 metadata service
    if timeout 1 curl -s http://169.254.169.254/latest/meta-data/ >/dev/null 2>&1; then
        IS_EC2_INSTANCE="yes"
    else
        IS_EC2_INSTANCE="no"
    fi
}
