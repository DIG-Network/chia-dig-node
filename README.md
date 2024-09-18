# DIG Node Setup Script README

## Overview
This Bash script automates the setup of a DIG Node. It configures a full node for the DIG network, sets up Nginx as a reverse proxy, enables SSL with Let's Encrypt, and configures firewall rules and port forwarding. The script requires root privileges to run and is designed to simplify the process of setting up a secure, fully operational DIG node.

## Features
- Installs necessary software (Docker, Docker Compose, UFW, OpenSSL, and Certbot).
- Configures Nginx for reverse proxy, with support for HTTPS.
- Optionally sets up SSL certificates using Let's Encrypt.
- Opens required firewall ports using UFW and optionally configures UPnP for router port forwarding.
- Generates secure credentials for the DIG node.
- Configures a `docker-compose.yml` file to manage DIG services (Propagation Server, Content Server, Incentive Server).
- Optionally sets up Nginx to serve traffic over HTTPS.
- Supports automatic certificate renewal for Let's Encrypt.
- Optionally creates and starts a systemd service for managing the DIG node.
- Provides user-friendly prompts and logs the progress in the terminal.

## Prerequisites
- Must be run as `root` or with `sudo`.
- Requires a Linux-based operating system with support for package managers like `apt-get` or `yum`.
- The following software must be installed (or will be prompted to install):
  - `docker`
  - `docker-compose`
  - `ufw`
  - `openssl`
  - `certbot` (if using Let's Encrypt for SSL certificates)
  - `upnpc` (if UPnP port forwarding is desired)

## How to Run
1. Ensure the script has executable permissions:
   ```bash
   chmod +x setup-dig-node.sh
   ```
2. Run the script as root:
   ```bash
   sudo ./setup-dig-node.sh
   ```

## Configuration Options
The script offers several configurable options through user prompts:
- **Nginx reverse proxy**: You can choose to set up an Nginx reverse proxy with SSL support.
- **UFW firewall**: The script will ask if you want to automatically open the required ports.
- **UPnP router configuration**: You can enable UPnP for automatic port forwarding on your router.
- **SSL with Let's Encrypt**: If Nginx is enabled, the script can automatically request and configure SSL certificates.

### Service Configuration
The script generates a `docker-compose.yml` file that defines three services for the DIG network:
1. **Propagation Server**: Listens on port 4159.
2. **Incentive Server**: Listens on port 4160.
3. **Content Server**: Listens on port 4161.

If Nginx is selected, it acts as a reverse proxy on ports 80 (HTTP) and 443 (HTTPS).

### Systemd Service
Optionally, the script can create a systemd service to manage the DIG node, making it easier to start and stop the node as a service.

## Ports Used
- **4159**: Propagation Server
- **4160**: Incentive Server
- **4161**: Content Server
- **80**: Nginx reverse proxy (HTTP, if enabled)
- **443**: Nginx reverse proxy (HTTPS, if enabled)

## Post-Setup Notes
- If Nginx and Let's Encrypt are configured, the script will also offer to set up automatic SSL certificate renewal via cron.
- After the script completes, you will need to log out and log back in for the changes to take effect (especially if the Docker group was modified).

## Troubleshooting
- If SSL certificates fail to generate, ensure that:
  - The hostname is correctly mapped to the public IP.
  - No other service is running on port 80.
- If the DIG node is inaccessible, check that UFW or router port forwarding is properly configured.

## End of README
This script is a comprehensive setup for a secure DIG node with Nginx reverse proxy and optional SSL via Let's Encrypt. Follow the prompts and instructions during the script's execution to customize the setup for your specific environment.