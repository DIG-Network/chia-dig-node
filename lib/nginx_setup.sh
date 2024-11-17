#!/usr/bin/env bash

# Function to display messages in color
function echo_color() {
    local color="$1"
    local message="$2"
    case "$color" in
        "red")
            echo -e "\e[31m${message}\e[0m"
            ;;
        "green")
            echo -e "\e[32m${message}\e[0m"
            ;;
        "yellow")
            echo -e "\e[33m${message}\e[0m"
            ;;
        "blue")
            echo -e "\e[34m${message}\e[0m"
            ;;
        *)
            echo "${message}"
            ;;
    esac
}

# Function to check for ACME TXT record
function check_acme_challenge() {
    local domain="$1"
    local token="$2"
    local timeout="$3"
    local interval="$4"
    local elapsed=0

    echo_color "yellow" "Waiting for DNS propagation of ACME challenge..."
    while [ $elapsed -lt $timeout ]; do
        # Query the TXT record for _acme-challenge.domain
        local txt_records
        txt_records=$(dig TXT +short "_acme-challenge.$domain")

        # Check if the token is present in the TXT records
        if echo "$txt_records" | grep -q "$token"; then
            echo_color "green" "ACME challenge TXT record detected."
            return 0
        fi

        sleep $interval
        elapsed=$((elapsed + interval))
        echo_color "yellow" "ACME challenge TXT record not found yet. Checking again in $interval seconds..."
    done

    echo_color "red" "Timeout reached. ACME challenge TXT record not detected."
    return 1
}

# Main setup function
nginx_setup() {
    # Define user home directory
    USER_HOME=$(eval echo ~${SUDO_USER})

    # Prompt for hostname
    echo_color "blue" "Would you like to set a hostname for your server? (e.g., example.com)"
    read -p "(y/n): " -n 1 -r
    echo    # Move to a new line

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Please enter your hostname (e.g., example.com): " HOSTNAME
        USE_HOSTNAME="yes"
    else
        USE_HOSTNAME="no"
        HOSTNAME="_"
    fi

    # Define directories
    NGINX_CONF_DIR="$USER_HOME/.dig/remote/.nginx/conf.d"
    NGINX_CERTS_DIR="$USER_HOME/.dig/remote/.nginx/certs"
    NGINX_MAIN_CONF="$USER_HOME/.dig/remote/.nginx/nginx.conf"
    NGINX_LUA_DIR="$USER_HOME/.dig/remote/.nginx/lua"
    DOCKER_COMPOSE_FILE="$USER_HOME/.dig/remote/docker-compose.yml"

    # Create necessary directories
    echo_color "blue" "Creating necessary directories..."
    mkdir -p "$NGINX_CONF_DIR"
    mkdir -p "$NGINX_CERTS_DIR"
    mkdir -p "$NGINX_LUA_DIR"

    # Create Lua Base62 Encoder/Decoder Module
    echo_color "blue" "Creating Lua Base62 module..."
    cat <<'EOF' > "$NGINX_LUA_DIR/base62.lua"
-- base62.lua
local Base62 = {}
Base62.__index = Base62

local charset = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"

function Base62.encode(data)
    local number = 0
    for i = 1, #data do
        number = number * 256 + data:byte(i)
    end

    local encoded = ""
    local base = 62
    while number > 0 do
        local remainder = number % base
        number = math.floor(number / base)
        encoded = charset:sub(remainder + 1, remainder + 1) .. encoded
    end

    return encoded
end

function Base62.decode(str)
    local number = 0
    local base = 62

    for i = 1, #str do
        local char = str:sub(i, i)
        local index = string.find(charset, char, 1, true)
        if not index then
            return nil, "Invalid character '" .. char .. "' in Base62 string"
        end
        number = number * base + (index - 1)
    end

    -- Convert the big integer back to binary data
    local bytes = {}
    while number > 0 do
        local byte = number % 256
        number = math.floor(number / 256)
        table.insert(bytes, 1, string.char(byte))
    end

    return table.concat(bytes)
end

return Base62
EOF
    echo_color "green" "Lua Base62 module created."

    # Create Lua Decoder Module (Simplified, Reversible ID without HMAC)
    echo_color "blue" "Creating Lua Decoder module..."
    cat <<'EOF' > "$NGINX_LUA_DIR/decoder.lua"
-- decoder.lua
local Base62 = require("base62")

local Decoder = {}
Decoder.__index = Decoder

function Decoder.decode(encodedId)
    -- Decode the Base62 string back to binary data
    local decodedData, err = Base62.decode(encodedId)
    if not decodedData then
        return nil, "Failed to decode Base62: " .. err
    end

    -- Ensure there's at least 1 byte for chain_length and STORE_ID_LENGTH bytes for storeId
    local STORE_ID_LENGTH = 32 -- bytes
    if #decodedData < (1 + STORE_ID_LENGTH) then
        return nil, "Decoded data is too short to contain required fields."
    end

    -- Extract chain_length (1 byte)
    local chain_length = string.byte(decodedData:sub(1,1))

    # Define the expected total length
    local expected_length = 1 + chain_length + STORE_ID_LENGTH
    if #decodedData ~= expected_length then
        return nil, "Decoded data length mismatch. Expected " .. expected_length .. " bytes, got " .. #decodedData .. " bytes."
    end

    -- Extract chain and storeId
    local chain = decodedData:sub(2, 1 + chain_length)
    local storeId = decodedData:sub(2 + chain_length, 1 + chain_length + STORE_ID_LENGTH)

    -- Convert storeId binary to hex string
    local storeIdHex = storeId:gsub(".", function(c)
        return string.format("%02x", string.byte(c))
    end)

    return {
        chain = chain,
        storeId = storeIdHex
    }
end

return Decoder
EOF
    echo_color "green" "Lua Decoder module created."

    # Create Main Nginx Configuration
    echo_color "blue" "Creating main Nginx configuration..."
    cat <<EOF > "$NGINX_MAIN_CONF"
worker_processes auto;

events {
    worker_connections 1024;
}

http {
    lua_package_path "/etc/nginx/lua/?.lua;;";
    lua_shared_dict base32_cache 10m;

    include /etc/nginx/conf.d/*.conf;

    sendfile        on;
    keepalive_timeout  65;
}
EOF
    echo_color "green" "Main Nginx configuration created."

    # Create Nginx Server Blocks
    echo_color "blue" "Creating Nginx server blocks..."

    if [[ $USE_HOSTNAME == "yes" ]]; then
        # Redirect HTTP to HTTPS
        cat <<EOF > "$NGINX_CONF_DIR/redirect.conf"
server {
    listen 80;
    server_name $HOSTNAME;
    return 301 https://\$host\$request_uri;
}
EOF

        # HTTPS server block for main hostname (proxying without encodedId)
        cat <<EOF > "$NGINX_CONF_DIR/main.conf"
server {
    listen 443 ssl;
    server_name $HOSTNAME;

    ssl_certificate /etc/nginx/certs/fullchain.pem;
    ssl_certificate_key /etc/nginx/certs/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location / {
        proxy_pass http://content-server:4161;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

        # Encoded subdomain server block
        cat <<EOF > "$NGINX_CONF_DIR/encoded.conf"
server {
    listen 443 ssl;
    server_name ~^(?<encodedId>[A-Za-z0-9]{1,63})\.$HOSTNAME$;

    ssl_certificate /etc/nginx/certs/fullchain.pem;
    ssl_certificate_key /etc/nginx/certs/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location / {
        # Decode the encodedId to retrieve chain and storeId
        access_by_lua_block {
            local Decoder = require("decoder")
            local encodedId = ngx.var.encodedId

            if not encodedId then
                ngx.log(ngx.ERR, "No encodedId provided")
                ngx.exit(ngx.HTTP_BAD_REQUEST)
            end

            -- Decode the encodedId using Decoder module
            local decoded, err = Decoder.decode(encodedId)
            if not decoded then
                ngx.log(ngx.ERR, "Failed to decode encodedId: " .. err)
                ngx.exit(ngx.HTTP_BAD_REQUEST)
            end

            local chain = decoded.chain
            local storeId = decoded.storeId

            -- Set variables for use in proxy_pass
            ngx.var.chain = chain
            ngx.var.storeId = storeId
        }

        # Proxy to content server with chain and storeId as query parameters
        proxy_pass http://content-server:4161/?chain=$chain&storeId=$storeId$request_uri;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF

        echo_color "green" "Nginx server blocks for hostname and encoded IDs created."
    else
        # If hostname is not set, create a default server block without SSL
        cat <<EOF > "$NGINX_CONF_DIR/default.conf"
server {
    listen 80 default_server;
    server_name _;

    location / {
        proxy_pass http://content-server:4161;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

        echo_color "green" "Default Nginx server block without SSL created."
    fi

    # Create Docker Compose File if it doesn't exist
    if [[ ! -f "$DOCKER_COMPOSE_FILE" ]]; then
        echo_color "blue" "Creating Docker Compose file..."
        cat <<EOF > "$DOCKER_COMPOSE_FILE"
version: '3.8'

services:
  reverse-proxy:
    image: nginx:latest
    container_name: reverse-proxy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - "$NGINX_CONF_DIR:/etc/nginx/conf.d"
      - "$NGINX_CERTS_DIR:/etc/nginx/certs"
      - "$NGINX_LUA_DIR:/etc/nginx/lua"
    depends_on:
      - content-server

  content-server:
    image: your-content-server-image
    container_name: content-server
    restart: unless-stopped
    # Add your content server configurations here
EOF
        echo_color "green" "Docker Compose file created at $DOCKER_COMPOSE_FILE."
    else
        echo_color "yellow" "Docker Compose file already exists at $DOCKER_COMPOSE_FILE. Skipping creation."
    fi

    # Handle SSL Certificates
    echo_color "blue" "Setting up SSL certificates..."

    # Prompt user to choose between Let's Encrypt or Self-Signed
    echo_color "blue" "Choose SSL certificate option:"
    echo "1. Let's Encrypt (Recommended for production)"
    echo "2. Self-Signed Certificate (For development/testing)"
    read -p "Enter your choice (1 or 2): " SSL_OPTION

    if [[ "$SSL_OPTION" == "1" ]]; then
        # Prompt for email address
        echo_color "blue" "Please enter your email address for Let's Encrypt notifications:"
        read -p "Email: " LETSENCRYPT_EMAIL

        # Set up Let's Encrypt using certbot
        echo_color "blue" "Setting up Let's Encrypt SSL certificates for $HOSTNAME..."

        # Ensure certbot is installed
        if ! command -v certbot &> /dev/null; then
            echo_color "red" "certbot could not be found. Please install certbot and rerun the script."
            exit 1
        fi

        # Obtain SSL certificates with DNS-01 challenge
        echo_color "blue" "Starting Let's Encrypt DNS-01 challenge setup..."
        certbot certonly --manual --preferred-challenges dns \
            -d "*.$HOSTNAME" \
            -d "$HOSTNAME" \
            --agree-tos --no-eff-email --email "$LETSENCRYPT_EMAIL" --manual-public-ip-logging-ok

        # Extract the DNS TXT token for _acme-challenge.$HOSTNAME
        # Note: Certbot does not provide an easy way to extract the token programmatically
        # Therefore, we'll prompt the user to input the token manually
        echo_color "yellow" "Please provide the DNS TXT record value for _acme-challenge.$HOSTNAME:"
        read -p "ACME Challenge Token: " ACME_TOKEN

        # Function to check DNS TXT record
        check_acme_challenge "$HOSTNAME" "$ACME_TOKEN" 600 30  # 10 minutes timeout, check every 30 seconds

        # Start a loop to check for the ACME challenge
        echo_color "blue" "Verifying ACME challenge DNS TXT record..."
        MAX_ATTEMPTS=20
        INTERVAL=30  # seconds
        ATTEMPT=1
        while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
            # Query the TXT record
            TXT_RECORD=$(dig TXT +short "_acme-challenge.$HOSTNAME")

            # Check if the token is present
            if echo "$TXT_RECORD" | grep -q "$ACME_TOKEN"; then
                echo_color "green" "ACME challenge TXT record detected."
                break
            else
                echo_color "yellow" "ACME challenge TXT record not found. Attempt $ATTEMPT/$MAX_ATTEMPTS."
                sleep $INTERVAL
                ATTEMPT=$((ATTEMPT + 1))
            fi

            if [ $ATTEMPT -gt $MAX_ATTEMPTS ]; then
                echo_color "red" "ACME challenge verification failed after $MAX_ATTEMPTS attempts."
                exit 1
            fi
        done

        # Copy certificates to Nginx certs directory
        echo_color "blue" "Copying SSL certificates to Nginx certs directory..."
        cp /etc/letsencrypt/live/"$HOSTNAME"/fullchain.pem "$NGINX_CERTS_DIR/fullchain.pem"
        cp /etc/letsencrypt/live/"$HOSTNAME"/privkey.pem "$NGINX_CERTS_DIR/privkey.pem"

        echo_color "green" "Let's Encrypt SSL certificates obtained and copied."

        # Optionally, set up automatic renewal
        echo_color "blue" "Would you like to set up automatic certificate renewal for Let's Encrypt? (y/n)"
        read -p "(y/n): " -n 1 -r
        echo    # Move to a new line

        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo_color "blue" "Setting up cron job for automatic certificate renewal..."
            # Add renewal command to crontab
            (crontab -l 2>/dev/null; echo "0 0 * * * certbot renew --manual --preferred-challenges dns --manual-public-ip-logging-ok && docker-compose -f $DOCKER_COMPOSE_FILE restart reverse-proxy") | crontab -
            echo_color "green" "Automatic certificate renewal has been set up."
        else
            echo_color "yellow" "Skipping automatic certificate renewal setup."
        fi
    elif [[ "$SSL_OPTION" == "2" ]]; then
        # Generate Self-Signed Certificates
        echo_color "blue" "Generating self-signed SSL certificates for $HOSTNAME..."

        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout "$NGINX_CERTS_DIR/privkey.pem" \
            -out "$NGINX_CERTS_DIR/fullchain.pem" \
            -subj "/CN=$HOSTNAME"

        echo_color "green" "Self-signed SSL certificates generated."
    else
        echo_color "red" "Invalid choice for SSL certificate option. Exiting."
        exit 1
    fi

    # Inform user about setting up Docker Compose
    echo_color "blue" "Starting Docker Compose services..."
    docker-compose -f "$DOCKER_COMPOSE_FILE" up -d

    echo_color "green" "Nginx reverse proxy setup complete and running."
}
