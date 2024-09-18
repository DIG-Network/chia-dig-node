#!/bin/bash

collect_user_inputs() {
    # Prompt for TRUSTED_FULLNODE
    echo -e "\n${BLUE}Please enter the TRUSTED_FULLNODE (optional):${NC}"
    read -p "Your personal full node's public IP for better performance (press Enter to skip): " TRUSTED_FULLNODE
    TRUSTED_FULLNODE=${TRUSTED_FULLNODE:-"not-provided"}

    # Prompt for PUBLIC_IP
    echo -e "\n${BLUE}If needed, enter a PUBLIC_IP override (optional):${NC}"
    read -p "Leave blank for auto-detection: " PUBLIC_IP
    PUBLIC_IP=${PUBLIC_IP:-"not-provided"}

    # Prompt for Mercenary Mode
    echo -e "\n${BLUE}Enable Mercenary Mode?${NC}"
    echo "This allows your node to hunt for mirror offers to earn rewards."
    read -p "Do you want to enable Mercenary Mode? (y/n): " -n 1 -r
    echo    # Move to a new line

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        MERCENARY_MODE="true"
    else
        MERCENARY_MODE="false"
    fi

    # Prompt for DISK_SPACE_LIMIT_BYTES
    echo -e "\n${BLUE}Enter DISK_SPACE_LIMIT_BYTES (optional):${NC}"
    read -p "Leave blank for default (1 TB): " DISK_SPACE_LIMIT_BYTES
    DISK_SPACE_LIMIT_BYTES=${DISK_SPACE_LIMIT_BYTES:-"1099511627776"}

    # Display configuration summary
    echo -e "\n${GREEN}Configuration Summary:${NC}"
    echo "----------------------"
    echo -e "DIG_USERNAME:           ${YELLOW}$DIG_USERNAME${NC}"
    echo -e "DIG_PASSWORD:           ${YELLOW}$DIG_PASSWORD${NC}"
    echo -e "TRUSTED_FULLNODE:       ${YELLOW}$TRUSTED_FULLNODE${NC}"
    echo -e "PUBLIC_IP:              ${YELLOW}$PUBLIC_IP${NC}"
    echo -e "MERCENARY_MODE:         ${YELLOW}$MERCENARY_MODE${NC}"
    echo -e "DISK_SPACE_LIMIT_BYTES: ${YELLOW}$DISK_SPACE_LIMIT_BYTES${NC}"
    echo "----------------------"

    # Explain TRUSTED_FULLNODE and PUBLIC_IP
    echo -e "\n${BLUE}Note:${NC}"
    echo " - TRUSTED_FULLNODE is optional. It can be your own full node's public IP for better performance."
    echo " - PUBLIC_IP should be set if your network setup requires an IP override."
}
