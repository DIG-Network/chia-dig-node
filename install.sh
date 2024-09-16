#!/bin/bash

# Variables
USER_NAME=${SUDO_USER:-$(whoami)}  # Use SUDO_USER if available, otherwise fall back to whoami
SERVICE_NAME="dig@$USER_NAME.service"
SERVICE_FILE_PATH="/etc/systemd/system/$SERVICE_NAME"
WORKING_DIR=$(pwd)

# Required software
REQUIRED_SOFTWARE=(docker docker-compose ufw openssl)

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check for required software
echo "Checking for required software..."
MISSING_SOFTWARE=()
for SOFTWARE in "${REQUIRED_SOFTWARE[@]}"; do
    if ! command_exists "$SOFTWARE"; then
        MISSING_SOFTWARE+=("$SOFTWARE")
    fi
done

if [ ${#MISSING_SOFTWARE[@]} -ne 0 ]; then
    echo "The following required software is missing:"
    for SOFTWARE in "${MISSING_SOFTWARE[@]}"; do
        echo " - $SOFTWARE"
    done
    echo "Please install the missing software and rerun the script."
    exit 1
fi

echo "All required software is installed."

# Function to stop the service if it's running
stop_existing_service() {
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        echo "Stopping the existing service $SERVICE_NAME..."
        systemctl stop "$SERVICE_NAME"
        echo "Service $SERVICE_NAME stopped."
    fi
}

# Function to ask the user to open ports using UFW
open_ports() {
    echo "This setup uses the following ports:"
    echo " - Port 80: Reverse Proxy (HTTP)"
    echo " - Port 443: Reverse Proxy (HTTPS, if enabled)"
    echo " - Port 4159: Propagation Server"
    echo " - Port 4160: Incentive Server"
    echo " - Port 4161: Content Server"
    echo ""
    read -p "Do you want to open these ports (80, 443, 4159, 4160, 4161) using UFW? (y/n): " -n 1 -r
    echo    # Move to a new line
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Opening ports 80, 443, 4159, 4160, and 4161..."
        sudo ufw allow 80
        sudo ufw allow 443
        sudo ufw allow 4159
        sudo ufw allow 4160
        sudo ufw allow 4161
        sudo ufw reload
        echo "Ports have been opened in UFW."
        echo ""
    else
        echo "Skipping UFW port opening."
    fi
}

# Function to attempt opening ports on the router using UPnP
open_ports_upnp() {
    echo "Attempting to open ports on the router using UPnP..."

    # Check if upnpc is installed
    if ! command_exists upnpc; then
        echo "Error: upnpc is not installed."
        echo "Please install 'upnpc' (part of the 'miniupnpc' package) to enable UPnP port forwarding."
        echo "You can install it using your package manager. For example:"
        echo " - On Debian/Ubuntu: sudo apt-get install miniupnpc"
        echo " - On CentOS/Fedora: sudo yum install miniupnpc"
        exit 1
    fi

    # Get the local IP address
    LOCAL_IP=$(hostname -I | awk '{print $1}')
    echo "Local IP address detected: $LOCAL_IP"

    # Ports to open
    PORTS=(80 443 4159 4160 4161)

    # Open each port using upnpc
    for PORT in "${PORTS[@]}"; do
        echo "Opening port $PORT..."
        upnpc -e "DIG Node Port $PORT" -a $LOCAL_IP $PORT $PORT TCP
    done

    echo "UPnP port forwarding attempted. Please verify that the ports have been opened on your router."
}

# Check if the script is being run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# Stop the existing service if it is running
stop_existing_service

# Check if the current user is in the Docker group
if id -nG "$USER_NAME" | grep -qw "docker"; then
    echo "User $USER_NAME is already in the docker group."
else
    echo "To work properly, your user must be added to the docker group."
    read -p "Would you like to add $USER_NAME to the docker group now? (y/n): " -n 1 -r
    echo    # Move to a new line
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        usermod -aG docker "$USER_NAME"
        echo "User $USER_NAME has been added to the docker group."
    else
        echo "User $USER_NAME must be in the docker group to proceed. Exiting."
        exit 1
    fi
fi

# Check again if the current user is in the Docker group
if id -nG "$USER_NAME" | grep -qw "docker"; then
    echo "User $USER_NAME is in the docker group."
else
    echo "Failed to add $USER_NAME to the docker group. Exiting."
    exit 1
fi

# Check if the working directory exists
if [ ! -d "$WORKING_DIR" ]; then
    echo "Working directory $WORKING_DIR does not exist. Please create it first."
    exit 1
fi

# Prompt user for values, but generate DIG_USERNAME and DIG_PASSWORD automatically
echo "Generating high-entropy DIG_USERNAME and DIG_PASSWORD..."
DIG_USERNAME=$(openssl rand -hex 16)
DIG_PASSWORD=$(openssl rand -hex 32)

# Ask user for TRUSTED_FULLNODE and default to "not-provided" if left blank
read -p "Please enter the TRUSTED_FULLNODE (your personal full node's public IP for better performance) [optional]: " TRUSTED_FULLNODE
TRUSTED_FULLNODE=${TRUSTED_FULLNODE:-"not-provided"}

# Ask user for PUBLIC_IP and default to "not-provided" if left blank
read -p "If needed, enter a PUBLIC_IP override (leave blank for auto-detection): " PUBLIC_IP
PUBLIC_IP=${PUBLIC_IP:-"not-provided"}

# Prompt for Mercenary Mode (Yes/No) and convert to true/false
read -p "Enable Mercenary Mode? Enabling this will allow your node to hunt for mirror offers to earn rewards (y/n): " -n 1 -r
echo    # Move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]; then
    MERCENARY_MODE="true"
else
    MERCENARY_MODE="false"
fi

# Ask user for DISK_SPACE_LIMIT_BYTES and default to 1 TB if left blank
read -p "If needed, enter a DISK_SPACE_LIMIT_BYTES override (leave blank for 1 TB): " DISK_SPACE_LIMIT_BYTES
DISK_SPACE_LIMIT_BYTES=${DISK_SPACE_LIMIT_BYTES:-"1099511627776"}

# Echo the variables back to the user
echo "DIG_USERNAME: $DIG_USERNAME"
echo "DIG_PASSWORD: $DIG_PASSWORD"
echo "TRUSTED_FULLNODE: $TRUSTED_FULLNODE"
echo "PUBLIC_IP: $PUBLIC_IP"
echo "MERCENARY_MODE: $MERCENARY_MODE"
echo "These values will be used in the DIG CLI."

# Explanation of the TRUSTED_FULLNODE and PUBLIC_IP
echo "TRUSTED_FULLNODE is optional. It should be your own full node's public IP if applicable."
echo "PUBLIC_IP should only be set if your network setup requires an IP override."

# Call the function to ask if user wants to open the ports
open_ports

# Ask the user if they want to attempt to automatically set up port forwarding on their router
read -p "Would you like to try to automatically set up port forwarding on your router using UPnP? (y/n): " -n 1 -r
echo    # Move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]; then
    open_ports_upnp
else
    echo "Skipping automatic router port forwarding."
fi

# Create docker-compose.yml with the provided values
DOCKER_COMPOSE_FILE=./docker-compose.yml
cat <<EOF > $DOCKER_COMPOSE_FILE
version: '3.8'
services:
  propagation-server:
    image: dignetwork/dig-propagation-server:latest-alpha
    ports:
      - "4159:4159"
    volumes:
      - ~/.dig/remote:/.dig
    environment:
      - DIG_USERNAME=$DIG_USERNAME
      - DIG_PASSWORD=$DIG_PASSWORD
      - DIG_FOLDER_PATH=/.dig
      - PORT=4159
      - REMOTE_NODE=1
      - TRUSTED_FULLNODE=$TRUSTED_FULLNODE
    restart: always

  content-server:
    image: dignetwork/dig-content-server:latest-alpha
    ports:
      - "4161:4161"
    volumes:
      - ~/.dig/remote:/.dig
    environment:
      - DIG_FOLDER_PATH=/.dig
      - PORT=4161
      - REMOTE_NODE=1
      - TRUSTED_FULLNODE=$TRUSTED_FULLNODE
    restart: always

  incentive-server:
    image: dignetwork/dig-incentive-server:latest-alpha
    ports:
      - "4160:4160"
    volumes:
      - ~/.dig/remote:/.dig
    environment:
      - DIG_USERNAME=$DIG_USERNAME
      - DIG_PASSWORD=$DIG_PASSWORD
      - DIG_FOLDER_PATH=/.dig
      - PORT=4160
      - REMOTE_NODE=1
      - TRUSTED_FULLNODE=$TRUSTED_FULLNODE
      - PUBLIC_IP=$PUBLIC_IP
      - DISK_SPACE_LIMIT_BYTES=$DISK_SPACE_LIMIT_BYTES
      - MERCENARY_MODE=$MERCENARY_MODE
    restart: always

  reverse-proxy:
    image: nginx:latest
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ~/.dig/remote/.nginx/conf.d:/etc/nginx/conf.d
      - ~/.dig/remote/.nginx/certs:/etc/nginx/certs
    depends_on:
      - content-server
    restart: always

networks:
  default:
    name: dig_network
EOF

echo "docker-compose.yml file created successfully at $DOCKER_COMPOSE_FILE."

# Create Nginx configuration files in ~/.dig/remote/.nginx
NGINX_CONF_DIR=~/.dig/remote/.nginx/conf.d
NGINX_CERTS_DIR=~/.dig/remote/.nginx/certs

mkdir -p "$NGINX_CONF_DIR"
mkdir -p "$NGINX_CERTS_DIR"

# Generate TLS client certificate and key for Nginx to use when proxying to the content server
echo "Generating TLS client certificate and key for Nginx..."

# Paths to the CA certificate and key
CA_CERT="./ssl/ca/chia_ca.crt"
CA_KEY="./ssl/ca/chia_ca.key"

# Check if CA certificate and key exist
if [ ! -f "$CA_CERT" ] || [ ! -f "$CA_KEY" ]; then
    echo "Error: CA certificate or key not found in ./ssl/ca/"
    echo "Please ensure chia_ca.crt and chia_ca.key are present in ./ssl/ca/ directory."
    exit 1
fi

# Generate client key
openssl genrsa -out "$NGINX_CERTS_DIR/client.key" 2048

# Generate client CSR
openssl req -new -key "$NGINX_CERTS_DIR/client.key" -subj "/CN=dig-nginx-client" -out "$NGINX_CERTS_DIR/client.csr"

# Generate client certificate signed by the CA
openssl x509 -req -in "$NGINX_CERTS_DIR/client.csr" -CA "$CA_CERT" -CAkey "$CA_KEY" -CAcreateserial -out "$NGINX_CERTS_DIR/client.crt" -days 365 -sha256

# Clean up CSR
rm "$NGINX_CERTS_DIR/client.csr"

echo "TLS client certificate and key generated and stored in $NGINX_CERTS_DIR"

# Ask the user if they would like to set a hostname
read -p "Would you like to set a hostname for your server? (y/n): " -n 1 -r
echo    # Move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]; then
    read -p "Please enter your hostname (e.g., example.com): " HOSTNAME
    USE_HOSTNAME="yes"
else
    HOSTNAME=$(hostname -I | awk '{print $1}')
    USE_HOSTNAME="no"
fi

# Generate default.conf based on hostname or IP address
if [[ $USE_HOSTNAME == "yes" ]]; then
    SERVER_NAME="$HOSTNAME"

    # Ask if they want to set up Let's Encrypt
    read -p "Would you like to attempt to set up Let's Encrypt for SSL certificates? (y/n): " -n 1 -r
    echo    # Move to a new line
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Error: Let's Encrypt setup is not supported in this script."
        echo "Please set up SSL certificates manually."
        exit 1
    else
        # Use the hostname without SSL
        cat <<EOF > "$NGINX_CONF_DIR/default.conf"
server {
    listen 80;
    server_name $SERVER_NAME;

    location / {
        proxy_pass https://content-server:4161;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_ssl_certificate /etc/nginx/certs/client.crt;
        proxy_ssl_certificate_key /etc/nginx/certs/client.key;
        proxy_ssl_trusted_certificate /etc/nginx/certs/chia_ca.crt;
        proxy_ssl_verify on;
    }
}
EOF
        echo "Nginx configuration for hostname without SSL has been created."
    fi
else
    SERVER_NAME="$HOSTNAME"
    # Use IP address in default.conf
    cat <<EOF > "$NGINX_CONF_DIR/default.conf"
server {
    listen 80;
    server_name $SERVER_NAME;

    location / {
        proxy_pass https://content-server:4161;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_ssl_certificate /etc/nginx/certs/client.crt;
        proxy_ssl_certificate_key /etc/nginx/certs/client.key;
        proxy_ssl_trusted_certificate /etc/nginx/certs/chia_ca.crt;
        proxy_ssl_verify on;
    }
}
EOF
    echo "Nginx configuration using IP address has been created."
fi

# Copy CA certificate to Nginx certs directory
cp "$CA_CERT" "$NGINX_CERTS_DIR/chia_ca.crt"

echo "Nginx configuration files are located in $NGINX_CONF_DIR."

echo "Please ensure your SSL certificates are correctly placed and named."

# Pull the latest Docker images
echo "Pulling the latest Docker images..."
docker-compose pull

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
ExecStart=$(command -v docker-compose) up
ExecStop=$(command -v docker-compose) down
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
systemctl enable "$SERVICE_NAME"

# Start the service
echo "Starting $SERVICE_NAME service..."
systemctl start "$SERVICE_NAME"

# Check the status of the service
echo "Checking the status of the service..."
systemctl --no-pager status "$SERVICE_NAME"

echo "Service $SERVICE_NAME installed and activated successfully."

echo "Please log out and log back in for the Docker group changes to take effect."
