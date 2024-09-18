#!/bin/bash

create_systemd_service() {
    SERVICE_NAME="dig-node.service"
    SERVICE_FILE_PATH="/etc/systemd/system/$SERVICE_NAME"
    WORKING_DIR=$(pwd)

    echo -e "\n${BLUE}Creating systemd service file at $SERVICE_FILE_PATH...${NC}"
    read -p "Do you want to create and enable the systemd service for DIG Node? (y/n): " -n 1 -r
    echo    # Move to a new line
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cat <<EOF > $SERVICE_FILE_PATH
[Unit]
Description=Dig Node Docker Compose
After=network.target docker.service
Requires=docker.service

[Service]
WorkingDirectory=$WORKING_DIR
ExecStart=$(command -v docker-compose) up
ExecStop=$(command -v docker-compose) down
Restart=always
User=$USER_NAME
Group=docker
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF

        # Reload systemd daemon
        echo -e "\n${BLUE}Reloading systemd daemon...${NC}"
        systemctl daemon-reload

        # Enable and start the service
        echo -e "\n${BLUE}Enabling and starting $SERVICE_NAME service...${NC}"
        systemctl enable "$SERVICE_NAME"
        systemctl start "$SERVICE_NAME"

        # Check the status of the service
        echo -e "\n${BLUE}Checking the status of the service...${NC}"
        systemctl --no-pager status "$SERVICE_NAME"

        echo -e "\n${GREEN}Service $SERVICE_NAME installed and activated successfully.${NC}"
    else
        echo -e "${YELLOW}Skipping systemd service creation. You can manually start the DIG Node using 'docker-compose up'${NC}"
    fi
}
