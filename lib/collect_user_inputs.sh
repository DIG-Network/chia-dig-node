#!/usr/bin/env bash

collect_user_inputs() {
    # Ask if the user has a dynamic IP
    echo -e "\n${BLUE}Do you have a dynamic IP?${NC}"
    read -p "Press no if you want to use ip6 or you dont have a dynamic IP. (y/n): " -n 1 -r
    echo    # Move to a new line

    if [[ $REPLY =~ ^[Nn]$ ]]; then
        # Fetch public IP using the Datalayer API
        echo -e "\n${BLUE}Fetching your public IP address...${NC}"
        PUBLIC_IP_RESPONSE=$(curl -s --max-time 20 --connect-timeout 10 https://api.datalayer.storage/user/v1/get_user_ip | grep -o '"ip_address":[^,]*' | awk -F':' '{gsub(/"/,"",$2); print $2}')

        if [[ -z "$PUBLIC_IP_RESPONSE" || "$PUBLIC_IP_RESPONSE" == "null" ]]; then
            echo -e "${RED}Failed to automatically fetch your public IP address.${NC}"
            echo -e "${YELLOW}A value is ONLY needed here if you have a static IP and we weren't able to detect it. You can manually locate your public IP by searching 'what is my IP' in a search engine, or by visiting a site like ${CYAN}https://whatismyipaddress.com${YELLOW}.${NC}"
            read -p "Please manually enter your public IP address: " PUBLIC_IP
            PUBLIC_IP=${PUBLIC_IP:-"not-provided"}
        else
            echo -e "\n${BLUE}Detected public IP address: ${YELLOW}$PUBLIC_IP_RESPONSE${NC}"
            read -p "Is this correct? (y/n): " -n 1 -r
            echo    # Move to a new line

            if [[ $REPLY =~ ^[Yy]$ ]]; then
                PUBLIC_IP="$PUBLIC_IP_RESPONSE"
            else
                echo -e "${YELLOW}You may need to manually enter your public IP address.${NC}"
                read -p "Please manually enter your public IP address: " PUBLIC_IP
                PUBLIC_IP=${PUBLIC_IP:-"not-provided"}
            fi
        fi
    else
        # User has a dynamic IP, so public IP won't be set
        PUBLIC_IP="not-provided"
    fi

    # Prompt for TRUSTED_FULLNODE
    echo -e "\n${BLUE}Please enter the TRUSTED_FULLNODE (optional):${NC}"
    read -p "Your personal full node's public IP for better performance (press Enter to skip): " TRUSTED_FULLNODE
    TRUSTED_FULLNODE=${TRUSTED_FULLNODE:-"not-provided"}

    # If TRUSTED_FULLNODE is provided, ask for custom port
    if [[ "$TRUSTED_FULLNODE" != "not-provided" ]]; then
        read -p "Would you like to add a custom port for your trusted full node? (y/n): " -n 1 -r
        echo    # Move to a new line

        if [[ $REPLY =~ ^[Yy]$ ]]; then
            read -p "Please enter the custom port: " TRUSTED_FULLNODE_PORT
            TRUSTED_FULLNODE_PORT=${TRUSTED_FULLNODE_PORT:-"8444"}
        else
            TRUSTED_FULLNODE_PORT="8444"
        fi
    else
        TRUSTED_FULLNODE_PORT="8444"
    fi

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
    echo -e "TRUSTED_FULLNODE_PORT:  ${YELLOW}$TRUSTED_FULLNODE_PORT${NC}"
    echo -e "PUBLIC_IP:              ${YELLOW}$PUBLIC_IP${NC}"
    echo -e "MERCENARY_MODE:         ${YELLOW}$MERCENARY_MODE${NC}"
    echo -e "DISK_SPACE_LIMIT_BYTES: ${YELLOW}$DISK_SPACE_LIMIT_BYTES${NC}"
    echo "----------------------"

    # Explain TRUSTED_FULLNODE and PUBLIC_IP
    echo -e "\n${BLUE}Note:${NC}"
    echo " - TRUSTED_FULLNODE is optional. It can be your own full node's public IP for better performance."
    echo " - PUBLIC_IP should be set if your network setup requires an IP override."
}

