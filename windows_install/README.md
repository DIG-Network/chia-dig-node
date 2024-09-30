# DIG Node Setup for Windows

This folder contains scripts and instructions for setting up a DIG Node on Windows systems.

## Contents

1. `install.ps1`: PowerShell script for automated DIG Node setup
2. `upgrade-node.ps1`: PowerShell script for updating the DIG Node
3. `manual-setup-windows.md`: Step-by-step manual setup instructions

## Getting Started

You can set up the DIG Node on your Windows system using one of the following methods:

### Option 1: Cloning the Repository

1. Open PowerShell as Administrator.
2. Clone the repository:
   ```
   git clone https://github.com/DIG-Network/chia-dig-node.git
   ```
3. Navigate to the Windows installation directory:
   ```
   cd chia-dig-node/windows_install
   ```

4. Copy your `chia_ca.crt` and `chia_ca.key` files to `windows_install/ssl/ca/` directory. These files are found in your `.chia/mainnet/config/ssl/ca` directory after you have generated a wallet.

### Option 2: Downloading Individual Files

If you prefer not to clone the entire repository, you can download the necessary files individually:

1. Download the following files from the GitHub repository:
   - `install.ps1`
   - `upgrade-node.ps1`
2. Save these files in a new folder on your Windows system.
3. Create the `ssl/ca` directories and copy your `chia_ca.crt` and `chia_ca.key` files to it. These files are found in your `.chia/mainnet/config/ssl/ca` directory after you have generated a wallet.

## Automated Setup

To use the automated setup script:

1. Ensure you have met all prerequisites (see below).
2. Open PowerShell as Administrator and navigate to the directory containing the scripts.
3. Run the installation script:
   ```
   .\install.ps1
   ```
4. Follow the on-screen prompts to complete the setup.

## Prerequisites

Before running the setup script, ensure that your Windows system meets the following requirements:

1. **Windows 10** or **Windows 11** (64-bit)
2. **Administrator access** to your Windows machine
3. The following **software** is installed:
   - Docker Desktop for Windows
   - NSSM (Non-Sucking Service Manager)
4. (Optional) **Reverse Proxy** requirements:
   - Internet Information Services (IIS) **OR** Nginx (choose one)
   - OpenSSL (for certificate generation)

### Installing Prerequisites

#### Docker Desktop for Windows

1. Visit the [Docker Desktop for Windows](https://www.docker.com/products/docker-desktop) download page.
2. Click "Download for Windows" and run the installer.
3. Follow the installation wizard, ensuring that "Use WSL 2 instead of Hyper-V" is selected if prompted.
4. After installation, restart your computer.

#### NSSM (Non-Sucking Service Manager)

1. Download NSSM from [nssm.cc](https://nssm.cc/download).
2. Extract the zip file and copy `nssm.exe` from the appropriate folder (32-bit or 64-bit) to `C:\Windows\System32`.

#### Optional: Reverse Proxy Setup

A reverse proxy is necessary for the DIG Node setup to securely expose your content server to the internet, this step is optional.
You can choose between Internet Information Services (IIS) and Nginx for your reverse proxy setup. Microsoft IIS is native to Windows whereas Nginx is a popular lightweight cross-platform option. Install one of them based on your preference.

##### Option 1: Internet Information Services (IIS)

1. Open the Control Panel and go to "Programs and Features".
2. Click on "Turn Windows features on or off".
3. Check the box next to "Internet Information Services" and click OK.
4. Wait for the installation to complete and restart your computer if prompted.

After installing IIS, you'll need to install the URL Rewrite Module:

1. Download the URL Rewrite Module from the [official Microsoft IIS site](https://www.iis.net/downloads/microsoft/url-rewrite).
2. Run the installer and follow the prompts to complete the installation.

##### Option 2: Nginx

1. Download Nginx for Windows from the [official Nginx website](http://nginx.org/en/download.html).
2. Extract the zip file to a location of your choice (e.g., `C:\nginx`).
3. Add the Nginx directory to your system's PATH environment variable.

#### OpenSSL (for certificate generation)

If you plan to use SSL/TLS certificates:

1. Download the OpenSSL installer (Light version) for Windows from a trusted source like [Shining Light Productions](https://slproweb.com/products/Win32OpenSSL.html).
2. Run the installer and follow the prompts. Choose to copy OpenSSL DLLs to the OpenSSL binaries directory.
3. Add the OpenSSL bin directory (e.g., `C:\Program Files\OpenSSL-Win64\bin`) to your system's PATH environment variable.

After installing these prerequisites, you'll be ready to run the DIG Node setup script, which will guide you through the process of setting up your reverse proxy and other components.

## Manual Setup

If you prefer to set up your DIG Node manually or encounter issues with the automated script, please refer to the `manual-setup-windows.md` file for step-by-step instructions.

## Troubleshooting

If you encounter any issues during the setup process, please check the following:

1. Ensure all prerequisites are correctly installed.
2. Check that Docker Desktop is running.
3. Verify that you're running the script with Administrator privileges.
4. Check the Windows Event Viewer for any error messages related to the DIG Node service.

If problems persist, please contact [@digdotnet](https://x.com/digdotnet) for support.

## License

This project is licensed under the MIT License. See the [LICENSE](../LICENSE) file in the parent directory for details.

---

**Disclaimer**: These scripts are provided as-is without any warranty. Use them at your own risk. Always review scripts and understand their functionality before executing them on your system.