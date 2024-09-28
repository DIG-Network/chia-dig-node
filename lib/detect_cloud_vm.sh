#!/bin/bash

detect_cloud_vm() {
    local url
    local headers

    # AWS EC2 metadata
    url="http://169.254.169.254/latest/meta-data/"
    headers=$(curl -sI --max-time 1 $url | grep "200 OK")
    if [[ ! -z "$headers" ]]; then
        echo -e "${YELLOW}Running on AWS EC2${NC}"
        IS_CLOUD_VM="yes"
        return
    fi
    
    # Azure metadata
    url="http://169.254.169.254/metadata/instance?api-version=2021-02-01"
    response=$(curl -s -H "Metadata:true" --max-time 1 "$url")
    if [[ $response == *"compute"* ]]; then
        echo -e "${YELLOW}Running on Azure${NC}"
        IS_CLOUD_VM="yes"
        return
    fi
    
    # Google Cloud metadata
    url="http://169.254.169.254/computeMetadata/v1/"
    headers=$(curl -sI --max-time 1 -H "Metadata-Flavor: Google" $url | grep "200 OK")
    if [[ ! -z "$headers" ]]; then
        echo -e "${YELLOW}Running on Google Cloud${NC}"
        IS_CLOUD_VM="yes"
        return
    fi
    
    # DigitalOcean metadata
    url="http://169.254.169.254/metadata/v1/"
    headers=$(curl -sI --max-time 1 $url | grep "200 OK")
    if [[ ! -z "$headers" ]]; then
        echo -e "${YELLOW}Running on DigitalOcean${NC}"
        IS_CLOUD_VM="yes"
        return
    fi
    
    # Vultr metadata
    url="http://169.254.169.254/v1/"
    headers=$(curl -sI --max-time 1 $url | grep "200 OK")
    if [[ ! -z "$headers" ]]; then
        echo -e "${YELLOW}Running on Vultr${NC}"
        IS_CLOUD_VM="yes"
        return
    fi
    
    # Linode metadata
    url="http://169.254.169.254/"
    headers=$(curl -sI --max-time 1 $url | grep "200 OK")
    if [[ ! -z "$headers" ]]; then
        echo -e "${YELLOW}Running on Linode${NC}"
        IS_CLOUD_VM="yes"
        return
    fi
    
    # Scaleway metadata
    url="http://169.254.169.254/"
    headers=$(curl -sI --max-time 1 $url | grep "200 OK")
    if [[ ! -z "$headers" ]]; then
        echo -e "${YELLOW}Running on Scaleway${NC}"
        IS_CLOUD_VM="yes"
        return
    fi
    
    # Hetzner metadata
    url="http://169.254.169.254/hetzner/v1/"
    headers=$(curl -sI --max-time 1 $url | grep "200 OK")
    if [[ ! -z "$headers" ]]; then
        echo -e "${YELLOW}Running on Hetzner Cloud${NC}"
        IS_CLOUD_VM="yes"
        return
    fi
    
    echo -e "${GREEN}Cloud provider not detected${NC}"
    IS_CLOUD_VM="no"
}