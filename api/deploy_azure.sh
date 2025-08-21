#!/bin/bash

# RideShare API Azure VM Deployment Script
# This script automates the deployment of the RideShare API on an Azure VM

set -e  # Exit on any error

echo "🚀 Starting RideShare API deployment on Azure VM..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root. Please run as a regular user with sudo privileges."
   exit 1
fi

# Update system packages
print_status "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install required system dependencies
print_status "Installing system dependencies..."
sudo apt install -y python3.12 python3.12-venv python3-pip git nginx curl software-properties-common

# Install Docker
print_status "Installing Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    sudo usermod -aG docker $USER
    print_warning "You need to log out and log back in for Docker group membership to take effect."
fi

# Install Docker Compose (standalone)
print_status "Installing Docker Compose..."
if ! command -v docker-compose &> /dev/null; then
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

# Create application directory
APP_DIR="/home/$(whoami)/rideshare-api"
print_status "Setting up application directory at $APP_DIR..."

if [ ! -d "$APP_DIR" ]; then
    mkdir -p "$APP_DIR"
fi

cd "$APP_DIR"

# Clone or update repository
if [ ! -d ".git" ]; then
    print_status "Cloning repository..."
    # Note: Replace with your actual repository URL
    read -p "Enter your repository URL (or press Enter to skip): " REPO_URL
    if [ ! -z "$REPO_URL" ]; then
        git clone "$REPO_URL" .
        cd api
    else
        print_warning "Repository URL not provided. Please manually copy your code to $APP_DIR/api/"
        exit 1
    fi
else
    print_status "Updating repository..."
    git pull origin main
    cd api
fi

# Create environment file
print_status "Setting up environment variables..."
if [ ! -f ".env" ]; then
    cp env.example .env
    print_warning "Please edit .env file with your configuration:"
    print_warning "nano .env"
    
    # Generate a random secret key
    SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")
    sed -i "s/your-secret-key-here/$SECRET_KEY/" .env
    
    print_status "Generated random SECRET_KEY in .env file"
    print_warning "Please update MONGODB_URL and other settings in .env file"
fi

# Set up Nginx configuration
print_status "Configuring Nginx..."
sudo tee /etc/nginx/sites-available/rideshare-api > /dev/null <<EOF
server {
    listen 80;
    server_name _;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

    # Rate limiting
    limit_req_zone \$binary_remote_addr zone=api:10m rate=10r/s;
    limit_req zone=api burst=20 nodelay;

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
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Health check endpoint
    location /health {
        proxy_pass http://localhost:8000/;
        access_log off;
    }
}
EOF

# Enable the site
sudo ln -sf /etc/nginx/sites-available/rideshare-api /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test and reload Nginx
sudo nginx -t && sudo systemctl reload nginx

# Enable and start Nginx
sudo systemctl enable nginx
sudo systemctl start nginx

# Build and start the application
print_status "Building and starting the application..."
docker-compose down --remove-orphans 2>/dev/null || true
docker-compose build
docker-compose up -d

# Create systemd service for auto-restart
print_status "Creating systemd service..."
sudo tee /etc/systemd/system/rideshare-api.service > /dev/null <<EOF
[Unit]
Description=RideShare API
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$APP_DIR/api
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable rideshare-api

# Set up log rotation
print_status "Setting up log rotation..."
sudo tee /etc/logrotate.d/rideshare-api > /dev/null <<EOF
/var/lib/docker/containers/*/*-json.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
}
EOF

# Create backup script
print_status "Creating backup script..."
tee ~/backup_rideshare.sh > /dev/null <<EOF
#!/bin/bash
# RideShare API Backup Script

BACKUP_DIR="/home/$(whoami)/backups"
DATE=\$(date +%Y%m%d_%H%M%S)

mkdir -p "\$BACKUP_DIR"

# Backup application code
tar -czf "\$BACKUP_DIR/rideshare-api-\$DATE.tar.gz" -C "$APP_DIR" .

# Backup environment file
cp "$APP_DIR/api/.env" "\$BACKUP_DIR/.env-\$DATE"

echo "Backup completed: \$BACKUP_DIR/rideshare-api-\$DATE.tar.gz"
EOF

chmod +x ~/backup_rideshare.sh

# Setup firewall
print_status "Configuring UFW firewall..."
sudo ufw --force enable
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Final status check
print_status "Checking service status..."
sleep 10

if docker-compose ps | grep -q "Up"; then
    print_status "✅ RideShare API is running successfully!"
    print_status "API URL: http://$(curl -s ifconfig.me):80"
    print_status "API Documentation: http://$(curl -s ifconfig.me):80/docs"
    print_status "MongoDB Express (if enabled): http://$(curl -s ifconfig.me):8081"
else
    print_error "❌ Service may not be running properly. Check logs with:"
    echo "docker-compose logs -f"
fi

print_status "🎉 Deployment completed!"
print_status ""
print_status "Next steps:"
print_status "1. Edit .env file with your MongoDB connection string and other settings"
print_status "2. Restart the service: docker-compose restart"
print_status "3. Check logs: docker-compose logs -f"
print_status "4. Create backups: ~/backup_rideshare.sh"
print_status ""
print_status "Useful commands:"
print_status "- View logs: docker-compose logs -f"
print_status "- Restart: docker-compose restart"
print_status "- Stop: docker-compose down"
print_status "- Update: git pull && docker-compose build && docker-compose up -d"
