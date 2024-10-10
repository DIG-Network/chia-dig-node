#!/usr/bin/env bash

# Variables
USER_NAME=${SUDO_USER:-$(whoami)}
SERVICE_NAME="dig@$USER_NAME.service"

# Function to detect the Docker Compose command
detect_docker_compose_cmd() {
    if command -v docker-compose >/dev/null 2>&1; then
        echo "docker-compose"
    elif docker compose version >/dev/null 2>&1; then
        echo "docker compose"
    else
        echo ""
    fi
}

# Detect Docker Compose command
DOCKER_COMPOSE_CMD=$(detect_docker_compose_cmd)

# Check if the script is being run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Check if Docker Compose is installed
if [ -z "$DOCKER_COMPOSE_CMD" ]; then
  echo "Docker Compose is not installed. Exiting..."
  exit 1
fi

# Stop the service
echo "Stopping $SERVICE_NAME service..."
systemctl stop "$SERVICE_NAME"

if [ $? -ne 0 ]; then
  echo "Failed to stop the service. Exiting..."
  exit 1
fi

# Pull the latest Docker images using the detected Docker Compose command
echo "Pulling latest Docker images..."
$DOCKER_COMPOSE_CMD pull

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
