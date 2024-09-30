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

        # Determine the script path
        $scriptPath = if ($PSScriptRoot) {
            $PSScriptRoot
        } elseif ($MyInvocation.MyCommand.Path) {
            Split-Path $MyInvocation.MyCommand.Path
        } else {
            $PWD.Path
        }

        # Ensure the upgrade-node.ps1 script exists
        $upgradeScriptPath = Join-Path $scriptPath "upgrade-node.ps1"
        if (-not (Test-Path $upgradeScriptPath)) {
            Write-ColorOutput Red "Error: upgrade-node.ps1 script not found in the current directory."
            Write-ColorOutput Yellow "Please ensure upgrade-node.ps1 is in the same directory as this script."
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

# Function to ask about opening ports
function Ask-OpenPorts {
    Write-ColorOutput Blue "This setup uses the following ports:"
    Write-Host " - Port 22: SSH (for remote access)"
    Write-Host " - Port 4159: Propagation Server"
    Write-Host " - Port 4160: Incentive Server"
    Write-Host " - Port 4161: Content Server"
    Write-Host " - Port 8444: Chia FullNode"
    Write-Host " - Port 8555: Chia FullNode"

    $Ports = @(22, 4159, 4160, 4161, 8444, 8555)

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

# Function to open ports in Windows Firewall
function Open-Ports {
    param (
        [array]$Ports
    )
    
    $ruleName = "DIG Node Ports"
    $portsString = $Ports -join ","
    
    # Check if the rule already exists
    $existingRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue

    if ($existingRule) {
        Write-ColorOutput Yellow "A firewall rule named '$ruleName' already exists."
        $overwrite = Read-Host "Do you want to overwrite it? (y/n)"
        
        if ($overwrite -match "^[Yy]$") {
            # Remove the existing rule
            Remove-NetFirewallRule -DisplayName $ruleName
            Write-ColorOutput Yellow "Existing rule removed."
        } else {
            Write-ColorOutput Yellow "Keeping existing firewall rule. New rule will not be created."
            return
        }
    }

    Write-ColorOutput Yellow "Opening ports $portsString in Windows Firewall..."
    
    try {
        New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Protocol TCP -LocalPort $Ports -Action Allow -ErrorAction Stop
        Write-ColorOutput Green "Ports opened successfully in Windows Firewall."
    }
    catch {
        Write-ColorOutput Red "Failed to create firewall rule: $_"
        Write-ColorOutput Yellow "You may need to manually configure the Windows Firewall to allow these ports."
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
    $ports = @(22, 4159, 4160, 4161, 8444, 8555)

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

# Function to check if Docker is running
function Is-DockerRunning {
    try {
        $dockerInfo = docker info 2>&1
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

# Check for required software
Write-ColorOutput Cyan "Checking for required software..."
$dockerInstalled = Check-Software "Docker" "docker --version"
$nssmInstalled = Check-Software "NSSM" "nssm version"

$missingRequirements = $false

if (-not $dockerInstalled) {
    Write-ColorOutput Red "Docker is not installed. Please install Docker and try again."
    $missingRequirements = $true
}
elseif (-not (Is-DockerRunning)) {
    Write-ColorOutput Red "Docker is installed but not running. Please start Docker Desktop and try again."
    $missingRequirements = $true
}

if (-not $nssmInstalled) {
    Write-ColorOutput Red "NSSM (Non-Sucking Service Manager) is not installed. Please install NSSM and try again."
    $missingRequirements = $true
}

if ($missingRequirements) {
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

# Call the function to ask about opening ports
Ask-OpenPorts

# Ask about UPnP port forwarding
Ask-UPnPPorts

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