#!/usr/bin/env bash

docker_group_check() {
    USER_NAME=${SUDO_USER:-$(whoami)}  # User executing the script

    if id -nG "$USER_NAME" | grep -qw "docker"; then
        echo -e "${GREEN}User $USER_NAME is already in the docker group.${NC}"
    else
        echo -e "${YELLOW}User must be added to the docker group to run Docker without sudo.${NC}"
        read -p "Would you like to add $USER_NAME to the docker group now? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            usermod -aG docker "$USER_NAME"
            echo -e "${GREEN}User $USER_NAME added to the docker group.${NC}"
            echo -e "${YELLOW}Please log out and log back in for the changes to take effect.${NC}"
        else
            echo -e "${RED}User must be in the docker group to proceed.${NC}"
            exit 1
        fi
    fi
}
