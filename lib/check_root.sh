#!/usr/bin/env bash

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Please run this script as root.${NC}"
        exit 1
    fi
}
