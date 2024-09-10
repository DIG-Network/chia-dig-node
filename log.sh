#!/bin/bash

USER_NAME=${SUDO_USER:-$(whoami)} 
SERVICE_NAME="dig@$USER_NAME.service"

# Check if the service exists
if systemctl list-units --full -all | grep -q "$SERVICE_NAME"; then
  echo "Tailing logs for $SERVICE_NAME..."
  journalctl -fu "$SERVICE_NAME"
else
  echo "Service $SERVICE_NAME not found."
  exit 1
fi
