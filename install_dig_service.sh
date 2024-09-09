#!/bin/bash

# Variables
USER_NAME=${SUDO_USER:-$(whoami)}  # Use SUDO_USER if available, otherwise fall back to whoami
SERVICE_NAME="dig@$USER_NAME.service"
SERVICE_FILE_PATH="/etc/systemd/system/$SERVICE_NAME"
WORKING_DIR=$(pwd)

# Check if the script is being run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Add the current user to the Docker group
echo "Adding $USER_NAME to the docker group..."
usermod -aG docker "$USER_NAME"

# Check if the working directory exists
if [ ! -d "$WORKING_DIR" ]; then
  echo "Working directory $WORKING_DIR does not exist. Please create it first."
  exit 1
fi

# Create the systemd service file
echo "Creating systemd service file at $SERVICE_FILE_PATH..."

cat <<EOF > $SERVICE_FILE_PATH
[Unit]
Description=Dig Node Docker Compose
Documentation=https://dig.net
After=network.target docker.service
Requires=docker.service

[Service]
WorkingDirectory=$WORKING_DIR
ExecStart=/usr/local/bin/docker-compose up
ExecStop=/usr/local/bin/docker-compose down
Restart=always

User=$USER_NAME
Group=docker

# Time to wait before forcefully stopping the container
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd to recognize the new service
echo "Reloading systemd daemon..."
systemctl daemon-reload

# Enable the service to start on boot
echo "Enabling $SERVICE_NAME service..."
systemctl enable "dig@$USER_NAME.service"

# Start the service
echo "Starting $SERVICE_NAME service..."
systemctl start "dig@$USER_NAME.service"

# Check the status of the service
echo "Checking the status of the service..."
systemctl status "dig@$USER_NAME.service"

echo "Service $SERVICE_NAME installed and activated successfully."

echo "Please log out and log back in for the Docker group changes to take effect."
