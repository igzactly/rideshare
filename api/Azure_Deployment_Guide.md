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

---

### **Part 3: Deploy the RideShare API**

#### **Option A: Automated Deployment (Recommended)**

1. **Download and run the deployment script:**
   ```bash
   # Download the deployment script
   curl -O https://raw.githubusercontent.com/your-repo/rideshare/main/api/deploy_azure.sh
   
   # Make it executable
   chmod +x deploy_azure.sh
   
   # Run the deployment script
   ./deploy_azure.sh
   ```

2. **Follow the prompts:**
   - Enter your repository URL when prompted
   - The script will automatically install all dependencies, configure Nginx, and start the services

#### **Option B: Manual Deployment**

1. **Clone your repository:**
   ```bash
   cd /home/azureuser
   git clone <your-repository-url> rideshare-api
   cd rideshare-api/api
   ```

2. **Set up environment variables:**
   ```bash
   cp env.example .env
   nano .env
   ```
   
   Update the following critical settings:
   - `MONGODB_URL`: Your MongoDB connection string (from Atlas or local)
   - `SECRET_KEY`: Generate a secure random key
   - Other settings as needed

3. **Install Docker and Docker Compose:**
   ```bash
   # Install Docker
   curl -fsSL https://get.docker.com -o get-docker.sh
   sudo sh get-docker.sh
   sudo usermod -aG docker $USER
   
   # Install Docker Compose
   sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
   sudo chmod +x /usr/local/bin/docker-compose
   
   # Log out and back in for group membership to take effect
   ```

4. **Build and start the application:**
   ```bash
   docker-compose build
   docker-compose up -d
   ```

5. **Configure Nginx as reverse proxy:**
   ```bash
   sudo apt install nginx -y
   
   # Create Nginx configuration
   sudo tee /etc/nginx/sites-available/rideshare-api > /dev/null <<EOF
   server {
       listen 80;
       server_name _;
       
       location / {
           proxy_pass http://localhost:8000;
           proxy_set_header Host \$host;
           proxy_set_header X-Real-IP \$remote_addr;
           proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
           proxy_set_header X-Forwarded-Proto \$scheme;
           
           # WebSocket support
           proxy_http_version 1.1;
           proxy_set_header Upgrade \$http_upgrade;
           proxy_set_header Connection "upgrade";
       }
   }
   EOF
   
   # Enable the site
   sudo ln -s /etc/nginx/sites-available/rideshare-api /etc/nginx/sites-enabled/
   sudo rm /etc/nginx/sites-enabled/default
   sudo nginx -t && sudo systemctl reload nginx
   ```

---

### **Part 4: Production Configuration**

#### **Security Hardening**

1. **Update the system regularly:**
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

2. **Configure firewall:**
   ```bash
   sudo ufw enable
   sudo ufw allow ssh
   sudo ufw allow 80/tcp
   sudo ufw allow 443/tcp
   ```

3. **Secure MongoDB (if self-hosted):**
   - Enable authentication
   - Create application-specific users
   - Bind to localhost only

4. **SSL/TLS Certificate (Recommended):**
   ```bash
   # Install Certbot
   sudo apt install certbot python3-certbot-nginx -y
   
   # Get SSL certificate (replace your-domain.com)
   sudo certbot --nginx -d your-domain.com
   ```

#### **Monitoring and Logging**

1. **View application logs:**
   ```bash
   docker-compose logs -f api
   ```

2. **Monitor system resources:**
   ```bash
   htop
   df -h
   docker stats
   ```

3. **Set up log rotation:**
   ```bash
   sudo tee /etc/logrotate.d/rideshare-api > /dev/null <<EOF
   /var/lib/docker/containers/*/*-json.log {
       daily
       rotate 7
       compress
       delaycompress
       missingok
       notifempty
   }
   EOF
   ```

#### **Backup Strategy**

1. **Application code backup:**
   ```bash
   tar -czf rideshare-backup-$(date +%Y%m%d).tar.gz /home/azureuser/rideshare-api
   ```

2. **Database backup (if using local MongoDB):**
   ```bash
   docker exec rideshare-mongo mongodump --out /data/backup
   docker cp rideshare-mongo:/data/backup ./mongodb-backup-$(date +%Y%m%d)
   ```

---

### **Part 5: Testing the Deployment**

1. **Health Check:**
   ```bash
   curl http://your-vm-ip/
   ```

2. **API Documentation:**
   Visit `http://your-vm-ip/docs` in your browser

3. **Test API endpoints:**
   ```bash
   # Test user registration
   curl -X POST "http://your-vm-ip/auth" \
     -H "Content-Type: application/json" \
     -d '{"email": "test@example.com", "password": "testpassword123"}'
   ```

---

### **Part 6: Maintenance and Updates**

#### **Updating the Application**

1. **Pull latest changes:**
   ```bash
   cd /home/azureuser/rideshare-api/api
   git pull origin main
   ```

2. **Rebuild and restart:**
   ```bash
   docker-compose build
   docker-compose up -d
   ```

#### **Database Maintenance**

1. **View database status:**
   ```bash
   docker-compose exec mongo mongo --eval "db.stats()"
   ```

2. **Create database indexes:**
   ```bash
   docker-compose exec api python -c "
   import asyncio
   from app.database import create_indexes
   asyncio.run(create_indexes())
   "
   ```

#### **Performance Optimization**

1. **Monitor resource usage:**
   ```bash
   docker stats
   free -h
   df -h
   ```

2. **Optimize Docker containers:**
   ```bash
   docker system prune -f
   docker volume prune -f
   ```

---

### **Part 7: Troubleshooting**

#### **Common Issues**

1. **Service not starting:**
   ```bash
   docker-compose logs api
   docker-compose ps
   ```

2. **Database connection issues:**
   ```bash
   docker-compose logs mongo
   # Check MongoDB connection string in .env
   ```

3. **Port conflicts:**
   ```bash
   sudo netstat -tlnp | grep :8000
   sudo lsof -i :8000
   ```

4. **Memory issues:**
   ```bash
   free -h
   # Consider upgrading VM size if consistently low on memory
   ```

#### **Useful Commands**

```bash
# View all services status
docker-compose ps

# Restart specific service
docker-compose restart api

# View real-time logs
docker-compose logs -f

# Enter container shell
docker-compose exec api bash

# Check Nginx status
sudo systemctl status nginx

# Test Nginx configuration
sudo nginx -t
```

---

### **Part 8: Environment-Specific Configurations**

#### **Development Environment**
```bash
# Start with development profile (includes mongo-express)
docker-compose --profile dev up -d
```

#### **Production Environment**
```bash
# Start with production profile (includes Redis)
docker-compose --profile prod up -d
```

#### **Scaling Considerations**

For high-traffic scenarios, consider:

1. **Load Balancing:**
   - Multiple API container instances
   - Nginx load balancer configuration

2. **Database Scaling:**
   - MongoDB Atlas with auto-scaling
   - Read replicas for read-heavy workloads

3. **Caching:**
   - Redis for session management
   - CDN for static content

4. **Monitoring:**
   - Application Performance Monitoring (APM)
   - Log aggregation services
   - Health check endpoints

---

### **Part 9: Cost Optimization**

1. **VM Right-sizing:**
   - Monitor CPU and memory usage
   - Scale up/down based on actual usage

2. **Storage Optimization:**
   - Regular cleanup of logs and temporary files
   - Use managed databases for production

3. **Network Costs:**
   - Use CDN for static content
   - Optimize API response sizes

---

You are now ready to deploy and maintain the RideShare API on Azure VM!
