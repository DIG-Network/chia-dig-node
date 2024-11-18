#!/usr/bin/env bash

# Exit on error
set -e

# Function to create directories and files
setup_nginx_decoder() {
    # Set base directory
    BASE_DIR="$HOME/.dig/remote"

    echo -e "\e[34mSetting up Nginx decoder configuration...\e[0m"

    # Create necessary directories (force create if they exist)
    echo -e "\e[34mCleaning up existing configuration...\e[0m"
    rm -rf "$BASE_DIR/.nginx"
    rm -f "$BASE_DIR/docker-compose.yml"
    rm -rf "$BASE_DIR/docker"

    echo -e "\e[34mCreating directory structure...\e[0m"
    mkdir -p "$BASE_DIR/.nginx/"{conf.d,lua,logs}
    mkdir -p "$BASE_DIR/docker"

    # Create Dockerfile
    echo -e "\e[34mCreating Dockerfile...\e[0m"
    cat <<'EOF' > "$BASE_DIR/docker/Dockerfile"
FROM openresty/openresty:alpine-fat

RUN apk add --no-cache git && \
    apk del git

EOF

    # Create Lua decoder
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

    # Create Docker Compose file
    echo -e "\e[34mCreating Docker Compose configuration...\e[0m"
    rm -f "$BASE_DIR/docker-compose.yml"
    cat <<EOF > "$BASE_DIR/docker-compose.yml"
version: '3.8'

services:
  reverse-proxy:
    build:
      context: ./docker
      dockerfile: Dockerfile
    container_name: reverse-proxy
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ${BASE_DIR}/.nginx/conf.d:/etc/nginx/conf.d
      - ${BASE_DIR}/.nginx/nginx.conf:/usr/local/openresty/nginx/conf/nginx.conf
      - ${BASE_DIR}/.nginx/lua:/usr/local/openresty/nginx/lua
      - ${BASE_DIR}/.nginx/logs:/var/log/nginx
    logging:
      options:
        max-size: "10m"
        max-file: "7"
    networks:
      - dig_network
    restart: always

networks:
  dig_network:
    driver: bridge
EOF

    echo -e "\e[32mSetup complete. Files updated in $BASE_DIR\e[0m"
    echo -e "\e[33mTo restart the services, run:\e[0m"
    echo "cd $BASE_DIR && docker-compose down && docker-compose up -d"
    echo -e "\e[33mTo view logs, run:\e[0m"
    echo "tail -f $BASE_DIR/.nginx/logs/error.log  # For error logs"
    echo "tail -f $BASE_DIR/.nginx/logs/access.log # For access logs"
}

# Run the setup
setup_nginx_decoder
