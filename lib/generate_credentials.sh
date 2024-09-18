#!/bin/bash

generate_credentials() {
    echo -e "${BLUE}Generating high-entropy DIG_USERNAME and DIG_PASSWORD...${NC}"
    DIG_USERNAME=$(openssl rand -hex 16)
    DIG_PASSWORD=$(openssl rand -hex 32)
    echo -e "${GREEN}Credentials generated successfully.${NC}"
}
