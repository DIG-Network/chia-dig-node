#!/usr/bin/env bash

nginx_setup() {
    USER_HOME=$(eval echo ~${SUDO_USER})
    if [[ $INCLUDE_NGINX == "yes" ]]; then
        echo -e "${BLUE}Setting up Nginx reverse-proxy...${NC}"

        # Nginx directories
        NGINX_CONF_DIR="$USER_HOME/.dig/remote/.nginx/conf.d"
        NGINX_CERTS_DIR="$USER_HOME/.dig/remote/.nginx/certs"
        NGINX_MAIN_CONF="$USER_HOME/.dig/remote/.nginx/nginx.conf"

        # Create directories
        mkdir -p "$NGINX_CONF_DIR"
        mkdir -p "$NGINX_CERTS_DIR"

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

        # Generate main Nginx configuration
        echo -e "${BLUE}Writing main Nginx configuration file...${NC}"
        cat <<EOF > "$NGINX_MAIN_CONF"
worker_processes auto;

events {
    worker_connections 1024;
}

http {
    lua_shared_dict base32_cache 10m;

    include /etc/nginx/conf.d/*.conf;

    sendfile        on;
    keepalive_timeout  65;
}
EOF
        echo -e "${GREEN}Main Nginx configuration written to $NGINX_MAIN_CONF${NC}"

        # Prompt for hostname
        echo -e "\n${BLUE}Would you like to set a hostname for your server?${NC}"
        read -p "(y/n): " -n 1 -r
        echo    # Move to a new line

        if [[ $REPLY =~ ^[Yy]$ ]]; then
            read -p "Please enter your hostname (e.g., example.com): " HOSTNAME
            USE_HOSTNAME="yes"
        else
            USE_HOSTNAME="no"
            HOSTNAME="_"
        fi

        # Generate server block configurations
        echo -e "${BLUE}Writing server block configurations...${NC}"

        if [[ $USE_HOSTNAME == "yes" ]]; then
            # Redirect HTTP to HTTPS
            cat <<EOF > "$NGINX_CONF_DIR/redirect.conf"
server {
    listen 80;
    server_name $HOSTNAME;
    return 301 https://\$host\$request_uri;
}
EOF

            # HTTPS server block for main hostname (initially with placeholder certs)
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
        proxy_ssl_certificate /etc/nginx/certs/client.crt;
        proxy_ssl_certificate_key /etc/nginx/certs/client.key;
        proxy_ssl_trusted_certificate /etc/nginx/certs/chia_ca.crt;
        proxy_ssl_verify off;
    }
}
EOF

            # Server block for regex-based hostname handling
            cat <<EOF > "$NGINX_CONF_DIR/regex.conf"
server {
    listen 443 ssl;
    server_name ~^(?<chainname>[^.]+)\.(?<storeidBase32>[^.]+)(?:\.(?<rootBase32>[^.]+))?\.${HOSTNAME}$;

    ssl_certificate /etc/nginx/certs/fullchain.pem;
    ssl_certificate_key /etc/nginx/certs/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location / {
        set \$storeidHex '';
        set \$rootHex '';

        # Convert base32 to base16 using Lua
        access_by_lua_block {
            local base32_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
            local function base32_to_hex(base32)
                local bit = require("bit")
                local result = {}
                local buffer = 0
                local bits_left = 0

                for char in base32:gmatch(".") do
                    local value = base32_chars:find(char:upper(), 1, true)
                    if not value then
                        ngx.log(ngx.ERR, "Invalid Base32 character: ", char)
                        return nil
                    end
                    value = value - 1 -- Convert to 0-based index

                    buffer = bit.bor(bit.lshift(buffer, 5), value)
                    bits_left = bits_left + 5

                    while bits_left >= 4 do
                        bits_left = bits_left - 4
                        local hex_digit = bit.band(bit.rshift(buffer, bits_left), 0xF)
                        table.insert(result, string.format("%X", hex_digit))
                    end
                end

                return table.concat(result)
            end

            local storeidBase32 = ngx.var.storeidBase32
            local rootBase32 = ngx.var.rootBase32

            ngx.var.storeidHex = base32_to_hex(storeidBase32)
            ngx.var.rootHex = rootBase32 and base32_to_hex(rootBase32) or nil

            if not ngx.var.storeidHex or (rootBase32 and not ngx.var.rootHex) then
                ngx.log(ngx.ERR, "Base32-to-Hex conversion failed")
                ngx.exit(ngx.HTTP_BAD_REQUEST)
            end
        }

        proxy_pass http://content-server:4161/urn:dig:chia:\$chainname:\$storeidHex:\$rootHex\$request_uri;
        proxy_ssl_certificate /etc/nginx/certs/client.crt;
        proxy_ssl_certificate_key /etc/nginx/certs/client.key;
        proxy_ssl_trusted_certificate /etc/nginx/certs/chia_ca.crt;
        proxy_ssl_verify off;
    }
}
EOF

            echo -e "${GREEN}Server block configurations written to $NGINX_CONF_DIR${NC}"

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
                    echo "4. You have access to your DNS provider to add TXT records for DNS-01 challenges."
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

                    # Obtain wildcard SSL certificates using certbot with DNS-01 challenge
                    echo -e "${BLUE}Obtaining wildcard SSL certificates for *.$HOSTNAME, *.*.$HOSTNAME, and *.*.*.$HOSTNAME...${NC}"
                    certbot certonly --manual --preferred-challenges dns \
                        -d "*.$HOSTNAME" -d "*.*.$HOSTNAME" -d "*.*.*.$HOSTNAME" \
                        --agree-tos --no-eff-email --email "$LETSENCRYPT_EMAIL" --manual-public-ip-logging-ok

                    if [[ $? -eq 0 ]]; then
                        echo -e "${GREEN}SSL certificates obtained successfully.${NC}"
                        break
                    else
                        echo -e "${RED}Failed to obtain SSL certificates. Please check the requirements and try again.${NC}"
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

                    # Modify Nginx configurations to use SSL
                    echo -e "${BLUE}Updating Nginx configurations for SSL...${NC}"

                    # Update main server block to use SSL certificates
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
        proxy_ssl_certificate /etc/nginx/certs/client.crt;
        proxy_ssl_certificate_key /etc/nginx/certs/client.key;
        proxy_ssl_trusted_certificate /etc/nginx/certs/chia_ca.crt;
        proxy_ssl_verify off;
    }
}
EOF

                    # Ensure redirect from HTTP to HTTPS
                    cat <<EOF > "$NGINX_CONF_DIR/redirect.conf"
server {
    listen 80;
    server_name $HOSTNAME;
    return 301 https://\$host\$request_uri;
}
EOF

                    echo -e "${GREEN}Nginx configurations updated for SSL.${NC}"

                    # Start Nginx container
                    echo -e "${BLUE}Starting Nginx container...${NC}"
                    docker-compose up -d reverse-proxy

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

                        # Add renewal command to crontab
                        (crontab -l 2>/dev/null; echo "0 0 * * * certbot renew --manual --preferred-challenges dns --deploy-hook 'docker-compose restart reverse-proxy'") | crontab -

                        echo -e "${GREEN}Automatic certificate renewal has been set up.${NC}"
                    else
                        echo -e "${YELLOW}Skipping automatic certificate renewal setup.${NC}"
                    fi

                    echo -e "${GREEN}Let's Encrypt SSL setup complete.${NC}"
                fi
            else
                SETUP_LETSENCRYPT="no"
            fi
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
        proxy_ssl_certificate /etc/nginx/certs/client.crt;
        proxy_ssl_certificate_key /etc/nginx/certs/client.key;
        proxy_ssl_trusted_certificate /etc/nginx/certs/chia_ca.crt;
        proxy_ssl_verify off;
    }
}
EOF

            echo -e "${GREEN}Default Nginx server block written to $NGINX_CONF_DIR/default.conf${NC}"
        fi

        # Restart Docker container to apply changes
        echo -e "${BLUE}Restarting reverse-proxy container...${NC}"
        docker-compose restart reverse-proxy
    fi
}

# Call the function
nginx_setup
