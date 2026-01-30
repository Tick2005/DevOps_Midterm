#!/bin/bash

# ============================================
# PRODUCTION DEPLOYMENT SCRIPT FOR AWS UBUNTU
# ============================================
# This script deploys the application in production mode
# with PM2 process manager and Nginx reverse proxy
#
# Usage:
#   ./deploy.sh              # Run production deployment

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="$SCRIPT_DIR"

# Set to production mode only
MODE="production"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${CYAN}🚀 PRODUCT MANAGEMENT SYSTEM${NC}"
echo -e "${CYAN}   Mode: ${YELLOW}PRODUCTION${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📍 Application root: $APP_ROOT"
echo ""

# Navigate to app root
if [ ! -d "$APP_ROOT" ]; then
    echo -e "${RED}❌ Error: App root not found at $APP_ROOT${NC}"
    exit 1
fi

cd "$APP_ROOT"
echo "✓ Working directory: $(pwd)"
echo ""

# Detect OS
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
    if [ -f /etc/debian_version ]; then
        PKG_MANAGER="apt"
    elif [ -f /etc/redhat-release ]; then
        PKG_MANAGER="yum"
    fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="mac"
    PKG_MANAGER="brew"
else
    echo -e "${RED}❌ Unsupported OS: $OSTYPE${NC}"
    exit 1
fi

# Check if running with sudo privileges (for production)
if [ "$EUID" -eq 0 ]; then 
    SUDO=""
else
    SUDO="sudo"
fi

# ============================================
# LOAD ENVIRONMENT VARIABLES FROM .env
# ============================================

ENV_FILE="$APP_ROOT/.env"

# ============================================
# FUNCTION: CREATE .ENV FILE INTERACTIVELY
# ============================================
create_env_file() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${CYAN}📝 Environment Configuration${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo -e "${BLUE}Setting up environment variables for MongoDB Atlas${NC}"
    echo ""
    
    # Get MongoDB password
    echo -e "${YELLOW}MongoDB Atlas Configuration:${NC}"
    echo "Base URI: mongodb+srv://admin:<db_password>@cluster0.ahaubn2.mongodb.net/"
    echo "Database: productdb (fixed)"
    echo ""
    
    read -rsp "Enter MongoDB Password: " MONGO_PASSWORD
    echo ""
    while [ -z "$MONGO_PASSWORD" ]; do
        echo -e "${RED}Password cannot be empty!${NC}"
        read -rsp "Enter MongoDB Password: " MONGO_PASSWORD
        echo ""
    done
    
    # Build MongoDB URI with fixed values
    MONGODB_URI="mongodb+srv://admin:${MONGO_PASSWORD}@cluster0.ahaubn2.mongodb.net/productdb?retryWrites=true&w=majority"
    
    echo ""
    echo -e "${CYAN}Configuration Summary:${NC}"
    echo "  Username: admin"
    echo "  Cluster:  cluster0.ahaubn2.mongodb.net"
    echo "  Database: productdb"
    echo ""
    
    # Get application port
    read -p "Application Port [3000]: " APP_PORT
    APP_PORT=${APP_PORT:-3000}
    
    # Production defaults
    APP_HOST="0.0.0.0"
    APP_ENV="production"
    
    echo ""
    echo -e "${GREEN}Creating .env file...${NC}"
    
    # Create .env file
    cat > "$ENV_FILE" << EOF
# MongoDB Atlas Configuration
MONGODB_URI=$MONGODB_URI
MONGO_URI=$MONGODB_URI
DATA_SOURCE=mongodb

# Application Settings
PORT=$APP_PORT
HOST=$APP_HOST
NODE_ENV=$APP_ENV

# Optional: Add more variables below as needed
# MAX_FILE_SIZE=10485760
EOF
    
    chmod 600 "$ENV_FILE"  # Secure file permissions
    echo -e "${GREEN}✓ .env file created successfully${NC}"
    echo -e "${GREEN}✓ File permissions set to 600 (owner read/write only)${NC}"
    echo ""
    
    # Reload environment variables
    set -a
    source "$ENV_FILE"
    set +a
}

# ============================================
# FUNCTION: UPDATE EXISTING .ENV FILE
# ============================================
update_env_file() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${CYAN}📝 Update Environment Configuration${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo -e "${BLUE}Current values will be kept if you just press Enter${NC}"
    echo ""
    
    # Load current values
    set -a
    source "$ENV_FILE"
    set +a
    
    # Extract current password from URI if possible
    CURRENT_PASSWORD=""
    if [[ $MONGODB_URI =~ admin:([^@]+)@ ]]; then
        CURRENT_PASSWORD="${BASH_REMATCH[1]}"
    fi
    
    # Update MongoDB password
    echo -e "${YELLOW}MongoDB Configuration:${NC}"
    echo "Base URI: mongodb+srv://admin:<db_password>@cluster0.ahaubn2.mongodb.net/"
    echo "Database: productdb (fixed)"
    echo ""
    
    if [ -n "$CURRENT_PASSWORD" ]; then
        echo "Current password: ${CURRENT_PASSWORD:0:3}***"
    fi
    read -rsp "New MongoDB Password (Enter to keep current): " NEW_PASSWORD
    echo ""
    
    if [ -n "$NEW_PASSWORD" ]; then
        MONGO_PASSWORD="$NEW_PASSWORD"
        echo -e "${GREEN}✓ Password will be updated${NC}"
    else
        MONGO_PASSWORD="$CURRENT_PASSWORD"
        echo -e "${BLUE}✓ Keeping current password${NC}"
    fi
    
    # Build MongoDB URI
    MONGODB_URI="mongodb+srv://admin:${MONGO_PASSWORD}@cluster0.ahaubn2.mongodb.net/productdb?retryWrites=true&w=majority"
    
    # Update application port
    echo ""
    echo "Current port: ${PORT:-3000}"
    read -p "New Application Port (Enter to keep current): " NEW_PORT
    
    if [ -n "$NEW_PORT" ]; then
        APP_PORT="$NEW_PORT"
        echo -e "${GREEN}✓ Port will be updated to $APP_PORT${NC}"
    else
        APP_PORT="${PORT:-3000}"
        echo -e "${BLUE}✓ Keeping current port $APP_PORT${NC}"
    fi
    
    # Production defaults
    APP_HOST="0.0.0.0"
    APP_ENV="production"
    
    echo ""
    echo -e "${GREEN}Updating .env file...${NC}"
    
    # Update .env file
    cat > "$ENV_FILE" << EOF
# MongoDB Atlas Configuration
MONGODB_URI=$MONGODB_URI
MONGO_URI=$MONGODB_URI
DATA_SOURCE=mongodb

# Application Settings
PORT=$APP_PORT
HOST=$APP_HOST
NODE_ENV=$APP_ENV

# Optional: Add more variables below as needed
# MAX_FILE_SIZE=10485760
EOF
    
    chmod 600 "$ENV_FILE"
    echo -e "${GREEN}✓ .env file updated successfully${NC}"
    echo ""
    
    # Reload environment variables
    set -a
    source "$ENV_FILE"
    set +a
}

# ============================================
# LOAD OR CREATE .ENV FILE
# ============================================

if [ -f "$ENV_FILE" ]; then
    echo "📄 Loading environment variables from .env..."
    set -a
    source "$ENV_FILE"
    set +a
    echo -e "${GREEN}✓ Environment variables loaded${NC}"
    echo ""
    
    # Ask if user wants to update configuration
    read -p "Do you want to update the .env configuration? (y/n): " -n 1 -r
    echo ""
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        update_env_file
    else
        echo -e "${BLUE}✓ Using existing configuration${NC}"
    fi
else
    echo -e "${YELLOW}⚠ .env file not found.${NC}"
    echo -e "${YELLOW}Creating new environment configuration...${NC}"
    create_env_file
fi

# Set defaults
PORT="${PORT:-3000}"
DATA_SOURCE="${DATA_SOURCE:-mongodb}"
MONGODB_URI="${MONGODB_URI:-}"

echo ""

# ============================================
# STEP 1: INSTALL DEPENDENCIES
# ============================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${CYAN}📦 STEP 1: Installing Dependencies${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Function to install packages
install_package() {
    local package=$1
    
    if command -v "$package" &> /dev/null 2>&1 || dpkg -s "$package" &> /dev/null 2>&1; then
        echo -e "${GREEN}✓ $package is already installed${NC}"
        return 0
    fi
    
    echo "Installing $package..."
    
    if [ "$PKG_MANAGER" == "apt" ]; then
        $SUDO apt update -qq && $SUDO apt install -y "$package"
    elif [ "$PKG_MANAGER" == "yum" ]; then
        $SUDO yum install -y "$package"
    elif [ "$PKG_MANAGER" == "brew" ]; then
        brew install "$package"
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $package installed successfully${NC}"
        return 0
    else
        echo -e "${RED}❌ Failed to install $package${NC}"
        return 1
    fi
}

# Install curl and git
install_package "curl"
install_package "git"

# Install Node.js if not present
if ! command -v node &> /dev/null; then
    echo "Installing Node.js 20.x LTS..."
    if [ "$PKG_MANAGER" == "apt" ]; then
        curl -fsSL https://deb.nodesource.com/setup_20.x | $SUDO -E bash -
        install_package "nodejs"
    elif [ "$PKG_MANAGER" == "yum" ]; then
        curl -fsSL https://rpm.nodesource.com/setup_20.x | $SUDO bash -
        install_package "nodejs"
    elif [ "$PKG_MANAGER" == "brew" ]; then
        install_package "node"
    fi
else
    NODE_VERSION=$(node -v)
    echo -e "${GREEN}✓ Node.js already installed ($NODE_VERSION)${NC}"
fi

# Install nginx for production mode
if ! command -v nginx &> /dev/null; then
    echo "Installing nginx..."
    install_package "nginx"
else
    echo -e "${GREEN}✓ Nginx already installed${NC}"
fi

# Install PM2 globally for production mode
if ! command -v pm2 &> /dev/null; then
    echo "Installing PM2 process manager..."
    $SUDO npm install -g pm2
    echo -e "${GREEN}✓ PM2 installed successfully${NC}"
else
    echo -e "${GREEN}✓ PM2 already installed${NC}"
fi

echo ""
echo -e "${GREEN}✅ All dependencies installed!${NC}"
echo ""

# ============================================
# STEP 2: MONGODB CONFIGURATION
# ============================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${CYAN}☁️  STEP 2: MongoDB Configuration${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Display MongoDB configuration (without verification)
if [ -n "$MONGODB_URI" ]; then
    echo -e "${GREEN}✓ MongoDB Atlas URI configured${NC}"
    # Hide password in display
    DISPLAY_URI=$(echo "$MONGODB_URI" | sed 's/:\/\/[^:]*:[^@]*@/:\/\/***:***@/')
    echo "   URI: $DISPLAY_URI"
else
    echo -e "${RED}❌ MongoDB URI not configured${NC}"
    echo "Please run the script again and configure MongoDB properly."
    exit 1
fi

echo ""

# ============================================
# STEP 3: APPLICATION SETUP
# ============================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${CYAN}⚙️  STEP 3: Application Setup${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Create .gitignore
if [ ! -f ".gitignore" ]; then
    cat > .gitignore << 'EOF'
.env
node_modules/
public/uploads/*
!public/uploads/.gitkeep
*.log
.DS_Store
EOF
    echo -e "${GREEN}✓ .gitignore created${NC}"
fi

# Create uploads directory
if [ ! -d "public/uploads" ]; then
    mkdir -p "public/uploads"
    touch "public/uploads/.gitkeep"
    echo -e "${GREEN}✓ Uploads directory created${NC}"
fi

# Install npm dependencies
if [ ! -d "node_modules" ]; then
    echo "Installing npm packages..."
    npm install --production
    echo -e "${GREEN}✓ Dependencies installed${NC}"
else
    echo -e "${GREEN}✓ Dependencies already installed${NC}"
fi

echo ""

# ============================================
# PRODUCTION MODE - PM2 + NGINX
# ============================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${CYAN}🔧 Production Deployment${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ============================================
# CREATE PM2 ECOSYSTEM FILE
# ============================================

echo "Setting up PM2 configuration..."

cat > "ecosystem.config.js" << EOF
module.exports = {
  apps: [{
    name: 'product-app',
    script: './main.js',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production',
      PORT: ${PORT:-3000},
      HOST: '0.0.0.0'
    },
    error_file: './logs/pm2-error.log',
    out_file: './logs/pm2-out.log',
    log_file: './logs/pm2-combined.log',
    time: true
  }]
};
EOF

# Create logs directory
mkdir -p logs

echo -e "${GREEN}✓ PM2 ecosystem file created${NC}"

# ============================================
# CREATE NGINX CONFIGURATION
# ============================================

echo "Setting up nginx configuration..."

cat > "nginx.conf" << EOF
server {
    listen 80;
    listen [::]:80;
    server_name _;

    # Logs
    access_log /var/log/nginx/product-app-access.log;
    error_log /var/log/nginx/product-app-error.log;

    # Max upload size
    client_max_body_size 10M;

    # Main application - Reverse proxy to Node.js
    location / {
        proxy_pass http://localhost:${PORT:-3000};
        proxy_http_version 1.1;
        
        # WebSocket support
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        
        # Headers
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Buffering
        proxy_cache_bypass \$http_upgrade;
        proxy_buffering off;
    }

    # Serve uploaded files directly from nginx
    location /uploads/ {
        alias $APP_ROOT/public/uploads/;
        expires 1y;
        add_header Cache-Control "public, immutable";
        add_header X-Content-Type-Options nosniff;
        
        # Security: prevent script execution
        location ~* \.(php|pl|py|jsp|asp|sh|cgi)\$ {
            deny all;
        }
    }

    # Static assets caching
    location ~* \.(css|js|jpg|jpeg|png|gif|ico|svg|woff|woff2|ttf|eot)\$ {
        proxy_pass http://localhost:${PORT:-3000};
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;

    # Hide nginx version
    server_tokens off;
}
EOF

# Copy to nginx
$SUDO cp "nginx.conf" /etc/nginx/sites-available/product-app

# Remove default site
if [ -f /etc/nginx/sites-enabled/default ]; then
    $SUDO rm /etc/nginx/sites-enabled/default
fi

# Enable site
$SUDO ln -sf /etc/nginx/sites-available/product-app /etc/nginx/sites-enabled/product-app

echo -e "${GREEN}✓ Nginx configuration created${NC}"

# ============================================
# START SERVICES WITH PM2
# ============================================

echo ""
echo "Starting services..."

# Test nginx config
if $SUDO nginx -t; then
    echo -e "${GREEN}✓ Nginx configuration valid${NC}"
else
    echo -e "${RED}❌ Nginx configuration test failed${NC}"
    exit 1
fi

# Stop existing PM2 process if running
pm2 delete product-app 2>/dev/null || true

# Start application with PM2
pm2 start ecosystem.config.js

# Save PM2 process list
pm2 save

# Setup PM2 to start on system boot automatically
echo "Setting up PM2 startup on system boot..."
STARTUP_CMD=$(pm2 startup systemd -u $USER --hp $HOME | grep "sudo env")
if [ -n "$STARTUP_CMD" ]; then
    echo "Executing: $STARTUP_CMD"
    eval "$STARTUP_CMD" 2>/dev/null || echo -e "${BLUE}PM2 startup already configured${NC}"
fi
echo -e "${GREEN}✓ PM2 configured to start on system boot${NC}"
echo ""

# Restart nginx
$SUDO systemctl restart nginx

echo -e "${GREEN}✓ Services started${NC}"

# Check service status
sleep 2

# Check PM2 status
if pm2 list | grep -q "product-app.*online"; then
    echo -e "${GREEN}✓ Application is running with PM2${NC}"
else
    echo -e "${RED}❌ Application failed to start. Check: pm2 logs product-app${NC}"
    exit 1
fi

if $SUDO systemctl is-active --quiet nginx; then
    echo -e "${GREEN}✓ Nginx service is running${NC}"
else
    echo -e "${RED}❌ Nginx failed to start${NC}"
    exit 1
fi

echo ""

# ============================================
# PRODUCTION DEPLOYMENT SUMMARY
# ============================================

PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || echo "your-server-ip")

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ PRODUCTION DEPLOYMENT COMPLETED!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${BLUE}🌐 Access your application:${NC}"
echo "   http://$PUBLIC_IP"
echo "   http://localhost"
echo ""
echo -e "${BLUE}📊 PM2 Process Management:${NC}"
echo "   Status:    pm2 status"
echo "   List:      pm2 list"
echo "   Restart:   pm2 restart product-app"
echo "   Stop:      pm2 stop product-app"
echo "   Logs:      pm2 logs product-app"
echo "   Monitor:   pm2 monit"
echo ""
echo -e "${BLUE}🔧 Nginx Management:${NC}"
echo "   Restart:   sudo systemctl restart nginx"
echo "   Status:    sudo systemctl status nginx"
echo "   Logs:      sudo tail -f /var/log/nginx/product-app-access.log"
echo ""
echo -e "${BLUE}📝 Application Log Files:${NC}"
echo "   PM2 Logs:  $APP_ROOT/logs/"
echo "   Out:       pm2 logs product-app --out"
echo "   Error:     pm2 logs product-app --err"
echo ""
echo -e "${YELLOW}⚠️  AWS Security Group - Required ports:${NC}"
echo "   ✓ Port 22 (SSH)"
echo "   ✓ Port 80 (HTTP)"
echo "   ✓ Port 443 (HTTPS) - optional"
echo "   ✗ Port 3000 - DO NOT expose (internal only)"
echo ""
echo -e "${GREEN}🎉 Production deployment successful with PM2!${NC}"
echo -e "${BLUE}💡 PM2 will automatically restart your app on system reboot${NC}"
