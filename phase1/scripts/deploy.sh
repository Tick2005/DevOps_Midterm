#!/bin/bash

# ============================================
# PRODUCTION DEPLOYMENT SCRIPT
# ============================================
# This script deploys the application in production mode
# with full setup including systemd service and nginx reverse proxy.
#
# Usage:
#   ./deploy.sh              # Deploy in production mode

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
APP_ROOT="$(cd "$SCRIPT_DIR/../app" && pwd)"

# ============================================
# SET PRODUCTION MODE
# ============================================

MODE="production"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${CYAN}🚀 PRODUCT MANAGEMENT SYSTEM${NC}"
echo -e "${CYAN}   Mode: ${YELLOW}${MODE^^}${NC}"
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

load_env_file() {
    set +e
    set -a
    source "$ENV_FILE"
    local source_status=$?
    set +a
    set -e

    if [ $source_status -ne 0 ]; then
        echo -e "${RED}❌ Failed to load .env due to invalid syntax${NC}"
        echo -e "${YELLOW}⚠ Tip: wrap MongoDB URI in double quotes if it contains placeholders like <username>${NC}"
        return 1
    fi

    return 0
}

# ============================================
# FUNCTION: CREATE .ENV FILE INTERACTIVELY
# ============================================
create_env_file() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${CYAN}📝 Environment Configuration${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo -e "${BLUE}We need to set up your environment variables.${NC}"
    echo ""
    
    # MongoDB Atlas credentials
    echo -e "${YELLOW}MongoDB Atlas Setup:${NC}"
    echo "If you don't have MongoDB Atlas yet:"
    echo "  1. Visit: https://www.mongodb.com/cloud/atlas"
    echo "  2. Create free cluster (M0 tier - 512MB free)"
    echo "  3. Create database user"
    echo "  4. Whitelist IP: 0.0.0.0/0 (Network Access)"
    echo ""
    
    # Get MongoDB username
    read -p "MongoDB Username: " MONGO_USERNAME
    while [ -z "$MONGO_USERNAME" ]; do
        echo -e "${RED}Username cannot be empty!${NC}"
        read -p "MongoDB Username: " MONGO_USERNAME
    done
    
    # Get MongoDB password (hidden)
    echo -e "${YELLOW}(Password will be hidden)${NC}"
    read -rsp "MongoDB Password: " MONGO_PASSWORD
    echo ""
    while [ -z "$MONGO_PASSWORD" ]; do
        echo -e "${RED}Password cannot be empty!${NC}"
        read -rsp "MongoDB Password: " MONGO_PASSWORD
        echo ""
    done
    
    # Get cluster name
    read -p "Cluster Name (e.g., cluster0): " MONGO_CLUSTER
    while [ -z "$MONGO_CLUSTER" ]; do
        echo -e "${RED}Cluster name cannot be empty!${NC}"
        read -p "Cluster Name: " MONGO_CLUSTER
    done
    
    # Get database name
    read -p "Database Name [productdb]: " MONGO_DATABASE
    MONGO_DATABASE=${MONGO_DATABASE:-productdb}
    
    # Build MongoDB URI
    MONGODB_URI="mongodb+srv://${MONGO_USERNAME}:${MONGO_PASSWORD}@${MONGO_CLUSTER}.mongodb.net/${MONGO_DATABASE}?retryWrites=true&w=majority"
    
    echo ""
    echo -e "${CYAN}Configuration Summary:${NC}"
    echo "  Username: $MONGO_USERNAME"
    echo "  Cluster:  $MONGO_CLUSTER.mongodb.net"
    echo "  Database: $MONGO_DATABASE"
    echo ""
    
    # Get application port
    read -p "Application Port [3000]: " APP_PORT
    APP_PORT=${APP_PORT:-3000}
    
    # Get host binding (production settings)
    APP_HOST="0.0.0.0"
    APP_ENV="production"
    
    echo ""
    echo -e "${GREEN}Creating .env file...${NC}"
    
    # Create .env file
    cat > "$ENV_FILE" << EOF
# MongoDB Atlas Configuration
MONGODB_URI="$MONGODB_URI"
MONGO_URI="$MONGODB_URI"
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
# LOAD OR CREATE .ENV FILE
# ============================================

MONGO_PROMPTED=0

if [ ! -f "$ENV_FILE" ]; then
    echo -e "${YELLOW}⚠ .env file not found.${NC}"
    
    # Copy from .env.example if it exists
    if [ -f "$APP_ROOT/.env.example" ]; then
        echo "Creating .env from .env.example template..."
        cp "$APP_ROOT/.env.example" "$ENV_FILE"
        chmod 600 "$ENV_FILE"
        echo -e "${GREEN}✓ .env file created from template${NC}"
    else
        echo -e "${RED}❌ .env.example not found. Creating empty .env file...${NC}"
        touch "$ENV_FILE"
        chmod 600 "$ENV_FILE"
    fi
fi

# Detect unquoted MongoDB placeholders before sourcing .env
if grep -Eq '^[[:space:]]*(MONGODB_URI|MONGO_URI)=.*(<username>|<password>|<cluster>)' "$ENV_FILE"; then
    echo ""
    echo -e "${YELLOW}⚠ MongoDB URI is not configured yet${NC}"
    echo -e "${YELLOW}Current URI contains placeholders: <username>, <password>, <cluster>${NC}"
    echo ""
    read -p "Do you want to configure MongoDB now? (y/n): " -n 1 -r
    echo ""
    MONGO_PROMPTED=1
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        create_env_file
    else
        echo -e "${YELLOW}⚠ Continuing with current configuration...${NC}"
        echo -e "${YELLOW}⚠ Note: Application may not work properly without valid MongoDB credentials${NC}"
        echo -e "${YELLOW}⚠ You can configure it later by editing the .env file${NC}"
    fi
fi

# Load environment variables from .env
echo "📄 Loading environment variables from .env..."
if load_env_file; then
    echo -e "${GREEN}✓ Environment variables loaded${NC}"
else
    read -p "Do you want to configure MongoDB now? (y/n): " -n 1 -r
    echo ""
    MONGO_PROMPTED=1
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        create_env_file
        echo -e "${GREEN}✓ Environment variables loaded from updated .env${NC}"
    else
        echo -e "${YELLOW}⚠ Continuing without loading .env variables${NC}"
    fi
fi

# Check if MongoDB URI needs configuration
if [ -z "$MONGODB_URI" ] || [[ $MONGODB_URI == *"<username>"* ]] || [[ $MONGODB_URI == *"<password>"* ]] || [[ $MONGODB_URI == *"<cluster>"* ]]; then
    echo ""
    echo -e "${YELLOW}⚠ MongoDB URI is not configured yet${NC}"
    echo -e "${YELLOW}Current URI contains placeholders: <username>, <password>, <cluster>${NC}"
    echo ""
    if [ "$MONGO_PROMPTED" -eq 0 ]; then
        read -p "Do you want to configure MongoDB now? (y/n): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            create_env_file
        else
            echo -e "${YELLOW}⚠ Continuing with current configuration...${NC}"
            echo -e "${YELLOW}⚠ Note: Application may not work properly without valid MongoDB credentials${NC}"
            echo -e "${YELLOW}⚠ You can configure it later by editing the .env file${NC}"
        fi
    fi
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

# Install nginx
if ! command -v nginx &> /dev/null; then
    echo "Installing nginx..."
    install_package "nginx"
else
    echo -e "${GREEN}✓ Nginx already installed${NC}"
fi

echo ""
echo -e "${GREEN}✅ All dependencies installed!${NC}"
echo ""

# ============================================
# STEP 2: VERIFY MONGODB CONFIGURATION
# ============================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${CYAN}☁️  STEP 2: Verify MongoDB Configuration${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if MongoDB URI is valid
if [ -n "$MONGODB_URI" ] && [[ $MONGODB_URI == mongodb+srv://* ]] && [[ $MONGODB_URI != *"<username>"* ]] && [[ $MONGODB_URI != *"<password>"* ]] && [[ $MONGODB_URI != *"<cluster>"* ]]; then
    echo -e "${GREEN}✓ MongoDB Atlas URI configured${NC}"
    # Hide password in display
    DISPLAY_URI=$(echo "$MONGODB_URI" | sed 's/:\/\/[^:]*:[^@]*@/:\/\/***:***@/')
    echo "   URI: $DISPLAY_URI"
    echo ""
    echo -e "${YELLOW}⚠️  Important MongoDB Atlas Checklist:${NC}"
    echo "   1. Database User exists with correct password"
    echo "   2. Network Access: IP whitelist includes your IP or 0.0.0.0/0"
    echo "   3. Cluster name is correct (including subdomain)"
    echo ""
else
    echo -e "${YELLOW}⚠️  MongoDB URI contains placeholders or is not configured${NC}"
    echo ""
    read -p "Do you want to configure MongoDB now? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        create_env_file
        # Reload the new configuration
        set -a
        source "$ENV_FILE"
        set +a
        echo ""
        echo -e "${GREEN}✓ MongoDB configuration updated${NC}"
    else
        echo -e "${YELLOW}⚠️  Continuing with current configuration...${NC}"
        echo -e "${YELLOW}⚠️  Note: Application may not work properly without valid MongoDB credentials${NC}"
    fi
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
else
    echo -e "${GREEN}✓ .gitignore already exists${NC}"
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
# PRODUCTION MODE - SYSTEMD + NGINX
# ============================================
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${CYAN}🔧 Production Deployment${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Create configs directory if doesn't exist
    CONFIGS_DIR="$APP_ROOT/configs"
    if [ ! -d "$CONFIGS_DIR" ]; then
        mkdir -p "$CONFIGS_DIR"
        echo -e "${GREEN}✓ Created configs directory${NC}"
    fi
    
    # ============================================
    # CREATE SYSTEMD SERVICE FILE
    # ============================================
    
    echo "Setting up systemd service..."
    
    cat > "$CONFIGS_DIR/product-app.service" << EOF
[Unit]
Description=Product Management Node.js Application
Documentation=https://github.com/yourrepo/product-management
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$APP_ROOT
ExecStart=$(which node) $APP_ROOT/main.js

# Auto restart on failure
Restart=always
RestartSec=10

# Environment variables
Environment=NODE_ENV=production
Environment=PORT=3000
Environment=HOST=0.0.0.0

# Load additional variables from .env file
EnvironmentFile=$APP_ROOT/.env

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=product-app

# Security hardening
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
    
    # Copy to systemd
    $SUDO cp "$CONFIGS_DIR/product-app.service" /etc/systemd/system/product-app.service
    echo -e "${GREEN}✓ Systemd service created${NC}"
    
    # ============================================
    # CREATE NGINX CONFIGURATION
    # ============================================
    
    echo "Setting up nginx configuration..."
    
    cat > "$CONFIGS_DIR/nginx.conf" << EOF
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
        proxy_pass http://localhost:3000;
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
        proxy_pass http://localhost:3000;
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
    $SUDO cp "$CONFIGS_DIR/nginx.conf" /etc/nginx/sites-available/product-app
    
    # Remove default site
    if [ -f /etc/nginx/sites-enabled/default ]; then
        $SUDO rm /etc/nginx/sites-enabled/default
    fi
    
    # Enable site
    $SUDO ln -sf /etc/nginx/sites-available/product-app /etc/nginx/sites-enabled/product-app
    
    echo -e "${GREEN}✓ Nginx configuration created${NC}"
    
    # ============================================
    # START SERVICES
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
    
    # Reload systemd
    $SUDO systemctl daemon-reload
    
    # Enable and start app service
    $SUDO systemctl enable product-app
    $SUDO systemctl restart product-app
    
    # Restart nginx
    $SUDO systemctl restart nginx
    
    echo -e "${GREEN}✓ Services started${NC}"
    
    # Check service status
    sleep 2
    if $SUDO systemctl is-active --quiet product-app; then
        echo -e "${GREEN}✓ Application service is running${NC}"
    else
        echo -e "${RED}❌ Service failed to start. Check: sudo journalctl -u product-app -n 50${NC}"
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
    echo -e "${BLUE}📊 Service Management:${NC}"
    echo "   Status:    sudo systemctl status product-app"
    echo "   Restart:   sudo systemctl restart product-app"
    echo "   Logs:      sudo journalctl -u product-app -f"
    echo "   Nginx:     sudo systemctl restart nginx"
    echo ""
    echo -e "${BLUE}📝 Log Files:${NC}"
    echo "   App:       sudo journalctl -u product-app"
    echo "   Nginx:     sudo tail -f /var/log/nginx/product-app-access.log"
    echo ""
    echo -e "${YELLOW}⚠️  AWS Security Group - Required ports:${NC}"
    echo "   ✓ Port 22 (SSH)"
    echo "   ✓ Port 80 (HTTP)"
    echo "   ✓ Port 443 (HTTPS) - optional"
    echo "   ✗ Port 3000 - DO NOT expose (internal only)"
    echo ""
    echo -e "${GREEN}🎉 Production deployment successful!${NC}"
