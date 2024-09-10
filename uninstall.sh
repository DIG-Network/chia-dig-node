#!/bin/bash

# Variables
USER_NAME=${SUDO_USER:-$(whoami)}  # Use SUDO_USER if available, otherwise fall back to whoami
SERVICE_NAME="dig@$USER_NAME.service"
SERVICE_FILE_PATH="/etc/systemd/system/$SERVICE_NAME"

# Check if the script is being run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Check if the service exists
if [ ! -f "$SERVICE_FILE_PATH" ]; then
  echo "Service $SERVICE_NAME does not exist. Nothing to uninstall."
  exit 1
fi

# Stop the service
echo "Stopping $SERVICE_NAME service..."
systemctl stop "$SERVICE_NAME"

# Disable the service so it does not start on boot
echo "Disabling $SERVICE_NAME service..."
systemctl disable "$SERVICE_NAME"

# Remove the service file
echo "Removing $SERVICE_FILE_PATH..."
rm -f "$SERVICE_FILE_PATH"

# Reload systemd daemon to reflect the changes
echo "Reloading systemd daemon..."
systemctl daemon-reload

# Check if Docker Compose is running for this project and stop it if necessary
WORKING_DIR=$(pwd)
if [ -d "$WORKING_DIR" ]; then
  echo "Stopping Docker Compose services in $WORKING_DIR..."
  /usr/local/bin/docker-compose down
fi

# Optionally, remove Docker volumes or networks if desired
echo "Would you like to remove Docker volumes and networks created by the DIG node (y/n)?"
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
  echo "Removing Docker volumes and networks..."
  /usr/local/bin/docker-compose down -v --remove-orphans
fi

echo "Uninstall complete. The $SERVICE_NAME service has been removed."
