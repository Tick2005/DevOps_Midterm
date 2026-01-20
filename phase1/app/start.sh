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
if [ -n "$MONGODB_URI" ] && [[ $MONGODB_URI != mongodb+srv://* ]] && [[ $MONGODB_URI != *"<username>"* ]]; then
    # Hide password in display
    SAFE_URI=$(echo "$MONGODB_URI" | sed 's|://[^:]*:[^@]*@|://***:***@|')
    echo "   MongoDB: $SAFE_URI"
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

# Check if MONGODB_URI is set and valid
MONGODB_URI_VALID=false

while [ "$MONGODB_URI_VALID" = false ]; do
    # Check if URI is configured and not a template
    if [ -n "$MONGODB_URI" ] && [[ $MONGODB_URI == mongodb+srv://* ]] && [[ $MONGODB_URI != *"<username>"* ]] && [[ $MONGODB_URI != *"<password>"* ]] && [[ $MONGODB_URI != *"<cluster>"* ]]; then
        # URI looks valid
        echo -e "${GREEN}✓ MongoDB Atlas URI configured${NC}"
        
        # Hide password in display
        SAFE_URI=$(echo "$MONGODB_URI" | sed 's|://[^:]*:[^@]*@|://***:***@|')
        echo "   URI: $SAFE_URI"
        echo ""
        echo -e "${BLUE}💡 Tip: Make sure to whitelist your IP address in MongoDB Atlas${NC}"
        echo "   Network Access > Add IP Address > Allow Access from Anywhere (0.0.0.0/0)"
        echo ""
        
        MONGODB_URI_VALID=true
    else
        # URI not configured or invalid
        if [ -n "$MONGODB_URI" ] && [[ $MONGODB_URI != *"<username>"* ]]; then
            echo -e "${RED}❌ Invalid MongoDB Atlas connection string format${NC}"
            echo ""
        fi
        
        echo -e "${YELLOW}⚠ MongoDB Atlas connection string is required${NC}"
        echo ""
        echo -e "${BLUE}📝 How to get MongoDB Atlas connection string:${NC}"
        echo "   1. Go to https://www.mongodb.com/cloud/atlas"
        echo "   2. Sign up/Login (Free tier M0 available - 512MB)"
        echo "   3. Create a new cluster (Choose M0 Free tier)"
        echo "   4. Create a Database User (Database Access > Add New User)"
        echo "   5. Whitelist IP (Network Access > Add IP > 0.0.0.0/0 for all)"
        echo "   6. Get Connection String:"
        echo "      - Click 'Connect' on your cluster"
        echo "      - Choose 'Connect your application'"
        echo "      - Copy the connection string"
        echo "      - Replace <password> with your actual password"
        echo "      - Replace <dbname> with 'productdb' (or your database name)"
        echo ""
        echo -e "${YELLOW}Required format:${NC}"
        echo "   mongodb+srv://<username>:<password>@cluster0.xxxxx.mongodb.net/productdb"
        echo ""
        echo -e "${YELLOW}Example:${NC}"
        echo "   mongodb+srv://myuser:MyP@ssw0rd@cluster0.mongodb.net/productdb"
        echo ""
        
        echo -e "${CYAN}Please enter your MongoDB Atlas connection string:${NC}"
        read -r ATLAS_URI
        
        # Validate URI format
        if [ -z "$ATLAS_URI" ]; then
            echo ""
            echo -e "${RED}❌ Connection string cannot be empty${NC}"
            echo ""
            read -p "Press Enter to try again..." -r
            echo ""
            continue
        fi
        
        if [[ $ATLAS_URI != mongodb+srv://* ]] && [[ $ATLAS_URI != mongodb://* ]]; then
            echo ""
            echo -e "${RED}❌ Invalid format. Must start with 'mongodb+srv://' or 'mongodb://'${NC}"
            echo ""
            read -p "Press Enter to try again..." -r
            echo ""
            continue
        fi
        
        if [[ $ATLAS_URI == *"<username>"* ]] || [[ $ATLAS_URI == *"<password>"* ]] || [[ $ATLAS_URI == *"<cluster>"* ]]; then
            echo ""
            echo -e "${RED}❌ Please replace placeholders (<username>, <password>, <cluster>) with actual values${NC}"
            echo ""
            read -p "Press Enter to try again..." -r
            echo ""
            continue
        fi
        
        # URI is valid, save it
        MONGODB_URI="$ATLAS_URI"
        
        # Update .env file
        if grep -q "^MONGODB_URI=" "$ENV_FILE" 2>/dev/null; then
            sed -i "s|^MONGODB_URI=.*|MONGODB_URI=$ATLAS_URI|" "$ENV_FILE" 2>/dev/null || \
            sed -i '' "s|^MONGODB_URI=.*|MONGODB_URI=$ATLAS_URI|" "$ENV_FILE" 2>/dev/null
        else
            echo "MONGODB_URI=$ATLAS_URI" >> "$ENV_FILE"
        fi
        
        # Update DATA_SOURCE to mongodb
        if grep -q "^DATA_SOURCE=" "$ENV_FILE" 2>/dev/null; then
            sed -i "s|^DATA_SOURCE=.*|DATA_SOURCE=mongodb|" "$ENV_FILE" 2>/dev/null || \
            sed -i '' "s|^DATA_SOURCE=.*|DATA_SOURCE=mongodb|" "$ENV_FILE" 2>/dev/null
        else
            echo "DATA_SOURCE=mongodb" >> "$ENV_FILE"
        fi
        
        echo ""
        echo -e "${GREEN}✓ MongoDB Atlas URI saved to .env${NC}"
        echo ""
        
        MONGODB_URI_VALID=true
    fi
done

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

# Install npm dependenMongoDB Atlas (Cloud Database)"
SAFE_URI=$(echo "$MONGODB_URI" | sed 's|://[^:]*:[^@]*@|://***:***@|')
echo "   MongoDB URI: $SAFE_URI"  npm install --silent
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Dependencies installed successfully${NC}"
    else
        echo -e "${RED}❌ Failed to install dependencies${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✓ Already installed${NC}"
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
    SAFE_URI=$(echo "$MONGODB_URI" | sed 's|://[^:]*:[^@]*@|://***:***@|')
    echo "   MongoDB:     MongoDB Atlas (Cloud)"
    echo "   URI:         $SAFE_URI"
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
