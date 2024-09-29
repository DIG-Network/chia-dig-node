# DIG Node Setup Script for Windows
# This script automates the installation and configuration of a DIG Node on Windows

# Function to output colored text
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    else {
        $input | Write-Output
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

# Function to create Windows Service using NSSM
function Create-DIGNodeService {
    $currentDir = Get-Location
    $defaultDir = $currentDir.Path
    $defaultDockerPath = "C:\Program Files\Docker\Docker\resources\bin\docker.exe"
    
    Write-ColorOutput Cyan "Creating Windows Service for DIG Node..."
    $createService = Read-Host "Do you want to create and enable the Windows service for DIG Node? (y/n)"
    
    if ($createService -eq "y") {
        $serviceDir = Read-Host "Enter the directory for the DIG Node service (default: $defaultDir)"
        if ([string]::IsNullOrWhiteSpace($serviceDir)) {
            $serviceDir = $defaultDir
        }

        # Verify the directory exists
        if (-not (Test-Path $serviceDir)) {
            Write-ColorOutput Red "The specified directory does not exist. Please check the path and try again."
            return
        }

        $dockerPath = Read-Host "Enter the path to the Docker executable (default: $defaultDockerPath)"
        if ([string]::IsNullOrWhiteSpace($dockerPath)) {
            $dockerPath = $defaultDockerPath
        }

        # Verify the Docker executable exists
        if (-not (Test-Path $dockerPath)) {
            Write-ColorOutput Red "The specified Docker executable does not exist. Please check the path and try again."
            return
        }

        # Install the service
        Write-ColorOutput Cyan "Installing DIGNode service..."
        nssm install DIGNode $dockerPath
        nssm set DIGNode AppDirectory $serviceDir
        nssm set DIGNode AppParameters "compose up"

        # Set service description
        nssm set DIGNode Description "DIG Node Docker Compose Service"

        # Set service to auto-start
        nssm set DIGNode Start SERVICE_AUTO_START

        # Start the service
        Write-ColorOutput Cyan "Starting DIGNode service..."
        Start-Service DIGNode

        # Check service status
        $service = Get-Service DIGNode
        if ($service.Status -eq "Running") {
            Write-ColorOutput Green "DIGNode service installed and started successfully."
        } else {
            Write-ColorOutput Red "Failed to start DIGNode service. Please check the Windows Event Viewer for more details."
        }

        # Display service status
        Write-ColorOutput Cyan "Service Status:"
        Get-Service DIGNode | Format-List Name, Status, StartType
    } else {
        Write-ColorOutput Yellow "Skipping Windows service creation. You can manually start the DIG Node using 'docker-compose up -d' in the appropriate directory."
    }
}

# Function to set up automatic updates
function Setup-AutoUpdate {
    Write-ColorOutput Yellow "Would you like to automatically keep your DIG Node updated?"
    Write-Host "This will create a scheduled task to run 'upgrade-node.ps1' once a day."
    $response = Read-Host "Do you want to set up automatic updates? (y/n)"

    if ($response -eq "y" -or $response -eq "Y") {
        Write-ColorOutput Green "Setting up automatic updates..."

        # Ensure the upgrade-node.ps1 script exists
        $upgradeScriptPath = Join-Path $PSScriptRoot "upgrade-node.ps1"
        if (-not (Test-Path $upgradeScriptPath)) {
            Write-ColorOutput Red "Error: upgrade-node.ps1 script not found in the current directory."
            return
        }

        # Create a scheduled task to run the upgrade-node.ps1 script once a day
        $taskName = "DIG Node Auto Update"
        $taskDescription = "Automatically update DIG Node daily"
        $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -File `"$upgradeScriptPath`""
        $trigger = New-ScheduledTaskTrigger -Daily -At 12am
        $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

        Register-ScheduledTask -TaskName $taskName -Description $taskDescription -Action $action -Trigger $trigger -Principal $principal -Force

        Write-ColorOutput Green "Automatic updates have been set up successfully!"
        Write-Host "Your DIG Node will be updated daily at midnight."
    }
    else {
        Write-ColorOutput Yellow "Automatic updates skipped."
    }
}

# Function to set up Nginx reverse proxy
function Setup-NginxReverseProxy {
    if ($INCLUDE_NGINX -eq "y") {
        Write-ColorOutput Cyan "Setting up Nginx reverse-proxy..."

        # Nginx directories
        $NGINX_CONF_DIR = "$env:USERPROFILE\.dig\remote\.nginx\conf.d"
        $NGINX_CERTS_DIR = "$env:USERPROFILE\.dig\remote\.nginx\certs"

        # Create directories
        New-Item -ItemType Directory -Force -Path $NGINX_CONF_DIR | Out-Null
        New-Item -ItemType Directory -Force -Path $NGINX_CERTS_DIR | Out-Null

        # Generate TLS client certificate and key
        Write-ColorOutput Blue "Generating TLS client certificate and key for Nginx..."

        # Paths to the CA certificate and key (assumed to be in .\ssl\ca\)
        $CA_CERT = ".\ssl\ca\chia_ca.crt"
        $CA_KEY = ".\ssl\ca\chia_ca.key"

        # Check if CA certificate and key exist
        if (-not (Test-Path $CA_CERT) -or -not (Test-Path $CA_KEY)) {
            Write-ColorOutput Red "Error: CA certificate or key not found in .\ssl\ca\"
            Write-Host "Please ensure chia_ca.crt and chia_ca.key are present in .\ssl\ca\ directory."
            exit 1
        }

        # Generate client key and certificate
        & openssl genrsa -out "$NGINX_CERTS_DIR\client.key" 2048
        & openssl req -new -key "$NGINX_CERTS_DIR\client.key" -subj "/CN=dig-nginx-client" -out "$NGINX_CERTS_DIR\client.csr"
        & openssl x509 -req -in "$NGINX_CERTS_DIR\client.csr" -CA $CA_CERT -CAkey $CA_KEY `
            -CAcreateserial -out "$NGINX_CERTS_DIR\client.crt" -days 365 -sha256

        # Clean up CSR
        Remove-Item "$NGINX_CERTS_DIR\client.csr"
        Copy-Item $CA_CERT "$NGINX_CERTS_DIR\chia_ca.crt"

        Write-ColorOutput Green "TLS client certificate and key generated."

        # Prompt for hostname
        Write-ColorOutput Blue "Would you like to set a hostname for your server?"
        $USE_HOSTNAME = Read-Host "(y/n)"

        if ($USE_HOSTNAME -eq "y") {
            $HOSTNAME = Read-Host "Please enter your hostname (e.g., example.com)"
            $SERVER_NAME = $HOSTNAME
            $LISTEN_DIRECTIVE = "listen 80;"
        } else {
            $SERVER_NAME = "_"
            $LISTEN_DIRECTIVE = "listen 80 default_server;"
        }

        # Generate Nginx configuration
        $NGINX_CONF = @"
server {
    $LISTEN_DIRECTIVE
    server_name $SERVER_NAME;

    location / {
        proxy_pass http://content-server:4161;
        proxy_set_header Host `$host;
        proxy_set_header X-Real-IP `$remote_addr;
        proxy_ssl_certificate /etc/nginx/certs/client.crt;
        proxy_ssl_certificate_key /etc/nginx/certs/client.key;
        proxy_ssl_trusted_certificate /etc/nginx/certs/chia_ca.crt;
        proxy_ssl_verify off;
    }
}
"@

        Set-Content -Path "$NGINX_CONF_DIR\default.conf" -Value $NGINX_CONF
        Write-ColorOutput Green "Nginx configuration has been set up at $NGINX_CONF_DIR\default.conf"

        if ($USE_HOSTNAME -eq "y") {
            Write-ColorOutput Blue "Would you like to set up SSL certificates for your hostname?"
            $SETUP_SSL = Read-Host "(y/n)"

            if ($SETUP_SSL -eq "y") {
                Write-ColorOutput Yellow "To successfully set up SSL certificates, please ensure the following:"
                Write-Host "1. Your domain name ($HOSTNAME) must be correctly configured to point to your server's public IP address."
                Write-Host "2. Ports 80 and 443 must be open and accessible from the internet."
                Write-Host "3. No other service is running on port 80 (e.g., IIS, another Nginx instance)."
                Write-Host "`nPlease make sure these requirements are met before proceeding."

                $PROCEED = Read-Host "Have you completed these steps? (y/n)"

                if ($PROCEED -eq "y") {
                    # Here you would typically use a tool like Certbot to obtain SSL certificates
                    # However, Windows doesn't have a direct equivalent, so you might need to use
                    # a different approach or instruct the user to obtain certificates manually

                    Write-ColorOutput Yellow "Automatic SSL certificate setup is not available in this script for Windows."
                    Write-Host "Please obtain SSL certificates manually and place them in $NGINX_CERTS_DIR"
                    Write-Host "Then, update the Nginx configuration accordingly."

                    # If certificates are obtained, update Nginx configuration
                    $UPDATE_CONF = Read-Host "Have you obtained SSL certificates and placed them in the correct directory? (y/n)"
                    if ($UPDATE_CONF -eq "y") {
                        $NGINX_SSL_CONF = @"
server {
    listen 80;
    server_name $HOSTNAME;
    return 301 https://`$host`$request_uri;
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
        proxy_set_header Host `$host;
        proxy_set_header X-Real-IP `$remote_addr;
        proxy_ssl_certificate /etc/nginx/certs/client.crt;
        proxy_ssl_certificate_key /etc/nginx/certs/client.key;
        proxy_ssl_trusted_certificate /etc/nginx/certs/chia_ca.crt;
        proxy_ssl_verify off;
    }
}
"@
                        Set-Content -Path "$NGINX_CONF_DIR\default.conf" -Value $NGINX_SSL_CONF
                        Write-ColorOutput Green "Nginx configuration updated for SSL."
                    }
                }
            }
        }
    }
}

# Function to open ports in Windows Firewall
function Open-Ports {
    param (
        [array]$Ports
    )
    
    $portsString = $Ports -join ","
    Write-ColorOutput Yellow "Opening ports $portsString in Windows Firewall..."
    New-NetFirewallRule -DisplayName "DIG Node Ports" -Direction Inbound -Protocol TCP -LocalPort $Ports -Action Allow
    Write-ColorOutput Green "Ports opened successfully in Windows Firewall."
}

# Function to ask about opening ports
function Ask-OpenPorts {
    Write-ColorOutput Blue "This setup uses the following ports:"
    Write-Host " - Port 22: SSH (for remote access)"
    Write-Host " - Port 4159: Propagation Server"
    Write-Host " - Port 4160: Incentive Server"
    Write-Host " - Port 4161: Content Server"
    Write-Host " - Port 8444: Chia FullNode"
    Write-Host " - Port 8555: Chia FullNode"

    if ($INCLUDE_NGINX -eq "yes") {
        Write-Host " - Port 80: Reverse Proxy (HTTP)"
        Write-Host " - Port 443: Reverse Proxy (HTTPS)"
        $Ports = @(22, 80, 443, 4159, 4160, 4161, 8444, 8555)
    } else {
        $Ports = @(22, 4159, 4160, 4161, 8444, 8555)
    }

    Write-Host ""
    Write-Host "This install script can automatically attempt to configure your ports."
    Write-Host "If you do not like this port configuration, you can input No and configure the ports manually."
    $reply = Read-Host "Do you want to open these ports ($($Ports -join ', ')) using Windows Firewall? (y/n)"

    if ($reply -match "^[Yy]$") {
        Open-Ports -Ports $Ports
    } else {
        Write-ColorOutput Yellow "Skipping Windows Firewall port configuration."
    }
}

# Function to ask about including Nginx reverse proxy
function Ask-IncludeNginx {
    Write-Host "We need to set up a reverse proxy to your DIG Node's content server."
    Write-Host "If you already have a reverse proxy setup, such as IIS or another Nginx instance,"
    Write-Host "you should skip this and manually set up port 80 and port 443 to map to your DIG Node's content server at port 4161."
    Write-ColorOutput Blue "Would you like to include the Nginx reverse-proxy setup?"
    $reply = Read-Host "(y/n)"

    if ($reply -match "^[Yy]$") {
        $script:INCLUDE_NGINX = "yes"
        $nginxInstalled = Check-Software "Nginx" "nginx -v"
        if (-not $nginxInstalled) {
            Write-ColorOutput Red "Nginx is not installed. Please install Nginx and try again."
            exit 1
        }
    } else {
        $script:INCLUDE_NGINX = "no"
        Write-ColorOutput Yellow "Warning: You have chosen not to include the Nginx reverse-proxy setup."
        Write-Host "Unless you plan on exposing port 80/443 in another way, your DIG Node's content server will be inaccessible to the browser."
    }
}

# Function to ask about UPnP port forwarding
function Ask-UPnPPorts {
    Write-Host "In addition to the Windows Firewall, you may need to open ports on your router."
    Write-Host "Some routers can automatically open ports using UPnP."
    Write-Host "If you do not like this port configuration, you can input No and configure the ports manually."
    Write-ColorOutput Blue "Would you like to try to automatically set up port forwarding on your router using UPnP?"
    $reply = Read-Host "(y/n)"

    if ($reply -match "^[Yy]$") {
        Open-PortsUPnP
    } else {
        Write-ColorOutput Yellow "Skipping automatic router port forwarding."
    }
}

# Function to open ports using UPnP
function Open-PortsUPnP {
    Write-ColorOutput Blue "Attempting to open ports on the router using UPnP..."

    # Get the local IP address
    $localIP = (Get-NetIPAddress | Where-Object { $_.AddressFamily -eq 'IPv4' -and $_.PrefixOrigin -eq 'Dhcp' }).IPAddress
    if (-not $localIP) {
        Write-ColorOutput Red "Could not determine local IP address."
        return
    }
    Write-ColorOutput Green "Local IP address detected: $localIP"

    # Ports to open
    $ports = if ($INCLUDE_NGINX -eq "yes") { @(22, 80, 443, 4159, 4160, 4161, 8444, 8555) } else { @(22, 4159, 4160, 4161, 8444, 8555) }

    # Create UPnP object
    $natUPnP = New-Object -ComObject HNetCfg.NATUPnP

    # Get the UPnP NAT mapping collection
    $mappings = $natUPnP.StaticPortMappingCollection

    if ($mappings -eq $null) {
        Write-ColorOutput Red "UPnP is not available on your router or is not enabled."
        return
    }

    # Open each port using UPnP
    foreach ($port in $ports) {
        Write-ColorOutput Yellow "Attempting to open port $port via UPnP..."
        try {
            $mappings.Add($port, "TCP", $port, $localIP, $true, "DIG Node Port $port")
            Write-ColorOutput Green "Successfully opened port $port."
        } catch {
            Write-ColorOutput Red "Failed to open port ${port}: $_"
        }
    }

    Write-ColorOutput Green "UPnP port forwarding attempted."
    Write-ColorOutput Yellow "Please verify that the ports have been opened on your router."
}

# Ensure the script is run as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
    exit 1
}

# Display script header
Write-ColorOutput Green @"
###############################################################################
#               DIG Node Setup Script for Windows                             #
###############################################################################
"@

# Function to check if software is installed
function Check-Software {
    param (
        [string]$Name,
        [string]$Command
    )
    
    try {
        $null = Invoke-Expression $Command 2>&1
        return $true
    }
    catch {
        return $false
    }
}

# Check for required software
Write-ColorOutput Cyan "Checking for required software..."
$dockerInstalled = Check-Software "Docker" "docker --version"
$nssmInstalled = Check-Software "NSSM" "nssm version"

if (-not $dockerInstalled -or -not $nssmInstalled) {
    if (-not $dockerInstalled) {
        Write-ColorOutput Red "Docker is not installed. Please install Docker and try again."
    }
    if (-not $nssmInstalled) {
        Write-ColorOutput Red "NSSM (Non-Sucking Service Manager) is not installed. Please install NSSM and try again."
    }
    exit 1
}

# Stop existing DIG Node service if running
Write-ColorOutput Cyan "Stopping existing DIG Node service if running..."
if (Get-Service DIGNode -ErrorAction SilentlyContinue) {
    Stop-Service DIGNode
    Write-ColorOutput Green "Existing DIG Node service stopped."
} else {
    Write-ColorOutput Yellow "No existing DIG Node service found."
}

# Generate credentials
Write-ColorOutput Cyan "Generating high-entropy credentials..."
$digUsername = -join ((65..90) + (97..122) | Get-Random -Count 12 | % {[char]$_})
$digPassword = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 16 | % {[char]$_})
Write-ColorOutput Green "Credentials generated successfully."

# Collect user inputs
Write-ColorOutput Cyan "Collecting user inputs..."
$trustedFullNode = Read-Host "Enter the IP address of your trusted full node (optional, ENTER to use localnode)"
$publicIP = Read-Host "Enter your public IP address (optional)"
$mercenaryMode = Read-Host "Enable Mercenary Mode (auto-mirror stores based on profitability)? (y/N)"
$mercenaryMode = if ($mercenaryMode -eq "y" -or $mercenaryMode -eq "Y") { "y" } else { "n" }

$diskSpaceLimit = Read-Host "Enter disk space limit in GB (default: 1024)"

if ([string]::IsNullOrWhiteSpace($diskSpaceLimit)) {
    $diskSpaceLimit = 1024
}
$diskSpaceLimitBytes = [int64]$diskSpaceLimit * 1GB

# Create docker-compose.yml
Write-ColorOutput Cyan "Creating docker-compose.yml file..."
$dockerComposeContent = @"
version: '3.8'

services:
  propagation-server:
    image: dignetwork/dig-propagation-server:latest-alpha
    ports:
      - "4159:4159"
    volumes:
      - ${env:USERPROFILE}\.dig\remote:/.dig
    environment:
      - DIG_USERNAME=$digUsername
      - DIG_PASSWORD=$digPassword
      - DIG_FOLDER_PATH=/.dig
      - PORT=4159
      - REMOTE_NODE=1
    restart: always

  content-server:
    image: dignetwork/dig-content-server:latest-alpha
    ports:
      - "4161:4161"
    volumes:
      - ${env:USERPROFILE}\.dig\remote:/.dig
    environment:
      - DIG_FOLDER_PATH=/.dig
      - PORT=4161
      - REMOTE_NODE=1
    restart: always

  incentive-server:
    image: dignetwork/dig-incentive-server:latest-alpha
    ports:
      - "4160:4160"
    volumes:
      - ${env:USERPROFILE}\.dig\remote:/.dig
    environment:
      - DIG_USERNAME=$digUsername
      - DIG_PASSWORD=$digPassword
      - DIG_FOLDER_PATH=/.dig
      - PORT=4160
      - REMOTE_NODE=1
      - PUBLIC_IP=$publicIP
      - DISK_SPACE_LIMIT_BYTES=$diskSpaceLimitBytes
"@

if ($trustedFullNode) {
    $dockerComposeContent += @"

      - TRUSTED_FULL_NODE=$trustedFullNode
"@
}

if ($mercenaryMode -eq "y") {
    $dockerComposeContent += @"

      - MERCENARY_MODE=1
"@
}

$dockerComposeContent += @"

    restart: always
"@

# Save docker-compose.yml
$dockerComposeContent | Out-File -FilePath "docker-compose.yml" -Encoding utf8
Write-ColorOutput Green "docker-compose.yml file created successfully."

# Ask if the user wants to include Nginx reverse proxy
Ask-IncludeNginx

# Call the function to ask about opening ports
Ask-OpenPorts

# Ask about UPnP port forwarding
Ask-UPnPPorts

# Setup Nginx reverse proxy if chosen
if ($INCLUDE_NGINX -eq "yes") {
    Setup-NginxReverseProxy
}

# Pull latest Docker images
Write-ColorOutput Cyan "Pulling latest Docker images..."
docker-compose pull
Write-ColorOutput Green "Docker images pulled successfully."

# Start DIG Node services
Write-ColorOutput Cyan "Starting DIG Node services..."
docker-compose up -d
Write-ColorOutput Green "DIG Node services started successfully."


# Call the function to create the service
Create-DIGNodeService

# Set up automatic updates
Setup-AutoUpdate

Write-ColorOutput Green "DIG Node setup complete!"
Write-ColorOutput Cyan "Your DIG_USERNAME is: $digUsername"
Write-ColorOutput Cyan "Your DIG_PASSWORD is: $digPassword"
Write-ColorOutput Yellow "Please save these credentials in a secure location."