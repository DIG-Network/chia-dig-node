#!/usr/bin/env bash

create_docker_compose() {
    USER_HOME=$(eval echo ~${SUDO_USER})
    DOCKER_COMPOSE_FILE="$PWD/docker-compose.yml"
    echo -e "\n${BLUE}Creating docker-compose.yml at $DOCKER_COMPOSE_FILE...${NC}"

    # Begin writing the docker-compose.yml content
    cat <<EOF > $DOCKER_COMPOSE_FILE
services:
  propagation-server:
    image: dignetwork/dig-propagation-server:latest-alpha
    ports:
      - "4159:4159"
    volumes:
      - $USER_HOME/.dig/remote:/.dig
    logging:
      options:
        max-size: "10m"
        max-file: 7
    environment:
      - DIG_USERNAME=$DIG_USERNAME
      - DIG_PASSWORD=$DIG_PASSWORD
      - DIG_FOLDER_PATH=/.dig
      - PORT=4159
      - REMOTE_NODE=1
      - TRUSTED_FULLNODE=$TRUSTED_FULLNODE
      - TRUSTED_FULLNODE_PORT=$TRUSTED_FULLNODE_PORT
    restart: always
    networks:
      - dig_network

  content-server:
    image: dignetwork/dig-content-server:latest-alpha
    ports:
      - "4161:4161"
    volumes:
      - $USER_HOME/.dig/remote:/.dig
    logging:
      options:
        max-size: "10m"
        max-file: 7
    environment:
      - DIG_FOLDER_PATH=/.dig
      - PORT=4161
      - REMOTE_NODE=1
      - TRUSTED_FULLNODE=$TRUSTED_FULLNODE
      - TRUSTED_FULLNODE_PORT=$TRUSTED_FULLNODE_PORT
    restart: always
    networks:
      - dig_network

  incentive-server:
    image: dignetwork/dig-incentive-server:latest-alpha
    ports:
      - "4160:4160"
    volumes:
      - $USER_HOME/.dig/remote:/.dig
    logging:
      options:
        max-size: "10m"
        max-file: 7
    environment:
      - DIG_USERNAME=$DIG_USERNAME
      - DIG_PASSWORD=$DIG_PASSWORD
      - DIG_FOLDER_PATH=/.dig
      - PORT=4160
      - REMOTE_NODE=1
      - TRUSTED_FULLNODE=$TRUSTED_FULLNODE
      - TRUSTED_FULLNODE_PORT=$TRUSTED_FULLNODE_PORT
      - PUBLIC_IP=$PUBLIC_IP
      - DISK_SPACE_LIMIT_BYTES=$DISK_SPACE_LIMIT_BYTES
      - MERCENARY_MODE=$MERCENARY_MODE
    restart: always
    networks:
      - dig_network
EOF

    # Prompt the user if they want to run a Chia FullNode
    echo -e "${YELLOW}\nFor best performance, it's highly recommended to run a Chia FullNode with the DIG Node.${NC}"
    echo -e "${YELLOW}However, please be aware that running a fullnode requires significant resources (CPU, memory, storage) and may take time to sync.${NC}"
    echo -e "${YELLOW}Ensure this machine can handle it before proceeding.${NC}"
    read -p "Would you like to run a Chia FullNode? (y/n): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Adding Chia FullNode to the docker-compose file...${NC}"
        
        cat <<EOF >> $DOCKER_COMPOSE_FILE

  chia-nodes:
    image: ghcr.io/chia-network/chia:latest
    ports:
      - "8444:8444"
      - "8555:8555"
    environment:
      CHIA_ROOT: /chia-data
      service: node
      self_hostname: 0.0.0.0
      keys: "persistent"
    logging:
      options:
        max-size: "10m"
        max-file: 7
    volumes:
      - ~/.dig/chia-data:/chia-data
    networks:
      - dig_network
EOF
    else
        echo -e "${YELLOW}Chia FullNode will not be added.${NC}"
    fi

    # Prompt the user if they want to run a Chia FullNode
    echo -e "${YELLOW}\nWatchtower is used to keep your containers up to date.${NC}"
    read -p "Would you like to runWatchtower? (y/n): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cat <<EOF >> $DOCKER_COMPOSE_FILE

  watchtower:
    image: containrrr/watchtower:latest
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    logging:
      options:
        max-size: "10m"
        max-file: 7
    networks:
      - dig_network
    restart: always
EOF
    else
        echo -e "${YELLOW}Watchtower will not be added.${NC}"
    fi

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
    logging:
      options:
        max-size: "10m"
        max-file: 7
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
