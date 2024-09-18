#!/bin/bash

pull_docker_images() {
    echo -e "\n${BLUE}Pulling the latest Docker images...${NC}"
    docker-compose pull
}
