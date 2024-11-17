#!/usr/bin/env bash

create_docker_compose() {
    USER_HOME=$(eval echo ~${SUDO_USER})
    DOCKER_COMPOSE_FILE="$PWD/docker-compose.yml"
    echo -e "\n${BLUE}Creating docker-compose.yml at $DOCKER_COMPOSE_FILE...${NC}"

    # Begin writing the docker-compose.yml content
    cat <<EOF > $DOCKER_COMPOSE_FILE
version: '3.8'

services:
  redis:
    image: redis:latest
    container_name: redis
    ports:
      - "6379:6379"
    volumes:
      - redis-data:/data
    networks:
      - dig_network
    restart: always

  propagation-server:
    image: dignetwork/dig-propagation-server:latest-alpha
    container_name: propagation-server
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
      - USE_REDIS=true
      - REDIS_URL=redis://redis:6379
    depends_on:
      - redis
    restart: always
    networks:
      - dig_network

  content-server:
    image: dignetwork/dig-content-server:latest-alpha
    container_name: content-server
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
      - USE_REDIS=true
      - REDIS_URL=redis://redis:6379
    depends_on:
      - redis
    restart: always
    networks:
      - dig_network

  incentive-server:
    image: dignetwork/dig-incentive-server:latest-alpha
    container_name: incentive-server
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
      - USE_REDIS=true
      - REDIS_URL=redis://redis:6379
    depends_on:
      - redis
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
    container_name: chia-nodes
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
    restart: always
EOF
    else
        echo -e "${YELLOW}Chia FullNode will not be added.${NC}"
    fi

    # Prompt the user if they want to run Watchtower
    echo -e "${YELLOW}\nWatchtower is used to keep your containers up to date.${NC}"
    read -p "Would you like to run Watchtower? (y/n): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Adding Watchtower to the docker-compose file...${NC}"
        
        cat <<EOF >> $DOCKER_COMPOSE_FILE

  watchtower:
    image: containrrr/watchtower:latest
    container_name: watchtower
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    logging:
      options:
        max-size: "10m"
        max-file: 7
    networks:
      - dig_network
    environment:
      WATCHTOWER_POLL_INTERVAL: 3600
    restart: always
EOF
    else
        echo -e "${YELLOW}Watchtower will not be added.${NC}"
    fi

    # Include Nginx reverse-proxy if selected
    if [[ $INCLUDE_NGINX == "yes" ]]; then
        echo -e "${BLUE}Adding Nginx Reverse Proxy to the docker-compose file...${NC}"
        
        cat <<EOF >> $DOCKER_COMPOSE_FILE

  reverse-proxy:
    image: openresty/openresty:alpine-fat
    container_name: reverse-proxy
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - $USER_HOME/.dig/remote/.nginx/conf.d:/etc/nginx/conf.d
      - $USER_HOME/.dig/remote/.nginx/nginx.conf:/usr/local/openresty/nginx/conf/nginx.conf
      - $USER_HOME/.dig/remote/.nginx/certs:/etc/nginx/certs
      - $USER_HOME/.dig/remote/.nginx/lua:/usr/local/openresty/nginx/lua

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

    # Add the networks and volumes sections
    cat <<EOF >> $DOCKER_COMPOSE_FILE

networks:
  dig_network:
    driver: bridge

volumes:
  redis-data:
EOF

    echo -e "${GREEN}docker-compose.yml created successfully.${NC}"
}
