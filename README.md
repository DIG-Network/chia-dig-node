### DIG Node Setup Guide

A DIG Node is a data layer-powered web server that allows you to deploy and manage data and applications. Setting up a DIG Node requires the ability to port forward specific ports to ensure proper functionality. If you're unable to port forward, a future service will allow you to use the data layer without a dedicated DIG Node. This guide is for those who want full control over a DIG Node they own. 

**Requirements:**
- Ability to port forward on your server.
- Some XCH (Chia cryptocurrency) to fund operations.
- Docker and Docker Compose installed on the machine where your DIG Node will be hosted.
  - [Docker Installation Guide](https://docs.docker.com/get-docker/)
  - [Docker Compose Installation Guide](https://docs.docker.com/compose/install/)


---

## Linux Service Installation and Activation

You can use the `install_dig_service.sh` script to automate the setup of your DIG Node as a `systemd` service. This will ensure that your DIG Node starts automatically after system reboots.

1. ** Clone this repo somewhere in your user directory 
    ```bash
    git clone https://github.com/DIG-Network/chia-dig-node
    cd chia-dig-node
    ```

2. Modify the docker-compose.yml and make sure you give your node a strong username and password. Make sure they are set on both the propagation server and the incentive server
   ```bash
    - DIG_USERNAME=6JctogHaIwk8EqpuMuKl
    - DIG_PASSWORD=vq47m5A0leRPVH8NAwFe
   ```
   If you run your own full node, point the env for container to the public ip address for your node. Doing this will give your node better performance in general.
   ```bash
    - TRUSTED_FULLNODE=YouPublicIpAddressNoPort
   ```

2. **Run the install script**:
   ```bash
   chmod +x install_dig_service.sh
   sudo ./install_dig_service.sh
   ```

   The script will install the `dig@service`, enable it on boot, and start it automatically.

---

## Port Forwarding (Ports 80, 4159, and 4160)

To ensure proper functionality of your DIG Node, you need to allow incoming traffic on specific ports. Here’s how to configure port forwarding on Linux using `ufw` and how to handle port forwarding on your router.

### Linux Firewall Configuration (Using `ufw`)

On your Linux server, you’ll need to open the necessary ports using `ufw`, the uncomplicated firewall:

1. **Allow traffic on the necessary ports**:
   
   Run the following commands to open **Ports 80, 4159, and 4160**:

   ```bash
   sudo ufw allow 80/tcp   # Content Server (HTTP)
   sudo ufw allow 4159/tcp # Data Propagation Server (mTLS)
   sudo ufw allow 4160/tcp # Incentive Server (Incentives Management)
   ```

2. **Enable the firewall** (if not already enabled):

   ```bash
   sudo ufw enable
   ```

3. **Check the status of the firewall**:

   ```bash
   sudo ufw status
   ```

### Port Forwarding on Your Router

In addition to configuring your Linux firewall, you may also need to forward these ports on your router if the machine hosting the DIG Node is behind a home or office network. Here’s how:

1. **Access your router settings**:
   - Open a web browser and enter your router’s IP address (e.g., `192.168.1.1`) in the address bar.
   - Log in using your router’s credentials.

2. **Navigate to the Port Forwarding section**:
   - The location of the port forwarding section will vary by router, but it’s usually under “Advanced” or “NAT” settings.

3. **Create new port forwarding rules**:
   - For each port (80, 4159, and 4160), add a rule to forward traffic to the local IP address of the machine running your DIG Node.
   - Set the protocol to `TCP` for all three ports.

4. **Example configuration**:

   | Port Range | Local IP Address   | Protocol |
   |------------|--------------------|----------|
   | 80         | 192.168.1.X (your DIG Node's IP) | TCP      |
   | 4159       | 192.168.1.X         | TCP      |
   | 4160       | 192.168.1.X         | TCP      |

5. **Save the changes**: After setting up the port forwarding rules, save the configuration.

6. **Test the ports**: You can test if the ports are correctly forwarded by using an online port checker tool like [YouGetSignal](https://www.yougetsignal.com/tools/open-ports/). Enter your external IP address and the port number (80, 4159, or 4160) to check if the port is open.

---

## Step 1: Create a Dedicated Mnemonic for DIG

#### Step 1: Create a Dedicated Mnemonic for DIG

The DIG CLI and DIG Node Server require a mnemonic to operate. Although the mnemonic is encrypted and stored, it is **highly recommended** to create a dedicated mnemonic specifically for DIG development. It is also **highly recommended** that you only keep enough balance to run the DIG Node. While the software does its best to keep your seed secure, its ultimately your responsibility to keep your funds safe.

1. **Create a New Wallet Seed:**
   - Open the official Chia UI.
   - Create a new wallet seed and name it `DIGNode`.
   - Fund the wallet with some XCH. While 1 XCH is sufficient for the short term, it is recommended to maintain at least 0.25 XCH.

---

#### Step 2: Install the DIG CLI

The DIG CLI is a tool that you'll need to install on your development machine to interact with your DIG Node.

1. **Install Node.js and NPM:**
   - Ensure that Node.js version 20 and NPM are installed on your machine.

2. **Install DIG CLI:**
   - Run the following command to install the DIG CLI globally:
     ```bash
     npm install dig-cli -g
     ```

---

#### Step 3: Import Your Mnemonic into DIG CLI

After installing the DIG CLI, you need to import the mnemonic you created in Step 1.

1. **Import the Mnemonic:**
   - Run the following command:
     ```bash
     dig keys generate
     ```
   - Choose the option to "Import from Chia client."
   - Ensure that the Chia client is running and you are logged into your new wallet.

---

#### Step 4: Generate Credentials for Your DIG Node

Your DIG Node, referred to as the "remote," will communicate with the DIG CLI using mTLS for security. You'll need a username and password to access the remote.

1. **Generate Credentials:**
   - Run the following command to generate a secure username and password:
     ```bash
     dig generate creds
     ```
   - Save these credentials securely.

2. **Associate Credentials with Remote IP:**
   - If you know the public IP address of your remote, you can associate the credentials with it during this process.

---

#### Step 5: Prepare Your DIG Node Host Machine

You can run the DIG Node on your local machine, but it is highly recommended to use a Linux server that is always on.

1. **Open Required Ports:**
   - Ensure the following ports are open on your host machine:
     - **Port 80:** For the Content Server, which serves data on your DIG Node.
     - **Port 4159:** For the Data Propagation Server, which handles data synchronization between DIG Nodes using mTLS on encrypted channels.

2. **Configure Your Firewall:**
   - Ensure these ports are open in your firewall settings.

---

#### Step 6: Set Up the DIG Node with Docker

Now that your host machine is ready, you can set up the DIG Node using Docker.

1. **Create a Project Folder:**
   - On your DIG Node host machine, create a project folder.

2. **Create `docker-compose.yml`:**
   - Inside the project folder, create a new file named `docker-compose.yml`.
   - Copy the contents from the following link into the file:
     [docker-compose.yml](https://github.com/Datalayer-Storage/dig-cli/blob/main/docker-compose.yml).

3. **Configure Environment Variables:**
   - Use the credentials you generated in Step 4.
   - Set the `DIG_USERNAME` and `DIG_PASSWORD` environment variables in the `docker-compose.yml` file.

4. **Start the DIG Node:**
   - Run the following command to start the DIG Node:
     ```bash
     docker-compose up
     ```

5. **Verify Setup:**
   - Visit `http://your-ip-address` in a web browser.
   - If you see a page with the header "Store Index," your DIG Node is running correctly.

---

#### Step 7: Sync the Mnemonic to Your DIG Node

Finally, you need to sync the mnemonic from your DIG CLI to your DIG Node.

1. **Sync the Mnemonic:**
   - Run the following command to sync the mnemonic using mTLS:
     ```bash
     dig remote sync seed
     ```
   - This command will send the mnemonic to your remote keyring, allowing the remote to manage server coins needed for the DIG Network.

---

By following these steps, you will have successfully set up a DIG Node with a dedicated mnemonic, allowing you to monitor and manage your node's balance easily. This setup ensures that your DIG Node is secure, always accessible, and ready for deploying data and applications.