#!/usr/bin/env bash

nginx_setup() {
    USER_HOME=$(eval echo ~${SUDO_USER})
    if [[ $INCLUDE_NGINX == "yes" ]]; then
        echo -e "${BLUE}Setting up Nginx reverse-proxy...${NC}"

        # Nginx directories
        NGINX_CONF_DIR="$USER_HOME/.dig/remote/.nginx/conf.d"
        NGINX_CERTS_DIR="$USER_HOME/.dig/remote/.nginx/certs"

        # Create directories
        mkdir -p "$NGINX_CONF_DIR"
        mkdir -p "$NGINX_CERTS_DIR"

            # Create main Nginx configuration
    echo -e "\e[34mCreating main Nginx configuration...\e[0m"
    rm -f "$BASE_DIR/.nginx/nginx.conf"
    cat <<'EOF' > "$BASE_DIR/.nginx/nginx.conf"
worker_processes auto;
error_log /var/log/nginx/error.log debug;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    default_type application/octet-stream;
    
    log_format main '[$time_local] $remote_addr "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" host=$http_host '
                    'encodedId="$encodedId" '
                    'lua_log="$lua_log_message"';
    
    access_log /var/log/nginx/access.log main buffer=4k flush=1s;
    
    sendfile on;
    keepalive_timeout 65;
    
    lua_package_path "/usr/local/openresty/nginx/lua/?.lua;;";
    
    include /etc/nginx/conf.d/*.conf;
}
EOF

    echo -e "\e[34mCreating Lua decoder module...\e[0m"
    rm -f "$BASE_DIR/.nginx/lua/subdomain_decoder.lua"
    cat <<'EOF' > "$BASE_DIR/.nginx/lua/subdomain_decoder.lua"
-- subdomain_decoder.lua

local SubDomainDecoder = {}

-- Define the Base36 character set (only lowercase letters and digits)
local BASE36_CHARSET = "0123456789abcdefghijklmnopqrstuvwxyz"
local BASE36_BASE = 36
local STORE_ID_LENGTH = 32 -- bytes

-- Create reverse lookup table for faster decoding
local base36_lookup = {}
for i = 1, #BASE36_CHARSET do
    local char = BASE36_CHARSET:sub(i, i)
    base36_lookup[char] = i - 1
end

-- Function to convert a byte array to a Lua string
local function bytes_to_string(bytes)
    local chars = {}
    for i = 1, #bytes do
        chars[i] = string.char(bytes[i])
    end
    return table.concat(chars)
end

-- Function to convert a Lua string to a byte array
local function string_to_bytes(str)
    local bytes = {}
    for i = 1, #str do
        bytes[i] = string.byte(str, i)
    end
    return bytes
end

-- Function to multiply a big number by a small integer
local function multiply_big_num(num, multiplier)
    local carry = 0
    for i = #num, 1, -1 do
        local prod = num[i] * multiplier + carry
        num[i] = prod % 256
        carry = math.floor(prod / 256)
    end
    while carry > 0 do
        table.insert(num, 1, carry % 256)
        carry = math.floor(carry / 256)
    end
    return num
end

-- Function to add a small integer to a big number
local function add_big_num(num, digit)
    local carry = digit
    for i = #num, 1, -1 do
        local sum = num[i] + carry
        num[i] = sum % 256
        carry = math.floor(sum / 256)
        if carry == 0 then
            break
        end
    end
    while carry > 0 do
        table.insert(num, 1, carry % 256)
        carry = math.floor(carry / 256)
    end
    return num
end

-- Function to decode a Base36 string to a byte string
local function decode_base36(str)
    if not str or str == "" then
        return nil, "Input string is empty"
    end

    -- Convert string to lowercase to ensure consistency
    str = string.lower(str)

    -- Count leading '0's which represent leading zero bytes
    local leading_zeroes = 0
    for i = 1, #str do
        if str:sub(i, i) == '0' then
            leading_zeroes = leading_zeroes + 1
        else
            break
        end
    end

    -- Initialize big number as empty
    local num = {}

    -- Decode the rest of the string
    for i = leading_zeroes + 1, #str do
        local char = str:sub(i, i)
        local digit = base36_lookup[char]
        if digit == nil then
            return nil, "Invalid character in Base36 string: " .. char
        end
        num = multiply_big_num(num, BASE36_BASE)
        num = add_big_num(num, digit)
    end

    -- Convert big number to bytes
    local decoded = {}
    for _, byte in ipairs(num) do
        table.insert(decoded, byte)
    end

    -- Prepend leading zero bytes
    for i = 1, leading_zeroes do
        table.insert(decoded, 1, 0)
    end

    return bytes_to_string(decoded)
end

function SubDomainDecoder.decode(encodedId)
    ngx.log(ngx.ERR, "Decoding: ", encodedId)

    if not encodedId or encodedId == "" then
        return nil, "Invalid encodedId: encodedId must be a non-empty string"
    end

    -- Decode Base36 string
    local decoded, err = decode_base36(encodedId)
    if not decoded then
        return nil, "Failed to decode Base36 string: " .. (err or "unknown error")
    end

    -- Ensure decoded length is at least 1 byte for chain_length
    if #decoded < 1 then
        return nil, "Decoded data is too short to contain chain length."
    end

    -- Extract chain length (first byte)
    local chain_length = string.byte(decoded, 1)
    ngx.log(ngx.ERR, "Chain length: ", chain_length)

    -- Extract chain
    local chain = string.sub(decoded, 2, 1 + chain_length)

    -- Debug chain bytes
    local chain_bytes = ""
    for i = 1, #chain do
        chain_bytes = chain_bytes .. string.format("%02X ", string.byte(chain, i))
    end
    ngx.log(ngx.ERR, "Chain bytes: ", chain_bytes)

    -- Extract storeId
    local storeId_start = 2 + chain_length
    local storeId_raw = string.sub(decoded, storeId_start, storeId_start + STORE_ID_LENGTH - 1)

    -- Debug storeId bytes
    local store_bytes = ""
    for i = 1, #storeId_raw do
        store_bytes = store_bytes .. string.format("%02X ", string.byte(storeId_raw, i))
    end
    ngx.log(ngx.ERR, "StoreId bytes: ", store_bytes)

    -- Convert storeId to hex
    local storeId = ""
    for i = 1, #storeId_raw do
        storeId = storeId .. string.format("%02x", string.byte(storeId_raw, i))
    end

    -- Set Nginx variables for proxy_pass
    ngx.var.chain = chain
    ngx.var.storeId = storeId

    return {
        chain = chain,
        storeId = storeId
    }
end

-- Optional: Implement encode if needed
-- function SubDomainDecoder.encode(chain, storeId)
--     -- Implement encoding logic similar to the TypeScript class
--     -- This can be used if you need to encode within Lua
-- end

return SubDomainDecoder
EOF

        # Generate TLS client certificate and key
        echo -e "\n${BLUE}Generating TLS client certificate and key for Nginx...${NC}"

        # Paths to the CA certificate and key (assumed to be in ./ssl/ca/)
        CA_CERT="./ssl/ca/chia_ca.crt"
        CA_KEY="./ssl/ca/chia_ca.key"

        # Check if CA certificate and key exist
        if [ ! -f "$CA_CERT" ] || [ ! -f "$CA_KEY" ]; then
            echo -e "${RED}Error: CA certificate or key not found in ./ssl/ca/${NC}"
            echo "Please ensure chia_ca.crt and chia_ca.key are present in ./ssl/ca/ directory."
            exit 1
        fi

        # Generate client key and certificate
        openssl genrsa -out "$NGINX_CERTS_DIR/client.key" 2048
        openssl req -new -key "$NGINX_CERTS_DIR/client.key" -subj "/CN=dig-nginx-client" -out "$NGINX_CERTS_DIR/client.csr"
        openssl x509 -req -in "$NGINX_CERTS_DIR/client.csr" -CA "$CA_CERT" -CAkey "$CA_KEY" \
        -CAcreateserial -out "$NGINX_CERTS_DIR/client.crt" -days 365 -sha256

        # Clean up CSR
        rm "$NGINX_CERTS_DIR/client.csr"
        cp "$CA_CERT" "$NGINX_CERTS_DIR/chia_ca.crt"

        echo -e "${GREEN}TLS client certificate and key generated.${NC}"

        # Prompt for hostname
        echo -e "\n${BLUE}Would you like to set a hostname for your server?${NC}"
        read -p "(y/n): " -n 1 -r
        echo    # Move to a new line

        if [[ $REPLY =~ ^[Yy]$ ]]; then
            read -p "Please enter your hostname (e.g., example.com): " HOSTNAME
            USE_HOSTNAME="yes"
        else
            USE_HOSTNAME="no"
        fi

        # Generate Nginx configuration
        if [[ $USE_HOSTNAME == "yes" ]]; then
            SERVER_NAME="$HOSTNAME"
            LISTEN_DIRECTIVE="listen 80;"
        else
            SERVER_NAME="_"
            LISTEN_DIRECTIVE="listen 80 default_server;"
        fi

        cat <<EOF > "$NGINX_CONF_DIR/default.conf"
server {
    $LISTEN_DIRECTIVE
    server_name $SERVER_NAME;

    location / {
        proxy_pass http://content-server:4161;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_ssl_certificate /etc/nginx/certs/client.crt;
        proxy_ssl_certificate_key /etc/nginx/certs/client.key;
        proxy_ssl_trusted_certificate /etc/nginx/certs/chia_ca.crt;
        proxy_ssl_verify off;
    }
}
EOF

        echo -e "${GREEN}Nginx configuration has been set up at $NGINX_CONF_DIR/default.conf${NC}"

        if [[ $USE_HOSTNAME == "yes" ]]; then
            # Ask the user if they would like to set up Let's Encrypt
            echo -e "\n${BLUE}Would you like to set up Let's Encrypt SSL certificates for your hostname?${NC}"
            read -p "(y/n): " -n 1 -r
            echo    # Move to a new line

            if [[ $REPLY =~ ^[Yy]$ ]]; then
                SETUP_LETSENCRYPT="yes"

                while true; do
                    # Provide requirements and ask for confirmation
                    echo -e "\n${YELLOW}To successfully obtain Let's Encrypt SSL certificates, please ensure the following:${NC}"
                    echo "1. Your domain name ($HOSTNAME) must be correctly configured to point to your server's public IP address."
                    echo "2. Ports 80 and 443 must be open and accessible from the internet."
                    echo "3. No other service is running on port 80 (e.g., Apache, another Nginx instance)."
                    echo -e "\nPlease make sure these requirements are met before proceeding."

                    read -p "Have you completed these steps? (y/n): " -n 1 -r
                    echo    # Move to a new line

                    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                        echo -e "${RED}Please complete the required steps before proceeding.${NC}"
                        read -p "Would you like to skip Let's Encrypt setup? (y/n): " -n 1 -r
                        echo    # Move to a new line
                        if [[ $REPLY =~ ^[Yy]$ ]]; then
                            SETUP_LETSENCRYPT="no"
                            break
                        else
                            continue
                        fi
                    fi

                    # Prompt for email address for Let's Encrypt
                    read -p "Please enter your email address for Let's Encrypt notifications: " LETSENCRYPT_EMAIL

                    # Stop Nginx container before running certbot
                    echo -e "\n${BLUE}Stopping Nginx container to set up Let's Encrypt...${NC}"
                    docker-compose stop reverse-proxy

                    # Obtain SSL certificate using certbot
                    echo -e "${BLUE}Obtaining SSL certificate for $HOSTNAME...${NC}"
                    if certbot certonly --standalone -d "$HOSTNAME" --non-interactive --agree-tos --email "$LETSENCRYPT_EMAIL"; then
                        echo -e "${GREEN}SSL certificate obtained successfully.${NC}"
                        break
                    else
                        echo -e "${RED}Failed to obtain SSL certificate. Please check the requirements and try again.${NC}"
                        read -p "Would you like to try setting up Let's Encrypt again? (y/n): " -n 1 -r
                        echo    # Move to a new line
                        if [[ $REPLY =~ ^[Nn]$ ]]; then
                            SETUP_LETSENCRYPT="no"
                            break
                        else
                            continue
                        fi
                    fi
                done

                if [[ $SETUP_LETSENCRYPT == "yes" ]]; then
                    # Copy the certificates to the Nginx certs directory
                    echo -e "${BLUE}Copying SSL certificates to Nginx certs directory...${NC}"
                    cp /etc/letsencrypt/live/"$HOSTNAME"/fullchain.pem "$NGINX_CERTS_DIR/fullchain.pem"
                    cp /etc/letsencrypt/live/"$HOSTNAME"/privkey.pem "$NGINX_CERTS_DIR/privkey.pem"

                    # Modify Nginx configuration to use SSL
                    echo -e "${BLUE}Updating Nginx configuration for SSL...${NC}"
                    cat <<EOF > "$NGINX_CONF_DIR/default.conf"
server {
    listen 80;
    server_name $HOSTNAME;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name $HOSTNAME;

    ssl_certificate /etc/nginx/certs/fullchain.pem;
    ssl_certificate_key /etc/nginx/certs/privkey.pem;

    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;

    location / {
        proxy_pass http://content-server:4161;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_ssl_certificate /etc/nginx/certs/client.crt;
        proxy_ssl_certificate_key /etc/nginx/certs/client.key;
        proxy_ssl_trusted_certificate /etc/nginx/certs/chia_ca.crt;
        proxy_ssl_verify off;
    }
}
EOF

    # Create server configuration with proxy_pass and header
    echo -e "\e[34mCreating server configuration...\e[0m"
    rm -f "$BASE_DIR/.nginx/conf.d/encoded.conf"
    cat <<'EOF' > "$BASE_DIR/.nginx/conf.d/encoded.conf"
server {
    listen 80;
    server_name "~^(?<encodedId>[0-9a-z]+)\.dig\.host$" ;

    location / {
        access_by_lua_block {
            ngx.log(ngx.ERR, "Processing request for encodedId: ", ngx.var.encodedId)
            
            local subdomain_decoder = require "subdomain_decoder"
            local decoded, err = subdomain_decoder.decode(ngx.var.encodedId)
            
            if err then
                ngx.log(ngx.ERR, "Decoding error: ", err)
                ngx.status = 400
                ngx.say("<h1>Error</h1><p>Invalid subdomain format: " .. err .. "</p>")
                ngx.exit(ngx.HTTP_BAD_REQUEST)
            end

            -- Set Nginx variables for proxy_pass
            ngx.var.chain = decoded.chain
            ngx.var.storeId = decoded.storeId
        }

        # Add custom header
        proxy_set_header x-webapp true;

        # Proxy pass to the content server with dynamic URL
        proxy_pass http://content-server:4161:/urn:dig:$chain:$storeId$request_uri;
    }
}
EOF

                    echo -e "${GREEN}Nginx configuration updated for SSL.${NC}"

                    # Start Nginx container
                    echo -e "${BLUE}Starting Nginx container...${NC}"
                    $DOCKER_COMPOSE_CMD up -d reverse-proxy

                    # Ask if the user wants to set up auto-renewal
                    echo -e "\n${BLUE}Would you like to set up automatic certificate renewal for Let's Encrypt?${NC}"
                    read -p "(y/n): " -n 1 -r
                    echo    # Move to a new line

                    if [[ $REPLY =~ ^[Yy]$ ]]; then
                        # Set up cron job for certificate renewal
                        echo -e "${BLUE}Setting up cron job for certificate renewal...${NC}"

                        # Check if crontab exists for the user, create if not
                        if ! crontab -l >/dev/null 2>&1; then
                            echo "" | crontab -
                        fi

                        (crontab -l 2>/dev/null; echo "0 0 * * * certbot renew --pre-hook 'docker-compose stop reverse-proxy' --post-hook 'docker-compose up -d reverse-proxy'") | crontab -

                        echo -e "${GREEN}Automatic certificate renewal has been set up.${NC}"
                    else
                        echo -e "${YELLOW}Skipping automatic certificate renewal setup.${NC}"
                    fi

                    echo -e "${GREEN}Let's Encrypt SSL setup complete.${NC}"
                fi
            else
                SETUP_LETSENCRYPT="no"
            fi
        fi
    fi
}
