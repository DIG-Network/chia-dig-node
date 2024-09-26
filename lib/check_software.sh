#!/bin/bash

check_software() {
    echo -e "${BLUE}Checking for required software...${NC}"
    MISSING_SOFTWARE=()

    # Required software list
    REQUIRED_SOFTWARE=(docker docker-compose openssl certbot)

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

    # If any software is missing, inform the user and exit
    if [ ${#MISSING_SOFTWARE[@]} -ne 0 ]; then
        echo -e "${RED}The following required software is missing:${NC}"
        for SOFTWARE in "${MISSING_SOFTWARE[@]}"; do
            echo " - $SOFTWARE"
        done

        echo -e "\n${YELLOW}Please install the missing software using your package manager and rerun the script.${NC}"
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
