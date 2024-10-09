#!/usr/bin/env bash

# Adds a cron job to run the upgrade-node script once a day

source ./lib/setup_auto_update.sh

# Ask if the user wants to set up automatic updates
setup_auto_update
