#!/usr/bin/env bash

detect_distro() {
    if [ -f /etc/os-release ]; then
        # Read the distro info
        . /etc/os-release
        DISTRO=$ID
    else
        DISTRO=$(uname -s)
    fi

    # Function to check if either docker-compose or docker compose is installed
    check_docker_compose_installed() {
        if command -v docker-compose >/dev/null 2>&1; then
            DOCKER_COMPOSE_INSTALLED="docker-compose"
        elif docker compose version >/dev/null 2>&1; then
            DOCKER_COMPOSE_INSTALLED="docker compose"
        else
            DOCKER_COMPOSE_INSTALLED=""
        fi
    }

    # Run the check for docker-compose
    check_docker_compose_installed

    case $DISTRO in
        ubuntu|debian)
            PACKAGE_MANAGER="apt"
            INSTALL_CMD="sudo apt install -y"
            FIREWALL="ufw"
            REQUIRED_SOFTWARE=(docker openssl certbot)
            # Add docker-compose based on what's available
            if [[ -z "$DOCKER_COMPOSE_INSTALLED" ]]; then
                REQUIRED_SOFTWARE+=(docker-compose)
            fi
            ;;
        centos|fedora|rhel|rocky|almalinux)
            PACKAGE_MANAGER="yum"
            INSTALL_CMD="sudo yum install -y"
            FIREWALL="firewalld"
            REQUIRED_SOFTWARE=(docker openssl certbot)
            if [[ -z "$DOCKER_COMPOSE_INSTALLED" ]]; then
                REQUIRED_SOFTWARE+=(docker-compose)
            fi
            ;;
        amzn)
            PACKAGE_MANAGER="yum"
            INSTALL_CMD="sudo yum install -y"
            FIREWALL="firewalld"
            REQUIRED_SOFTWARE=(docker amazon-linux-extras openssl certbot)
            if [[ -z "$DOCKER_COMPOSE_INSTALLED" ]]; then
                REQUIRED_SOFTWARE+=(docker-compose)
            fi
            ;;
        arch|manjaro)
            PACKAGE_MANAGER="pacman"
            INSTALL_CMD="sudo pacman -S --noconfirm"
            FIREWALL="ufw"
            REQUIRED_SOFTWARE=(docker openssl certbot)
            if [[ -z "$DOCKER_COMPOSE_INSTALLED" ]]; then
                REQUIRED_SOFTWARE+=(docker-compose)
            fi
            ;;
        opensuse*)
            PACKAGE_MANAGER="zypper"
            INSTALL_CMD="sudo zypper install -y"
            FIREWALL="firewalld"
            REQUIRED_SOFTWARE=(docker openssl certbot)
            if [[ -z "$DOCKER_COMPOSE_INSTALLED" ]]; then
                REQUIRED_SOFTWARE+=(docker-compose)
            fi
            ;;
        *)
            echo -e "${RED}Unsupported Linux distribution: $DISTRO${NC}"
            exit 1
            ;;
    esac
}
