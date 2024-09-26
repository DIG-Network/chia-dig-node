#!/bin/bash

ask_include_nginx() {
    echo "We need to set up a reverse proxy to your DIG Node's content server."
    echo "If you already have a reverse proxy setup, such as nginx,"
    echo "You should skip this and manually set up port 80 and port 443 to map to your DIG Node's content server at port 4161."
    echo -e "\n${BLUE}Would you like to include the Nginx reverse-proxy container?${NC}"
    read -p "(y/n): " -n 1 -r
    echo    # Move to a new line

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        INCLUDE_NGINX="yes"
    else
        INCLUDE_NGINX="no"
        echo -e "\n${YELLOW}Warning:${NC} You have chosen not to include the Nginx reverse-proxy container."
        echo -e "${YELLOW}Unless you plan on exposing port 80/443 in another way, your DIG Node's content server will be inaccessible to the browser.${NC}"
    fi
}
