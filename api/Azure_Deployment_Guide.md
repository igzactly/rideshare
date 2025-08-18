# Azure VM and MongoDB Setup Guide for RideShare API

This guide provides step-by-step instructions for manually setting up an Azure Virtual Machine and a MongoDB database to deploy the RideShare API for the first time.

---

### **Part 1: Azure Virtual Machine Setup**

This guide assumes you will use **Ubuntu Server 22.04 LTS**, which is a common choice for web servers.

1.  **Create the Azure VM:**
    *   Log in to the [Azure Portal](https://portal.azure.com).
    *   Click **"Create a resource"** and search for **"Virtual machine"**. Click **"Create"**.
    *   **Basics Tab:**
        *   **Subscription & Resource Group:** Choose your subscription and create a new resource group (e.g., `rideshare-rg`).
        *   **Virtual machine name:** Give it a name (e.g., `rideshare-vm`).
        *   **Region:** Choose a region close to you.
        *   **Image:** Select **"Ubuntu Server 22.04 LTS - Gen2"**.
        *   **Size:** Choose a size. For starting, `B1s` or `B2s` under the "Standard" series is cost-effective.
        *   **Authentication type:** Select **"SSH public key"**.
        *   **Username:** Choose a username (e.g., `azureuser`).
        *   **SSH public key source:** Select **"Generate new key pair"**.
        *   **Key pair name:** Give it a name (e.g., `rideshare-vm-key`).
    *   **Disks Tab:** You can leave the defaults for now.
    *   **Networking Tab:**
        *   A virtual network and public IP will be created for you.
        *   **NIC network security group:** Select **"Advanced"**.
        *   Click **"Create new"** under the security group. Add an inbound rule to allow HTTP traffic:
            *   **Destination port ranges:** `80`
            *   **Protocol:** `TCP`
            *   **Name:** `Allow-HTTP`
        *   Add another inbound rule to allow your API traffic:
            *   **Destination port ranges:** `8000`
            *   **Protocol:** `TCP`
            *   **Name:** `Allow-API-8000`
    *   Click **"Review + create"**. After validation, click **"Create"**.
    *   When prompted, **download the private key (`.pem` file)** and save it securely. You will need it to connect to your VM.

2.  **Connect to the VM:**
    *   Find the public IP address of your VM from the Azure Portal.
    *   Open a terminal or command prompt on your local machine.
    *   Use the following command to connect via SSH. Replace `<your-private-key.pem>` and `<your-vm-ip>` with your actual values.
        ```bash
        ssh -i /path/to/your-private-key.pem azureuser@<your-vm-ip>
        ```

3.  **Install Dependencies on the VM:**
    *   Once connected, run the following commands to update the system and install Python, pip, Git, and Nginx (as a reverse proxy).
        ```bash
        # Update package lists and upgrade existing packages
        sudo apt update && sudo apt upgrade -y

        # Install Python 3.12 and pip
        sudo apt install python3.12 python3-pip -y

        # Install Git
        sudo apt install git -y

        # Install Nginx (recommended for production)
        sudo apt install nginx -y
        ```

---

### **Part 2: MongoDB Setup**

You have two main options. **Option A is highly recommended for ease of use and scalability.**

#### **Option A: MongoDB Atlas (Cloud Database - Recommended)**

1.  **Create a Free Cluster:**
    *   Go to the [MongoDB Atlas](https://www.mongodb.com/cloud/atlas) website and sign up.
    *   Follow the instructions to create a new project and build a database.
    *   Choose the **free `M0` cluster**. Select a cloud provider and region (ideally the same Azure region as your VM).
    *   Give your cluster a name and click **"Create"**.

2.  **Configure Database Access:**
    *   In your Atlas dashboard, go to **"Database Access"** under the "Security" section.
    *   Create a new database user with a username and password. Remember these credentials.
    *   Go to **"Network Access"**. Click **"Add IP Address"**.
    *   Select **"Allow Access From Anywhere"** (`0.0.0.0/0`). For better security, you can find your VM's public IP and add only that.

3.  **Get the Connection String:**
    *   Go back to your **"Database"** view and click the **"Connect"** button for your cluster.
    *   Select **"Drivers"**.
    *   It will show you a connection string. Copy this string. It will look something like this:
        ```
        mongodb+srv://<username>:<password>@<cluster-name>.mongodb.net/?retryWrites=true&w=majority
        ```
    *   Replace `<username>` and `<password>` with the credentials you created.

#### **Option B: Install MongoDB on the Azure VM (Self-Hosted)**

1.  **Install MongoDB:**as






























































f
    *   Run these commands on your VM to install MongoDB Community Edition.
        ```bash
        # Import the MongoDB public GPG key
        curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor

        # Create a list file for MongoDB
        echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list

        # Reload local package database
        sudo apt-get update

        # Install the MongoDB packages
        sudo apt-get install -y mongodb-org
        ```

2.  **Start and Enable MongoDB:**
    *   Start the MongoDB service and enable it to run on boot.
        ```bash
        sudo systemctl start mongod
        sudo systemctl enable mongod
        ```
    *   Your connection string for the self-hosted MongoDB will be: `mongodb://localhost:27017`

---

You are now ready to deploy the application code to the VM.
