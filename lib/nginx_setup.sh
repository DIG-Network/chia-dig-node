

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

    # Create Lua Decoder Module (Simplified, Reversible ID without HMAC)
    echo_color "blue" "Creating Lua Decoder module..."
cat > "$BASE_DIR/.nginx/lua/subdomain_decoder.lua" << 'EOL'
local baseX = require "baseX"

local SubDomainDecoder = {}

-- Define the Base62 character set
local BASE62_CHARSET = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
local STORE_ID_LENGTH = 32

local base62 = baseX.new(BASE62_CHARSET)

function SubDomainDecoder.decode(encodedId)
    if not encodedId then
        return nil, "Invalid encodedId: encodedId must be a non-empty string"
    end

    -- Decode the Base62 string
    local decoded = base62:decode(encodedId)
    if not decoded then
        return nil, "Failed to decode Base62 string"
    end

    -- Extract chain length (first byte)
    local chain_length = string.byte(decoded, 1)
    
    -- Validate minimum length
    if #decoded < (1 + chain_length + STORE_ID_LENGTH) then
        return nil, "Decoded data is too short"
    end

    -- Extract chain
    local chain = string.sub(decoded, 2, 1 + chain_length)
    
    -- Extract storeId (as raw bytes)
    local storeId_raw = string.sub(decoded, 2 + chain_length, 1 + chain_length + STORE_ID_LENGTH)
    
    -- Convert storeId to hex
    local storeId = ""
    for i = 1, #storeId_raw do
        storeId = storeId .. string.format("%02x", string.byte(storeId_raw, i))
    end

    return {
        chain = chain,
        storeId = storeId
    }
end

return SubDomainDecoder
EOL

    # Create Main Nginx Configuration
    echo_color "blue" "Creating main Nginx configuration..."
    cat <<EOF > "$NGINX_MAIN_CONF"
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    
    access_log /var/log/nginx/access.log main;
    
    sendfile on;
    keepalive_timeout 65;
    
    lua_package_path "/usr/local/openresty/nginx/lua/?.lua;;";
    
    include /etc/nginx/conf.d/*.conf;
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
sserver {
    listen 80;
    server_name ~^(?<subdomain>[^.]+)\.yourdomain\.com$;

    location / {
        access_by_lua_block {
            local subdomain_decoder = require "subdomain_decoder"
            local decoded, err = subdomain_decoder.decode(ngx.var.subdomain)
            
            if err then
                ngx.status = 400
                ngx.say("Invalid subdomain format: " .. err)
                ngx.exit(ngx.HTTP_BAD_REQUEST)
            end
            
            -- Store the decoded values in nginx variables for use in proxy_pass
            ngx.var.chain = decoded.chain
            ngx.var.store_id = decoded.storeId
        }

        # Proxy to your content server with the decoded information
        proxy_pass http://content-server:3000/store/$store_id/chain/$chain;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
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
        # Set up Let's Encrypt using certbot
        echo_color "blue" "Setting up Let's Encrypt SSL certificates for $HOSTNAME..."

        # Ensure certbot is installed
        if ! command -v certbot &> /dev/null; then
            echo_color "red" "certbot could not be found. Please install certbot and rerun the script."
            exit 1
        fi

        # Obtain SSL certificates
        certbot certonly --manual --preferred-challenges dns \
            -d "*.$HOSTNAME" \
            -d "$HOSTNAME" \
            --agree-tos --no-eff-email --email "youremail@example.com" --manual-public-ip-logging-ok

        # Check if certbot was successful
        if [[ $? -ne 0 ]]; then
            echo_color "red" "Failed to obtain SSL certificates with Let's Encrypt."
            exit 1
        fi

        # Copy certificates to Nginx certs directory
        cp /etc/letsencrypt/live/"$HOSTNAME"/fullchain.pem "$NGINX_CERTS_DIR/fullchain.pem"
        cp /etc/letsencrypt/live/"$HOSTNAME"/privkey.pem "$NGINX_CERTS_DIR/privkey.pem"

        echo_color "green" "Let's Encrypt SSL certificates obtained and copied."
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
