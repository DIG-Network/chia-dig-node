# Upgrade Node Script for Windows

# Variables
$ServiceName = "DIGNode"

# Function to detect the Docker Compose command
function Detect-DockerComposeCmd {
    if (Get-Command docker-compose -ErrorAction SilentlyContinue) {
        return "docker-compose"
    }
    elseif ((docker compose version) -match "Docker Compose") {
        return "docker compose"
    }
    else {
        return $null
    }
}

# Function to write colored output
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

# Check if the script is being run as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-ColorOutput Red "Please run as Administrator"
    exit 1
}

# Detect Docker Compose command
$DockerComposeCmd = Detect-DockerComposeCmd
if (-not $DockerComposeCmd) {
    Write-ColorOutput Red "Docker Compose is not installed. Exiting..."
    exit 1
}

# Stop the service
Write-ColorOutput Cyan "Stopping $ServiceName service..."
Stop-Service $ServiceName -ErrorAction SilentlyContinue
if (-not $?) {
    Write-ColorOutput Red "Failed to stop the service. Exiting..."
    exit 1
}

# Pull the latest Docker images using the detected Docker Compose command
Write-ColorOutput Cyan "Pulling latest Docker images..."
Invoke-Expression "$DockerComposeCmd pull"
if (-not $?) {
    Write-ColorOutput Red "Failed to pull latest Docker images. Exiting..."
    exit 1
}

# Start the service
Write-ColorOutput Cyan "Starting $ServiceName service..."
Start-Service $ServiceName
if (-not $?) {
    Write-ColorOutput Red "Failed to start the service. Exiting..."
    exit 1
}

# Verify the service is running
Write-ColorOutput Cyan "Checking status of $ServiceName service..."
$service = Get-Service $ServiceName
if ($service.Status -eq "Running") {
    Write-ColorOutput Green "$ServiceName is running."
} else {
    Write-ColorOutput Red "$ServiceName is not running. Status: $($service.Status)"
}

Write-ColorOutput Green "Node upgrade complete."