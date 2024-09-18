# DIG Node Setup Script with SSL and Let's Encrypt

This repository contains a set of scripts to automate the installation and configuration of a DIG Node with an Nginx reverse proxy, SSL certificates using Let's Encrypt, and other necessary components. The scripts are designed to work across major Linux distributions and handle specific environments like Amazon EC2 instances.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Directory Structure](#directory-structure)
- [Installation](#installation)
- [Usage](#usage)
- [Script Descriptions](#script-descriptions)
- [Special Considerations](#special-considerations)
  - [Amazon EC2 Instances](#amazon-ec2-instances)
- [License](#license)

## Overview

The DIG Node Setup Script automates the process of setting up a DIG Node, including:

- Installing necessary software dependencies.
- Configuring Docker and Docker Compose.
- Setting up Nginx as a reverse proxy.
- Generating SSL certificates using Let's Encrypt.
- Configuring automatic SSL certificate renewal.
- Creating a systemd service for managing the DIG Node.

## Features

- **Cross-Distribution Compatibility**: Works on major Linux distributions (Ubuntu, Debian, CentOS, Fedora, Amazon Linux 2, Arch Linux, openSUSE).
- **Modular Design**: The script is broken into reusable components for easy maintenance and customization.
- **SSL Support**: Integrates Let's Encrypt for obtaining and renewing SSL certificates.
- **UPnP Port Forwarding**: Attempts to automatically open required ports using UPnP (if not on Amazon EC2).
- **Amazon EC2 Detection**: Automatically detects if running on an EC2 instance and adjusts behavior accordingly.
- **User Prompts**: Interactive prompts guide the user through the setup process.

## Prerequisites

Before running the setup script, ensure that the following software is installed on your system:

- **Docker**
- **Docker Compose**
- **OpenSSL**
- **Certbot** (for Let's Encrypt SSL certificates)
- **miniupnpc** (only if not running on Amazon EC2 and you wish to use UPnP for port forwarding)

**Note**: The script checks for these dependencies and will exit if any are missing, prompting you to install them manually.

## Directory Structure

The repository should have the following structure:

```
setup-dig-node.sh
lib/
├── ask_include_nginx.sh
├── check_root.sh
├── check_software.sh
├── colors.sh
├── collect_user_inputs.sh
├── create_docker_compose.sh
├── create_systemd_service.sh
├── detect_distro.sh
├── detect_ec2.sh
├── docker_compose_setup.sh
├── docker_group.sh
├── generate_credentials.sh
├── nginx_setup.sh
├── open_ports.sh
├── open_ports_upnp.sh
├── pull_docker_images.sh
├── stop_existing_service.sh
ssl/
└── ca/
    ├── chia_ca.crt
    └── chia_ca.key
```

## Installation

1. **Clone the Repository**

   ```bash
   git clone https://github.com/yourusername/dig-node-setup.git
   cd dig-node-setup
   ```

2. **Ensure Executable Permissions**

   ```bash
   chmod +x setup-dig-node.sh
   chmod +x lib/*.sh
   ```

3. **Prepare SSL CA Files**

   - Place your `chia_ca.crt` and `chia_ca.key` files in the `./ssl/ca/` directory.

## Usage

Run the main setup script as the root user:

```bash
sudo ./setup-dig-node.sh
```

The script will guide you through the setup process with interactive prompts.

## Script Descriptions

### 1. **Main Script (`setup-dig-node.sh`)**

The primary script that orchestrates the setup process by calling functions from the scripts in the `lib/` directory.

### 2. **Color Definitions (`lib/colors.sh`)**

Defines color codes for output formatting.

### 3. **Root Check (`lib/check_root.sh`)**

Ensures the script is run as the root user.

### 4. **Detect Distribution (`lib/detect_distro.sh`)**

Detects the Linux distribution and sets variables accordingly.

### 5. **Detect EC2 Instance (`lib/detect_ec2.sh`)**

Checks if the script is running on an Amazon EC2 instance.

### 6. **Software Check (`lib/check_software.sh`)**

Verifies that all required software dependencies are installed. Exits if any are missing.

### 7. **Docker Group Check (`lib/docker_group.sh`)**

Ensures the current user is in the Docker group to run Docker commands without `sudo`.

### 8. **Stop Existing Service (`lib/stop_existing_service.sh`)**

Stops any existing DIG Node service to prevent conflicts.

### 9. **Generate Credentials (`lib/generate_credentials.sh`)**

Generates high-entropy `DIG_USERNAME` and `DIG_PASSWORD`.

### 10. **Collect User Inputs (`lib/collect_user_inputs.sh`)**

Prompts the user for additional configuration options, such as:

- Trusted full node IP
- Public IP override
- Enabling Mercenary Mode
- Disk space limit

### 11. **Ask Include Nginx (`lib/ask_include_nginx.sh`)**

Asks the user if they wish to include the Nginx reverse-proxy container.

### 12. **Open Ports (`lib/open_ports.sh`)**

Opens the required ports using the appropriate firewall management tool (`ufw` or `firewalld`).

### 13. **Open Ports UPnP (`lib/open_ports_upnp.sh`)**

Attempts to automatically open required ports on the router using UPnP. Skipped on Amazon EC2 instances.

### 14. **Docker Compose Setup (`lib/docker_compose_setup.sh`)**

Generates the `docker-compose.yml` file based on user inputs.

### 15. **Nginx Setup (`lib/nginx_setup.sh`)**

Sets up Nginx as a reverse proxy, generates SSL client certificates, and integrates Let's Encrypt SSL certificates if a hostname is provided.

### 16. **Pull Docker Images (`lib/pull_docker_images.sh`)**

Pulls the latest Docker images for the DIG Node services.

### 17. **Create Systemd Service (`lib/create_systemd_service.sh`)**

Creates and enables a systemd service to manage the DIG Node using `docker-compose`.

## Special Considerations

### Amazon EC2 Instances

- **UPnP Port Forwarding**: The script detects if it's running on an Amazon EC2 instance and skips the UPnP port forwarding step, as UPnP is not supported on EC2.

- **Security Groups**: Ensure that your AWS Security Groups are configured to allow inbound traffic on the required ports:

  - SSH: **22**
  - HTTP: **80** (if using Nginx)
  - HTTPS: **443** (if using Nginx)
  - DIG Node Ports: **4159**, **4160**, **4161**

- **Public IP Configuration**: When prompted for the public IP, you may need to provide the Elastic IP associated with your EC2 instance.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

**Note**: Replace `https://github.com/yourusername/dig-node-setup.git` with the actual URL of your repository.

## Troubleshooting

- **Missing Software Dependencies**: If the script exits due to missing software, install the required packages using your distribution's package manager.

- **Docker Group Changes**: If you are added to the Docker group during the setup, you may need to log out and log back in for the changes to take effect.

- **SSL Certificate Issues**: Ensure that your domain name is correctly pointed to your server's public IP and that ports **80** and **443** are accessible from the internet before attempting to obtain Let's Encrypt SSL certificates.

## Contributing

Contributions are welcome! Please submit pull requests or open issues for any bugs or feature requests.

## Contact

For questions or support, please contact [your-email@example.com](mailto:your-email@example.com).

---

**Disclaimer**: This script is provided as-is without any warranty. Use it at your own risk. Always review scripts and understand their functionality before executing them on your system.