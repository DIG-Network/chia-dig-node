#!/usr/bin/env bash

ask_open_ports() {
    echo -e "${BLUE}This setup uses the following ports:${NC}"
    echo " - Port 22: SSH (for remote access)"
    echo " - Port 4159: Propagation Server"
    echo " - Port 4160: Incentive Server"
    echo " - Port 4161: Content Server"
    echo " - Port 8444: Chia FullNode"
    echo " - Port 8555: Chia FullNode"

    if [[ $INCLUDE_NGINX == "yes" ]]; then
        echo " - Port 80: Reverse Proxy (HTTP)"
        echo " - Port 443: Reverse Proxy (HTTPS)"
        PORTS=(22 80 443 4159 4160 4161 8444 8555)
    else
        PORTS=(22 4159 4160 4161 8444 8555)
    fi

    echo ""
    echo "This install script can automatically attempt to configure your ports."
    echo "If you do not like this port configuration, you can input No and configure the ports manually."
    read -p "Do you want to open these ports (${PORTS[*]}) using the firewall? (y/n): " -n 1 -r
    echo    # Move to a new line

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        open_ports
    else
        echo -e "${YELLOW}Skipping firewall port configuration.${NC}"
    fi
}

open_ports() {
    echo -e "\n${BLUE}Opening ports: ${PORTS[*]}...${NC}"

    # Use the appropriate firewall management tool based on the distribution
    case $FIREWALL in
        ufw)
            for PORT in "${PORTS[@]}"; do
                echo -e "${YELLOW}Allowing port $PORT on UFW...${NC}"
                ufw allow "$PORT"
            done
            ufw reload
            echo -e "${GREEN}Ports opened successfully with UFW.${NC}"
            ;;
        firewalld)
            for PORT in "${PORTS[@]}"; do
                echo -e "${YELLOW}Allowing port $PORT on Firewalld...${NC}"
                firewall-cmd --permanent --add-port="$PORT"/tcp
            done
            firewall-cmd --reload
            echo -e "${GREEN}Ports opened successfully with Firewalld.${NC}"
            ;;
        *)
            echo -e "${RED}Unsupported firewall: $FIREWALL${NC}"
            exit 1
            ;;
    esac
}
