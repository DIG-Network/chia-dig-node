#!/bin/bash

check_software() {
    echo -e "${BLUE}Checking for required software...${NC}"
    MISSING_SOFTWARE=()
    DOCKER_COMPOSE_CMD=""

    # Required software list
    REQUIRED_SOFTWARE=(docker openssl certbot)

    # Check if docker-compose or docker compose is available and set an alias for docker-compose
    if command -v docker-compose >/dev/null 2>&1; then
        DOCKER_COMPOSE_CMD="docker-compose"
    elif docker compose version >/dev/null 2>&1; then
        DOCKER_COMPOSE_CMD="docker compose"
    else
        MISSING_SOFTWARE+=("docker-compose")
    fi

    # Include UPnP command check only if not running on EC2
    if [[ $IS_EC2_INSTANCE != "yes" ]]; then
        # Check for upnpc or miniupnpc command
        if ! command -v upnpc >/dev/null 2>&1 && ! command -v miniupnpc >/dev/null 2>&1; then
            MISSING_SOFTWARE+=("miniupnpc")
            UPnP_CMD="missing"
        else
            UPnP_CMD=$(command -v upnpc || command -v miniupnpc)
        fi
    fi

    # Check for each required software
    for SOFTWARE in "${REQUIRED_SOFTWARE[@]}"; do
        if ! command -v "$SOFTWARE" >/dev/null 2>&1; then
            MISSING_SOFTWARE+=("$SOFTWARE")
        fi
    done

    # If any software is missing, inform the user and provide instructions
    if [ ${#MISSING_SOFTWARE[@]} -ne 0 ]; then
        echo -e "${RED}The following required software is missing:${NC}"
        for SOFTWARE in "${MISSING_SOFTWARE[@]}"; do
            echo " - $SOFTWARE"
        done

        echo -e "\n${YELLOW}Please install the missing software using your package manager and rerun the script.${NC}"

        for SOFTWARE in "${MISSING_SOFTWARE[@]}"; do
            if [[ "$SOFTWARE" == "docker" || "$SOFTWARE" == "docker-compose" ]]; then
                echo -e "${YELLOW}To install Docker and Docker Compose, follow the instructions here:${NC}"
                echo -e "${CYAN}https://wiki.crowncloud.net/?How_to_Install_and_use_Docker_Compose_on_Ubuntu_24_04${NC}"
            fi
        done

        echo -e "${YELLOW}For example:${NC}"

        case $PACKAGE_MANAGER in
            apt)
                echo "sudo apt update && sudo apt install -y ${MISSING_SOFTWARE[*]}"
                ;;
            yum)
                echo "sudo yum install -y ${MISSING_SOFTWARE[*]}"
                ;;
            pacman)
                echo "sudo pacman -Sy --noconfirm ${MISSING_SOFTWARE[*]}"
                ;;
            zypper)
                echo "sudo zypper install -y ${MISSING_SOFTWARE[*]}"
                ;;
            *)
                echo -e "${RED}Unsupported package manager. Please install the software manually.${NC}"
                ;;
        esac

        exit 1
    fi

    echo -e "${GREEN}All required software is installed.${NC}"
}