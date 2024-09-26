#!/bin/bash

###############################################################################
#                       DIG Node Uninstall Script
# This script uninstalls the DIG Node and removes associated services.
# Please run this script as root.
###############################################################################

# Variables
USER_NAME=${SUDO_USER:-$(whoami)}             # User executing the script
SERVICE_NAME="dig@$USER_NAME.service"         # Systemd service name
SERVICE_FILE_PATH="/etc/systemd/system/$SERVICE_NAME"

# Color codes for formatting
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
RED='\033[1;31m'
NC='\033[0m'                                  # No Color

###############################################################################
#                         Function Definitions
###############################################################################

# Function to close specified ports using UFW
close_ports() {
    PORTS=("$@")
    echo -e "\n${BLUE}Closing ports: ${PORTS[*]}...${NC}"
    for PORT in "${PORTS[@]}"; do
        if ufw status | grep -qw "$PORT"; then
            ufw delete allow "$PORT"
            echo -e "${GREEN}Port $PORT has been closed.${NC}"
        else
            echo -e "${YELLOW}Port $PORT was not open or already closed.${NC}"
        fi
    done
    ufw reload
    echo -e "${GREEN}UFW rules have been updated.${NC}"
}

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

###############################################################################
#                         Script Execution Begins
###############################################################################

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo -e "\n${RED}Please run this script as root.${NC}"
    exit 1
fi

# Display script header
echo -e "${GREEN}
###############################################################################
#                       DIG Node Uninstall Script
###############################################################################
${NC}"

# Check if the service exists
if [ -f "$SERVICE_FILE_PATH" ]; then
    # Read the WorkingDirectory from the service file
    INSTALL_DIR=$(grep 'WorkingDirectory=' "$SERVICE_FILE_PATH" | cut -d'=' -f2)
else
    echo -e "${YELLOW}Service $SERVICE_NAME does not exist.${NC}"
    # Ask user for the directory
    read -p "Please provide the directory where DIG Node was installed (press Enter for current directory): " INSTALL_DIR
    INSTALL_DIR=${INSTALL_DIR:-$(pwd)}
fi

# Check if INSTALL_DIR exists
if [ ! -d "$INSTALL_DIR" ]; then
    echo -e "${RED}The directory $INSTALL_DIR does not exist. Exiting.${NC}"
    exit 1
fi

# Stop the service if it exists
if [ -f "$SERVICE_FILE_PATH" ]; then
    echo -e "${BLUE}Stopping $SERVICE_NAME service...${NC}"
    systemctl stop "$SERVICE_NAME"

    # Disable the service
    echo -e "${BLUE}Disabling $SERVICE_NAME service...${NC}"
    systemctl disable "$SERVICE_NAME"

    # Remove the service file
    echo -e "${BLUE}Removing service file at $SERVICE_FILE_PATH...${NC}"
    rm -f "$SERVICE_FILE_PATH"

    # Reload systemd daemon
    echo -e "${BLUE}Reloading systemd daemon...${NC}"
    systemctl daemon-reload

    echo -e "${GREEN}Service $SERVICE_NAME has been stopped and disabled.${NC}"
fi

# Detect Docker Compose command
DOCKER_COMPOSE_CMD=$(detect_docker_compose_cmd)

# Check if Docker Compose is installed
if [ -z "$DOCKER_COMPOSE_CMD" ]; then
    echo -e "${RED}Docker Compose is not installed. Skipping Docker services removal.${NC}"
else
    # Stop Docker Compose services
    if [ -f "$INSTALL_DIR/docker-compose.yml" ]; then
        echo -e "${BLUE}Stopping Docker Compose services in $INSTALL_DIR...${NC}"
        cd "$INSTALL_DIR" || { echo -e "${RED}Failed to change directory to $INSTALL_DIR. Exiting.${NC}"; exit 1; }
        $DOCKER_COMPOSE_CMD down
    else
        echo -e "${YELLOW}No docker-compose.yml found in $INSTALL_DIR. Skipping Docker Compose services stop.${NC}"
    fi

    # Optionally remove Docker volumes and networks
    echo -e "\n${YELLOW}Would you like to remove Docker volumes and networks created by the DIG Node?${NC}"
    read -p "(y/n): " -n 1 -r
    echo    # Move to a new line

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [ -f "$INSTALL_DIR/docker-compose.yml" ]; then
            echo -e "${BLUE}Removing Docker volumes and networks...${NC}"
            cd "$INSTALL_DIR" || { echo -e "${RED}Failed to change directory to $INSTALL_DIR. Exiting.${NC}"; exit 1; }
            $DOCKER_COMPOSE_CMD down -v --remove-orphans
            echo -e "${GREEN}Docker volumes and networks have been removed.${NC}"
        else
            echo -e "${YELLOW}No docker-compose.yml found in $INSTALL_DIR. Cannot remove Docker volumes and networks.${NC}"
        fi
    else
        echo -e "${YELLOW}Skipping removal of Docker volumes and networks.${NC}"
    fi
fi

# Ask the user if they want to close ports 80 and 443
echo -e "\n${YELLOW}Would you like to close ports 80 and 443 (used by the Nginx reverse proxy)?${NC}"
read -p "(y/n): " -n 1 -r
echo    # Move to a new line

if [[ $REPLY =~ ^[Yy]$ ]]; then
    close_ports 80 443
else
    echo -e "${YELLOW}Skipping closing of ports 80 and 443.${NC}"
fi

# Ask the user if they want to close the remaining ports
echo -e "\n${YELLOW}Would you like to close the remaining DIG Node ports (4159, 4160, 4161)?${NC}"
read -p "(y/n): " -n 1 -r
echo    # Move to a new line

if [[ $REPLY =~ ^[Yy]$ ]]; then
    close_ports 4159 4160 4161
else
    echo -e "${YELLOW}Skipping closing of remaining DIG Node ports.${NC}"
fi

echo -e "\n${GREEN}Uninstall complete. The DIG Node has been removed.${NC}"

###############################################################################
#                                End of Script
###############################################################################
