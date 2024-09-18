#!/bin/bash

stop_existing_service() {
    SERVICE_NAME="dig-node.service"  # Adjust service name as needed

    if systemctl is-active --quiet "$SERVICE_NAME"; then
        echo -e "\n${YELLOW}Stopping the existing service $SERVICE_NAME...${NC}"
        systemctl stop "$SERVICE_NAME"
        echo -e "${GREEN}Service $SERVICE_NAME stopped.${NC}"
    fi
}
