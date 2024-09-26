Here are the **manual setup instructions** for those who cannot run the script and want to set everything up manually:

---

## **DIG Node Manual Setup Instructions**

### **Prerequisites**

Ensure that your system meets the following prerequisites:
1. **Linux Server** (e.g., Ubuntu, CentOS, etc.).
2. **Root Access** or a user with `sudo` privileges.
3. The following **software** is installed:
   - Docker
   - Docker Compose
   - UFW (or another firewall tool)
   - Nginx (optional for reverse proxy)
   - OpenSSL (for generating SSL certificates)
   - Certbot (optional for Let's Encrypt SSL certificates)

---

### **Step 1: Install Required Software**

If the required software is not installed, install it using your system’s package manager. Below are installation commands for **Ubuntu**:

```bash
sudo apt update
sudo apt install docker docker-compose ufw openssl certbot nginx -y
```

For **CentOS** or **RHEL**:

```bash
sudo yum install docker docker-compose firewalld openssl certbot nginx -y
```

---

### **Step 2: Start Docker and Enable on Boot**

Ensure Docker is running and enabled on boot:

```bash
sudo systemctl start docker
sudo systemctl enable docker
```

Add your user to the Docker group to avoid needing `sudo` for Docker commands:

```bash
sudo usermod -aG docker $USER
```

Log out and back in for the group changes to take effect.

---

### **Step 3: Open Necessary Ports**

If you are using **UFW**, configure the firewall to allow the required ports:

```bash
sudo ufw allow 4159/tcp    # Propagation Server
sudo ufw allow 4160/tcp    # Incentive Server
sudo ufw allow 4161/tcp    # Content Server
sudo ufw allow 80/tcp      # HTTP (optional for Nginx reverse proxy)
sudo ufw allow 443/tcp     # HTTPS (optional for Nginx reverse proxy)
sudo ufw reload
```

For **firewalld** (CentOS, RHEL):

```bash
sudo firewall-cmd --add-port=4159/tcp --permanent
sudo firewall-cmd --add-port=4160/tcp --permanent
sudo firewall-cmd --add-port=4161/tcp --permanent
sudo firewall-cmd --add-port=80/tcp --permanent    # Optional for Nginx
sudo firewall-cmd --add-port=443/tcp --permanent   # Optional for Nginx
sudo firewall-cmd --reload
```

---

### **Step 4: Create Docker-Compose Configuration**

Create a `docker-compose.yml` file that defines your DIG Node services. This file will configure the propagation server, content server, and incentive server.

#### Example `docker-compose.yml`:

```yaml
version: '3.8'

services:
  propagation-server:
    image: dignetwork/dig-propagation-server:latest-alpha
    ports:
      - "4159:4159"
    volumes:
      - ~/.dig/remote:/.dig
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
      - ~/.dig/remote:/.dig
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
      - ~/.dig/remote:/.dig
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

Save this file to the directory you want to use for your DIG Node setup.

---

### **Step 5: Start Your DIG Node**

Start the DIG Node services using Docker Compose:

```bash
docker-compose up -d
```

This will start the three DIG Node services (propagation, content, and incentive servers) in the background.

---

### **Step 6: Optional - Set Up Nginx Reverse Proxy**

If you want to expose your content server over HTTP/HTTPS with Nginx, follow these steps:

1. **Install Nginx**:

   ```bash
   sudo apt install nginx -y
   ```

2. **Configure Nginx Reverse Proxy**:

   Create a configuration file for Nginx at `/etc/nginx/sites-available/dig-node`:

   ```nginx
   server {
       listen 80;
       server_name your_domain_or_ip;

       location / {
           proxy_pass http://localhost:4161;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
       }
   }
   ```

   Symlink the configuration file to enable the site:

   ```bash
   sudo ln -s /etc/nginx/sites-available/dig-node /etc/nginx/sites-enabled/
   sudo systemctl restart nginx
   ```

---

### **Step 7: Optional - Set Up HTTPS with Let’s Encrypt**

To secure your Nginx reverse proxy with HTTPS, use Let’s Encrypt:

1. **Install Certbot**:

   ```bash
   sudo apt install certbot python3-certbot-nginx -y
   ```

2. **Obtain an SSL Certificate**:

   Run the following command to obtain and install the SSL certificate:

   ```bash
   sudo certbot --nginx -d your_domain
   ```

3. **Set Up Auto-Renewal**:

   Certbot sets up automatic renewal, but you can manually test it by running:

   ```bash
   sudo certbot renew --dry-run
   ```

---

### **Step 8: Set Up Systemd Service**

To ensure your DIG Node starts on boot, create a **systemd** service file.

1. Create a file `/etc/systemd/system/dig-node.service`:

   ```bash
   [Unit]
   Description=DIG Node Docker Compose
   After=network.target

   [Service]
   WorkingDirectory=/path/to/your/docker-compose-directory
   ExecStart=/usr/local/bin/docker-compose up
   ExecStop=/usr/local/bin/docker-compose down
   Restart=always
   User=your_user

   [Install]
   WantedBy=multi-user.target
   ```

2. Reload systemd and enable the service:

   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable dig-node.service
   sudo systemctl start dig-node.service
   ```

---

### **Conclusion**

You’ve now manually set up a DIG Node with or without Nginx for reverse proxy. If you have any issues, check logs using Docker or systemd to debug:

- **Check Docker logs**: `docker-compose logs -f`
- **Check systemd service**: `sudo journalctl -u dig-node.service`

This manual setup allows you to manage and customize your DIG Node on your server, allowing it to function fully as part of the DIG Network.