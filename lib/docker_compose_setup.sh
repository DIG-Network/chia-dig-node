#!/bin/bash

create_docker_compose() {
    DOCKER_COMPOSE_FILE="$PWD/docker-compose.yml"
    echo -e "\n${BLUE}Creating docker-compose.yml at $DOCKER_COMPOSE_FILE...${NC}"

    # Begin writing the docker-compose.yml content
    cat <<EOF > $DOCKER_COMPOSE_FILE
version: '3.8'

services:
  propagation-server:
    image: dignetwork/dig-propagation-server:latest-alpha
    ports:
      - "4159:4159"
    volumes:
      - $USER_HOME/.dig/remote:/.dig
    environment:
      - DIG_USERNAME=$DIG_USERNAME
      - DIG_PASSWORD=$DIG_PASSWORD
      - DIG_FOLDER_PATH=/.dig
      - PORT=4159
      - REMOTE_NODE=1
      - TRUSTED_FULLNODE=$TRUSTED_FULLNODE
    restart: always
    networks:
      - dig_network

  content-server:
    image: dignetwork/dig-content-server:latest-alpha
    ports:
      - "4161:4161"
    volumes:
      - $USER_HOME/.dig/remote:/.dig
    environment:
      - DIG_FOLDER_PATH=/.dig
      - PORT=4161
      - REMOTE_NODE=1
      - TRUSTED_FULLNODE=$TRUSTED_FULLNODE
    restart: always
    networks:
      - dig_network

  incentive-server:
    image: dignetwork/dig-incentive-server:latest-alpha
    ports:
      - "4160:4160"
    volumes:
      - $USER_HOME/.dig/remote:/.dig
    environment:
      - DIG_USERNAME=$DIG_USERNAME
      - DIG_PASSWORD=$DIG_PASSWORD
      - DIG_FOLDER_PATH=/.dig
      - PORT=4160
      - REMOTE_NODE=1
      - TRUSTED_FULLNODE=$TRUSTED_FULLNODE
      - PUBLIC_IP=$PUBLIC_IP
      - DISK_SPACE_LIMIT_BYTES=$DISK_SPACE_LIMIT_BYTES
      - MERCENARY_MODE=$MERCENARY_MODE
    restart: always
    networks:
      - dig_network
EOF

    # Include Nginx reverse-proxy if selected
    if [[ $INCLUDE_NGINX == "yes" ]]; then
        cat <<EOF >> $DOCKER_COMPOSE_FILE

  reverse-proxy:
    image: nginx:latest
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - $USER_HOME/.dig/remote/.nginx/conf.d:/etc/nginx/conf.d
      - $USER_HOME/.dig/remote/.nginx/certs:/etc/nginx/certs
    depends_on:
      - content-server
    networks:
      - dig_network
    restart: always
EOF
    fi

    # Add the networks section
    cat <<EOF >> $DOCKER_COMPOSE_FILE

networks:
  dig_network:
    driver: bridge
EOF

    echo -e "${GREEN}docker-compose.yml created successfully.${NC}"
}
