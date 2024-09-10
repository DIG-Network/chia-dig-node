#!/bin/bash

# Variables
SERVICE_NAME="dig@$(whoami).service"

# Check if the script is being run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Stop the service
echo "Stopping $SERVICE_NAME service..."
systemctl stop "$SERVICE_NAME"

if [ $? -ne 0 ]; then
  echo "Failed to stop the service. Exiting..."
  exit 1
fi

# Pull the latest Docker images using docker-compose
echo "Pulling latest Docker images..."
docker-compose pull

if [ $? -ne 0 ]; then
  echo "Failed to pull latest Docker images. Exiting..."
  exit 1
fi

# Start the service
echo "Starting $SERVICE_NAME service..."
systemctl start "$SERVICE_NAME"

if [ $? -ne 0 ]; then
  echo "Failed to start the service. Exiting..."
  exit 1
fi

# Verify the service is running
echo "Checking status of $SERVICE_NAME service..."
systemctl status "$SERVICE_NAME"

echo "Node upgrade complete."
