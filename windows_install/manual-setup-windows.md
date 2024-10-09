# DIG Node Manual Setup Instructions for Windows

## Prerequisites

Ensure that your Windows system meets the following prerequisites:
1. **Windows 10** or **Windows 11** (64-bit)
2. **Administrator access** to your Windows machine.
3. The following **software** is installed:
   - Docker Desktop for Windows
   - NSSM (Non-Sucking Service Manager)

For detailed instructions on installing these prerequisites, see the [Installing Windows Prerequisites](#installing-windows-prerequisites) at the end of this document.

---

## Step 1: Start Docker Desktop for Windows

Start Docker Desktop. If it hasn't been installed yet, follow the instructions in the [Installing Windows Prerequisites](#installing-windows-prerequisites) section.

---

## Step 2: Create Docker-Compose Configuration

Create a `docker-compose.yml` file that defines your DIG Node services. This file will configure the propagation server, content server, and incentive server.

1. Open Windows Explorer and navigate to a directory where you want to store your DIG Node files.
2. Right-click in the folder, select "New" > "Text Document", and name it `docker-compose.yml`.
3. Open the file with a text editor (e.g., Notepad++ or Visual Studio Code) and paste the following content:

```yaml
version: '3.8'

services:
  propagation-server:
    image: dignetwork/dig-propagation-server:latest-alpha
    ports:
      - "4159:4159"
    volumes:
      - ${USERPROFILE}\.dig\remote:/.dig
    environment:
      - DIG_USERNAME=your_username
      - DIG_PASSWORD=your_password
      - DIG_FOLDER_PATH=/.dig
      - PORT=4159
      - REMOTE_NODE=1
    restart: always

  content-server:
    image: dignetwork/dig-content-server:latest-alpha
    ports:
      - "4161:4161"
    volumes:
      - ${USERPROFILE}\.dig\remote:/.dig
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
      - ${USERPROFILE}\.dig\remote:/.dig
    environment:
      - DIG_USERNAME=your_username
      - DIG_PASSWORD=your_password
      - DIG_FOLDER_PATH=/.dig
      - PORT=4160
      - REMOTE_NODE=1
      - PUBLIC_IP=your_public_ip
      - DISK_SPACE_LIMIT_BYTES=1099511627776
    restart: always
```

Replace `your_username`, `your_password`, and `your_public_ip` with your actual values.

---

## Step 3: Configure Windows Firewall

To allow incoming connections to your DIG Node, you need to open the necessary ports in Windows Firewall:

1. Open the Windows Start menu and search for "Windows Defender Firewall with Advanced Security".
2. Click on "Inbound Rules" in the left panel.
3. Click "New Rule..." in the right panel.
4. Choose "Port" and click "Next".
5. Select "TCP" and enter the following ports: "4159,4160,4161". Click "Next".
6. Choose "Allow the connection" and click "Next".
7. Select all network types (Domain, Private, and Public) and click "Next".
8. Give the rule a name (e.g., "DIG Node Ports") and click "Finish".

---

## Step 4: Start Your DIG Node

1. Open Powershell or Command Prompt as Administrator.
2. Navigate to the directory containing your `docker-compose.yml` file.
3. Run the following command to start the DIG Node services:

```cmd
docker-compose up -d
```

This will start the three DIG Node services (propagation, content, and incentive servers) in the background.

---

## Step 5: Create a Windows Service for DIG Node

To ensure your DIG Node starts automatically when your Windows machine boots up, you can create a Windows service using NSSM (Non-Sucking Service Manager). While Windows has built-in service creation capabilities, NSSM is preferred for this setup because:

- It provides better handling of Docker commands, which can be tricky to run as a standard Windows service.
- NSSM offers more robust logging and error handling, making it easier to troubleshoot issues.
- It allows for easier management of complex commands and arguments, which is beneficial when working with Docker Compose.
- NSSM provides a simpler interface for creating and managing services compared to native Windows tools.

If NSSM is not installed, follow the instructions in the [Installing Windows Prerequisites](#installing-windows-prerequisites) section.

Here's how to set up the service using NSSM:

1. Open Command Prompt as Administrator and run:

```cmd
nssm install DIGNode
```

2. In the NSSM service installer:
   - Set the "Path" to `C:\Program Files\Docker\Docker\resources\bin\docker.exe`.
   - Set "Startup directory" to the folder containing your `docker-compose.yml` file.
   - Set "Arguments" to `compose up`.
   - Click "Install service".

3. Start the service:

```cmd
nssm start DIGNode
```

Your DIG Node will now start automatically with Windows.

---

## Installing Windows Prerequisites

### Installing Docker Desktop for Windows

1. Visit the [Docker Desktop for Windows](https://www.docker.com/products/docker-desktop) download page.
2. Click "Download for Windows" and run the installer.
3. Follow the installation wizard, ensuring that "Use WSL 2 instead of Hyper-V" is selected if prompted.
4. After installation, restart your computer.


### Install NSSM (Non-Sucking Service Manager):

1. Download NSSM from [nssm.cc](https://nssm.cc/download).
2. Extract the zip file and copy `nssm.exe` from the appropriate folder (32-bit or 64-bit) to `C:\Windows\System32`.