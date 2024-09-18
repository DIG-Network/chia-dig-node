#!/bin/bash

###############################################################################
#                       DIG Node Setup Script with SSL and Let's Encrypt
# This script installs and configures a DIG Node with Nginx reverse proxy,
# using HTTPS to communicate with the content server, and attaching client
# certificates. It also sets up Let's Encrypt SSL certificates if a hostname
# is provided and the user opts in. Please run this script as root.
###############################################################################

# Load reusable functions
source ./lib/colors.sh
source ./lib/check_root.sh
source ./lib/detect_distro.sh
source ./lib/detect_ec2.sh        # Include EC2 detection
source ./lib/check_software.sh
source ./lib/docker_group.sh
source ./lib/stop_existing_service.sh
source ./lib/generate_credentials.sh
source ./lib/collect_user_inputs.sh
source ./lib/ask_include_nginx.sh
source ./lib/open_ports.sh
source ./lib/open_ports_upnp.sh
source ./lib/docker_compose_setup.sh
source ./lib/nginx_setup.sh
source ./lib/pull_docker_images.sh
source ./lib/create_systemd_service.sh

###############################################################################
#                         Script Execution Begins
###############################################################################

# Ensure the script is run as root
check_root

# Display script header
echo -e "${GREEN}
###############################################################################
#                       DIG Node Setup Script with SSL and Let's Encrypt
###############################################################################
${NC}"

# Detect the distribution and set package manager and service commands
detect_distro

# Detect if running on an Amazon EC2 instance
detect_ec2

# Check for required software at the beginning
check_software

# Stop the existing DIG Node service if running
stop_existing_service

# Check if the current user is in the Docker group
docker_group_check

# Generate high-entropy DIG_USERNAME and DIG_PASSWORD
generate_credentials

# Collect additional user inputs (trusted full node, public IP, Mercenary Mode)
collect_user_inputs

# Ask if the user wants to include the Nginx reverse-proxy container
ask_include_nginx

# Open ports using the appropriate firewall
ask_open_ports

# Attempt to open ports using UPnP (skip if on EC2)
if [[ $IS_EC2_INSTANCE == "yes" ]]; then
    echo -e "${YELLOW}Running on Amazon EC2 instance. Skipping UPnP port forwarding.${NC}"
else
    ask_upnp_ports
fi

# Create docker-compose.yml file
create_docker_compose

# Setup Nginx reverse proxy if chosen
nginx_setup

# Pull latest Docker images
pull_docker_images

# Create systemd service file
create_systemd_service

# Completion message
echo -e "${GREEN}Your DIG Node setup is complete!${NC}"

###############################################################################
#                                End of Script
###############################################################################
