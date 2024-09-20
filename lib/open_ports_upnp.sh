#!/bin/bash

ask_upnp_ports() {
    echo -e "\n${BLUE}Would you like to try to automatically set up port forwarding on your router using UPnP?${NC}"
    read -p "(y/n): " -n 1 -r
    echo    # Move to a new line

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        open_ports_upnp
    else
        echo -e "${YELLOW}Skipping automatic router port forwarding.${NC}"
    fi
}

open_ports_upnp() {
    echo -e "\n${BLUE}Attempting to open ports on the router using UPnP...${NC}"

    # Determine which UPnP command is available
    if command -v upnpc >/dev/null 2>&1; then
        UPnP_CMD="upnpc"
    elif command -v miniupnpc >/dev/null 2>&1; then
        UPnP_CMD="miniupnpc"
    else
        echo -e "${RED}Error: Neither 'upnpc' nor 'miniupnpc' command is available.${NC}"
        echo -e "${YELLOW}Please install 'miniupnpc' package and rerun the script.${NC}"
        exit 1
    fi

    # Get the local IP address
    LOCAL_IP=$(hostname -I | awk '{print $1}')
    if [[ -z "$LOCAL_IP" ]]; then
        echo -e "${RED}Could not determine local IP address.${NC}"
        exit 1
    fi
    echo -e "Local IP address detected: ${GREEN}$LOCAL_IP${NC}"

    # Ports to open
    if [[ $INCLUDE_NGINX == "yes" ]]; then
        PORTS=(22 80 443 4159 4160 4161 8444 8555)
    else
        PORTS=(22 4159 4160 4161 8444 8555)
    fi

    # Open each port using the available UPnP command
    for PORT in "${PORTS[@]}"; do
        echo -e "${YELLOW}Attempting to open port $PORT via UPnP...${NC}"
        $UPnP_CMD -e "DIG Node Port $PORT" -a "$LOCAL_IP" "$PORT" "$PORT" TCP
    done

    echo -e "${GREEN}UPnP port forwarding attempted.${NC}"
    echo -e "${YELLOW}Please verify that the ports have been opened on your router.${NC}"
}
