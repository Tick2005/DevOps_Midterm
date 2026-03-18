#!/bin/bash

# ============================================
# SETUP & START AUTOMATION SCRIPT
# ============================================
# This script installs dependencies, configures database,
# and starts the Node.js application
# For Product Management System Deployment

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="$SCRIPT_DIR"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 PRODUCT MANAGEMENT SYSTEM - AUTO SETUP"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📍 Application root: $APP_ROOT"
echo ""

# Navigate to app root
if [ ! -d "$APP_ROOT" ]; then
    echo "❌ Error: App root not found at $APP_ROOT"
    exit 1
fi

cd "$APP_ROOT"
echo "✓ Working directory: $(pwd)"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ============================================
# LOAD ENVIRONMENT VARIABLES FROM .env
# ============================================

ENV_FILE="$APP_ROOT/.env"

if [ -f "$ENV_FILE" ]; then
    echo "📄 Loading environment variables from .env..."
    set -a
    source "$ENV_FILE"
    set +a
    echo -e "${GREEN}✓ Environment variables loaded${NC}"
else
    echo -e "${YELLOW}⚠ .env file not found. Creating from template...${NC}"
    
    # Check if .env.example exists
    if [ ! -f "$APP_ROOT/.env.example" ]; then
        echo -e "${RED}❌ Error: .env.example not found${NC}"
        exit 1
    fi
    
    cp "$APP_ROOT/.env.example" "$ENV_FILE"
    echo -e "${GREEN}✓ Created .env file from template${NC}"
    
    # Load the new .env file
    set -a
    source "$ENV_FILE"
    set +a
fi

# Set defaults if not in .env
PORT="${PORT:-3000}"
DATA_SOURCE="mongodb"  # Always use MongoDB Atlas
MONGODB_URI="${MONGODB_URI:-}"

echo ""
echo "⚙️  Configuration:"
echo "   Port: $PORT"
echo "   Data Source: MongoDB Atlas (Cloud Database)"
if [ -n "$MONGODB_URI" ] && [[ $MONGODB_URI == mongodb+srv://* ]] && [[ $MONGODB_URI != *"<username>"* ]]; then
    echo "   MongoDB URI: $MONGODB_URI"
fi
echo ""

# ============================================
# STEP 1: CHECK AND INSTALL PREREQUISITES
# ============================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 STEP 1: Installing Dependencies"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
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

echo "Detected OS: $OS (Package manager: $PKG_MANAGER)"
echo ""

# Function to install packages
install_package() {
    local package=$1
    
    # Check if already installed
    if command -v "$package" &> /dev/null 2>&1 || dpkg -s "$package" &> /dev/null 2>&1; then
        echo -e "${GREEN}✓ $package is already installed${NC}"
        return 0
    fi
    
    echo "Installing $package..."
    
    if [ "$PKG_MANAGER" == "apt" ]; then
        sudo apt update -qq && sudo apt install -y "$package"
    elif [ "$PKG_MANAGER" == "yum" ]; then
        sudo yum install -y "$package"
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

# Install Basic Tools
echo -n "Checking curl... "
install_package "curl"

echo -n "Checking git... "
install_package "git"

# Check Node.js
echo -n "Checking Node.js... "
NODE_INSTALLED=false

if command -v node &> /dev/null; then
    NODE_VERSION=$(node -v)
    echo -e "${GREEN}✓ Found ($NODE_VERSION)${NC}"
    NODE_INSTALLED=true
else
    echo -e "${YELLOW}✗ Not found${NC}"
fi

# Install Node.js if not present
if [ "$NODE_INSTALLED" = false ]; then
    echo "Installing Node.js 20.x LTS..."
    if [ "$PKG_MANAGER" == "apt" ]; then
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
        install_package "nodejs"
    elif [ "$PKG_MANAGER" == "yum" ]; then
        curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
        install_package "nodejs"
    elif [ "$PKG_MANAGER" == "brew" ]; then
        install_package "node"
    fi
    
    # Verify installation
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node -v)
        echo -e "${GREEN}✓ Node.js $NODE_VERSION installed${NC}"
    else
        echo -e "${RED}❌ Failed to install Node.js${NC}"
        exit 1
    fi
fi

# Check npm
echo -n "Checking npm... "
if command -v npm &> /dev/null; then
    NPM_VERSION=$(npm -v)
    echo -e "${GREEN}✓ Found (npm $NPM_VERSION)${NC}"
else
    echo -e "${RED}❌ npm not found (should come with Node.js)${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ All dependencies verified!${NC}"
echo ""

# ============================================
# STEP 2: MONGODB ATLAS CONFIGURATION (REQUIRED)
# ============================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "☁️  STEP 2: MongoDB Atlas Configuration (Required)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo -e "${CYAN}This application requires MongoDB Atlas (Cloud Database)${NC}"
echo ""

# Check if MONGODB_URI is already configured and valid
MONGODB_URI_VALID=false

if [ -n "$MONGODB_URI" ] && [[ $MONGODB_URI == mongodb+srv://* ]] && [[ $MONGODB_URI != *"<username>"* ]] && [[ $MONGODB_URI != *"<password>"* ]] && [[ $MONGODB_URI != *"<cluster>"* ]]; then
    # URI looks valid
    echo -e "${GREEN}✓ MongoDB Atlas URI already configured${NC}"
    echo "   Full URI: $MONGODB_URI"
    echo ""
    echo -e "${YELLOW}⚠️  If connection fails, check these on MongoDB Atlas:${NC}"
    echo "   1. Network Access: Whitelist your IP (0.0.0.0/0 for all IPs)"
    echo "   2. Database User: Verify username and password are correct"
    echo "   3. Cluster Name: Make sure it matches exactly (e.g., cluster0.ahaubn2)"
    echo ""
    
    MONGODB_URI_VALID=true
else
    # If not configured, ask user for credentials
    echo -e "${YELLOW}⚠ MongoDB Atlas credentials required${NC}"
    echo ""
    echo -e "${BLUE}📝 How to get MongoDB Atlas credentials:${NC}"
    echo "   1. Go to https://www.mongodb.com/cloud/atlas"
    echo "   2. Sign up/Login (Free tier M0 available - 512MB)"
    echo "   3. Create a cluster (Choose M0 Free tier)"
    echo "   4. Create Database User:"
    echo "      - Go to: Database Access > Add New Database User"
    echo "      - Set username and password"
    echo "      - Grant 'Read and write to any database' permission"
    echo "   5. Whitelist IP:"
    echo "      - Go to: Network Access > Add IP Address"
    echo "      - Choose: Allow Access from Anywhere (0.0.0.0/0)"
    echo "   6. Get cluster name:"
    echo "      - Go to: Database > Clusters"
    echo "      - Your cluster name (e.g., cluster0, cluster1)"
    echo ""
    
    # Loop until valid credentials are provided
    while [ "$MONGODB_URI_VALID" = false ]; do
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${CYAN}Enter MongoDB Atlas Credentials:${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        # Ask for username
        read -p "MongoDB Username: " MONGO_USERNAME
        
        if [ -z "$MONGO_USERNAME" ]; then
            echo ""
            echo -e "${RED}❌ Username cannot be empty${NC}"
            echo ""
            read -p "Press Enter to try again..." -r
            echo ""
            continue
        fi
        
        # Ask for password (hidden input)
        echo -e "${YELLOW}(Password will be hidden for security)${NC}"
        read -rsp "MongoDB Password: " MONGO_PASSWORD
        echo ""
        
        if [ -z "$MONGO_PASSWORD" ]; then
            echo ""
            echo -e "${RED}❌ Password cannot be empty${NC}"
            echo ""
            read -p "Press Enter to try again..." -r
            echo ""
            continue
        fi
        
        # Ask for cluster name
        read -p "Cluster Name (e.g., cluster0): " MONGO_CLUSTER
        
        if [ -z "$MONGO_CLUSTER" ]; then
            echo ""
            echo -e "${RED}❌ Cluster name cannot be empty${NC}"
            echo ""
            read -p "Press Enter to try again..." -r
            echo ""
            continue
        fi
        
        # Ask for database name (default: productdb)
        read -p "Database Name [productdb]: " MONGO_DATABASE
        MONGO_DATABASE=${MONGO_DATABASE:-productdb}
        
        echo ""
        
        # Build MongoDB Atlas connection string
        MONGODB_URI="mongodb+srv://${MONGO_USERNAME}:${MONGO_PASSWORD}@${MONGO_CLUSTER}.mongodb.net/${MONGO_DATABASE}?retryWrites=true&w=majority"
        
        echo -e "${GREEN}✓ MongoDB Atlas connection string created${NC}"
        echo ""
        echo -e "${CYAN}Please verify your connection details:${NC}"
        echo "   Username: $MONGO_USERNAME"
        echo "   Password: $MONGO_PASSWORD"
        echo "   Cluster:  $MONGO_CLUSTER.mongodb.net"
        echo "   Database: $MONGO_DATABASE"
        echo "   Full URI: $MONGODB_URI"
        echo ""
        echo -e "${YELLOW}⚠️  Important: Make sure you have completed these steps on MongoDB Atlas:${NC}"
        echo "   1. Database User exists with correct password"
        echo "   2. Network Access allows your IP (recommend: 0.0.0.0/0 for testing)"
        echo "   3. Cluster name is correct (including the subdomain like 'cluster0.ahaubn2')"
        echo ""
        
        # Confirm with user
        read -p "Is this information correct? (y/n): " -n 1 -r
        echo ""
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Save to .env file
            if grep -q "^MONGODB_URI=" "$ENV_FILE" 2>/dev/null; then
                sed -i "s|^MONGODB_URI=.*|MONGODB_URI=$MONGODB_URI|" "$ENV_FILE" 2>/dev/null || \
                sed -i '' "s|^MONGODB_URI=.*|MONGODB_URI=$MONGODB_URI|" "$ENV_FILE" 2>/dev/null
            else
                echo "MONGODB_URI=$MONGODB_URI" >> "$ENV_FILE"
            fi
            
            # Update DATA_SOURCE to mongodb
            if grep -q "^DATA_SOURCE=" "$ENV_FILE" 2>/dev/null; then
                sed -i "s|^DATA_SOURCE=.*|DATA_SOURCE=mongodb|" "$ENV_FILE" 2>/dev/null || \
                sed -i '' "s|^DATA_SOURCE=.*|DATA_SOURCE=mongodb|" "$ENV_FILE" 2>/dev/null
            else
                echo "DATA_SOURCE=mongodb" >> "$ENV_FILE"
            fi
            
            echo ""
            echo -e "${GREEN}✓ MongoDB Atlas credentials saved to .env${NC}"
            echo ""
            
            MONGODB_URI_VALID=true
        else
            echo ""
            echo -e "${YELLOW}Let's try again...${NC}"
            echo ""
        fi
    done
fi

echo -e "${GREEN}✅ MongoDB Atlas configured successfully!${NC}"
echo ""

# ============================================
# STEP 3: APPLICATION CONFIGURATION
# ============================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⚙️  STEP 3: Application Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Create .gitignore if not exists
if [ ! -f ".gitignore" ]; then
    echo -n "Creating .gitignore... "
    cat > .gitignore << 'EOF'
.env
node_modules/
public/uploads/*
!public/uploads/.gitkeep
*.log
.DS_Store
EOF
    echo -e "${GREEN}✓${NC}"
elif ! grep -q "^\.env$" .gitignore 2>/dev/null; then
    echo -n "Adding .env to .gitignore... "
    echo ".env" >> .gitignore
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${GREEN}✓ .gitignore configured${NC}"
fi

# Create uploads directory
if [ ! -d "public/uploads" ]; then
    echo -n "Creating uploads directory... "
    mkdir -p "public/uploads"
    touch "public/uploads/.gitkeep"
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${GREEN}✓ Uploads directory exists${NC}"
fi

# Install npm dependencies
if [ ! -d "node_modules" ]; then
    echo -n "Installing dependencies... "
    npm install --silent
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Failed to install dependencies${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Dependencies installed successfully${NC}"
else
    echo -e "${GREEN}✓ Dependencies already installed${NC}"
fi

echo ""
echo -e "${GREEN}✅ Application configured!${NC}"
echo ""

# ============================================
# STEP 4: START APPLICATION
# ============================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 STEP 4: Starting Application"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Display final configuration
echo -e "${BLUE}📋 Final Configuration:${NC}"
echo "   Port:        $PORT"
echo "   Data Source: $DATA_SOURCE"
if [ "$DATA_SOURCE" == "mongodb" ]; then
    echo "   MongoDB:     MongoDB Atlas (Cloud)"
    echo "   URI:         $MONGODB_URI"
fi
echo ""

# Get server IP
if command -v curl &> /dev/null; then
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "localhost")
else
    SERVER_IP="localhost"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ SETUP COMPLETED!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${BLUE}🌐 Access your application at:${NC}"
echo "   Local:  http://localhost:$PORT"
if [ "$SERVER_IP" != "localhost" ]; then
    echo "   Remote: http://$SERVER_IP:$PORT"
fi
echo ""
echo -e "${GREEN}✨ Starting application...${NC}"
echo ""

# Start the application
npm start
