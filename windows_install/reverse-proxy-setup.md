# Reverse Proxy Setup for DIG Node

This guide provides instructions for setting up a reverse proxy for your DIG Node using either Nginx or Internet Information Services (IIS) on Windows. A reverse proxy is recommended to securely expose your DIG Node's content server to the internet.

## Table of Contents

1. [Choosing a Reverse Proxy](#choosing-a-reverse-proxy)
2. [Prerequisites](#prerequisites)
3. [Nginx Setup](#nginx-setup)
4. [IIS Setup](#iis-setup)
5. [Modifying Firewall Rules](#modifying-firewall-rules)
6. [Testing the Reverse Proxy Setup](#testing-the-reverse-proxy-setup)
7. [Troubleshooting](#troubleshooting)

## Choosing a Reverse Proxy

Both Nginx and IIS are capable reverse proxies, but they have different strengths:

- **Nginx**: Lightweight, high-performance, and excellent for static content and as a reverse proxy. It's cross-platform but requires manual installation on Windows.
- **IIS**: Native to Windows and integrates well with Windows authentication. It's already included in Windows but needs to be enabled.

Choose the option that best fits your familiarity and existing infrastructure.

## Prerequisites

### For Nginx:

1. Download Nginx for Windows from the [official Nginx website](http://nginx.org/en/download.html).
2. Extract the zip file to a location of your choice (e.g., `C:\nginx`).
3. Add the Nginx directory to your system's PATH environment variable.

### For IIS:

1. Open the Control Panel and go to "Programs and Features".
2. Click on "Turn Windows features on or off".
3. Check the box next to "Internet Information Services" and click OK.
4. Wait for the installation to complete and restart your computer if prompted.

After installing IIS, you'll need to install the URL Rewrite Module:

1. Download the URL Rewrite Module from the [official Microsoft IIS site](https://www.iis.net/downloads/microsoft/url-rewrite).
2. Run the installer and follow the prompts to complete the installation.

## Nginx Setup

1. Create a new configuration file named `dig-node.conf` in the `conf` directory of your Nginx installation.

2. Add the following content to the file:

   ```nginx
   server {
       listen 80;
       server_name your_domain.com;

       location / {
           proxy_pass http://localhost:4161;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
           proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
           proxy_set_header X-Forwarded-Proto $scheme;
       }
   }
   ```

   Replace `your_domain.com` with your actual domain name or public IP address.

3. Include this configuration in your main `nginx.conf` file by adding the following line in the `http` block:

   ```nginx
   include conf/dig-node.conf;
   ```

4. Test the configuration:

   ```
   nginx -t
   ```

5. If the test is successful, restart Nginx:

   ```
   nginx -s reload
   ```

## IIS Setup

1. Open IIS Manager.

2. Create a new website or use the default website.

3. In the website's configuration, add a new "URL Rewrite" rule:
   - Name: "Reverse Proxy to DIG Node"
   - Pattern: `(.*)`
   - Action: Rewrite
   - Rewrite URL: `http://localhost:4161/{R:1}`

4. Apply the changes.

## Modifying Firewall Rules

The `install.ps1` script creates a firewall rule named "DIG Node Ports". To modify this rule to include ports 80 and 443 for the reverse proxy:

1. Open PowerShell as Administrator.

2. Run the following commands:

   ```powershell
   $ruleName = "DIG Node Ports"
   $existingRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue

   if ($existingRule) {
       $ports = (Get-NetFirewallPortFilter -AssociatedNetFirewallRule $existingRule).LocalPort
       $newPorts = $ports + @(80, 443)
       Set-NetFirewallRule -DisplayName $ruleName -RemoveProperty LocalPort
       Set-NetFirewallRule -DisplayName $ruleName -LocalPort $newPorts
       Write-Host "Firewall rule updated to include ports 80 and 443."
   } else {
       Write-Host "Firewall rule 'DIG Node Ports' not found. Creating new rule..."
       New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Protocol TCP -LocalPort @(22, 80, 443, 4159, 4160, 4161, 8444, 8555) -Action Allow
   }
   ```

This script will either modify the existing rule to include ports 80 and 443 or create a new rule if it doesn't exist.

Remember to also configure your router to forward ports 80 and 443 to your DIG Node server if it's behind a NAT.

## Testing the Reverse Proxy Setup

After completing the setup for either Nginx or IIS, it's important to verify that the reverse proxy is working correctly. Follow these steps to test your configuration:

1. **Ensure your DIG Node is running**: 
   Make sure your DIG Node is up and running on port 4161.

2. **Check local access**:
   Open a web browser on the same machine and navigate to `http://localhost:4161`. You should see the DIG Node content server response.

3. **Test the reverse proxy**:
   - If you're using a domain name, navigate to `http://your_domain.com` in a web browser.
   - If you're using a public IP address, navigate to `http://your_public_ip` in a web browser.

   You should see the same content as you did when accessing `http://localhost:4161`.

4. **Check HTTP headers**:
   To verify that requests are indeed going through the reverse proxy, you can use an online tool like [WebSniffer](http://websniffer.cc/) or use curl in the command line:

   ````
   curl -I http://your_domain.com
   ```

   Look for headers like `X-Forwarded-For` or `X-Real-IP` in the response. These indicate that the request passed through the reverse proxy.

5. **Test different paths**:
   Try accessing various paths on your domain (e.g., `http://your_domain.com/some/path`) to ensure that all requests are correctly forwarded to your DIG Node.

6. **Check error scenarios**:
   Stop your DIG Node service and try accessing your domain again. You should see an error page served by your reverse proxy, not a connection timeout.

7. **Firewall test**:
   From a different network (not your local network), try accessing your domain or public IP. This will confirm that your firewall settings are correct and allowing incoming traffic.

If all these tests pass, your reverse proxy is set up correctly. If you encounter any issues, double-check your configuration files and firewall settings.

## Troubleshooting

If you're experiencing issues with your reverse proxy setup, try the following:

1. **Check logs**:
   - For Nginx: Look in the error.log file, typically found in the `logs` directory of your Nginx installation.
   - For IIS: Check the IIS logs in `C:\inetpub\logs\LogFiles`.

2. **Verify services are running**:
   Ensure both your reverse proxy (Nginx or IIS) and your DIG Node are running.

3. **Test without reverse proxy**:
   Temporarily allow direct access to port 4161 from the internet and test if you can access your DIG Node directly. This will help isolate whether the issue is with the DIG Node or the reverse proxy.

4. **Check firewall settings**:
   Ensure that both your Windows Firewall and any antivirus software are not blocking the necessary ports.

5. **Verify proxy settings**:
   Double-check your Nginx configuration or IIS rewrite rules to ensure they're correctly set up to forward requests to your DIG Node.

If you're still experiencing issues after these steps, you may need to seek further assistance from the DIG Network community or a network professional.

## Conclusion

After setting up your reverse proxy and modifying the firewall rules, your DIG Node's content server should be accessible from the internet via HTTP (port 80) and HTTPS (port 443). The reverse proxy will forward these requests to your DIG Node running on port 4161.