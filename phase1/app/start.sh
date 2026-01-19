#!/bin/bash
# ========================================
# Automation Script - Complete Setup & Start
# ========================================

echo "========================================"
echo "  Application Auto Setup & Start"
echo "========================================"
echo ""

# Function to install Node.js
install_nodejs() {
    echo "[INFO] Installing Node.js..."
    
    # Check if running on Ubuntu/Debian
    if command -v apt-get &> /dev/null; then
        # Install Node.js 20.x LTS
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
        sudo apt-get install -y nodejs
        
        if [ $? -eq 0 ]; then
            echo "[OK] Node.js installed successfully"
            node --version
            npm --version
            return 0
        else
            echo "[ERROR] Failed to install Node.js"
            return 1
        fi
    else
        echo "[ERROR] Automatic installation only supported on Ubuntu/Debian"
        echo "[INFO] Please install Node.js manually from: https://nodejs.org/"
        return 1
    fi
}

# Function to install MongoDB
install_mongodb() {
    echo "[INFO] Installing MongoDB Community Edition 7.0..."
    
    # Install prerequisites
    sudo apt-get install -y gnupg curl wget
    
    # Import MongoDB GPG key
    curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | \
        sudo gpg --dearmor -o /usr/share/keyrings/mongodb-server-7.0.gpg
    
    # Detect Ubuntu version and add repository
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "$VERSION_ID" =~ ^(22\.04|23\.|24\.) ]]; then
            UBUNTU_CODENAME="jammy"
        else
            UBUNTU_CODENAME="focal"
        fi
    else
        UBUNTU_CODENAME="jammy"
    fi
    
    echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu $UBUNTU_CODENAME/mongodb-org/7.0 multiverse" | \
        sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
    
    # Update and install MongoDB
    sudo apt-get update
    sudo apt-get install -y mongodb-org
    
    if [ $? -eq 0 ]; then
        echo "[OK] MongoDB installed successfully"
        
        # Start and enable MongoDB
        sudo systemctl start mongod
        sudo systemctl enable mongod
        echo "[OK] MongoDB service started and enabled"
        return 0
    else
        echo "[ERROR] Failed to install MongoDB"
        return 1
    fi
}

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "[WARNING] Node.js is not installed"
    read -p "Do you want to install Node.js automatically? (y/n): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        install_nodejs
        if [ $? -ne 0 ]; then
            exit 1
        fi
    else
        echo "[ERROR] Node.js is required to run this application"
        exit 1
    fi
else
    echo "[OK] Node.js is installed"
    node --version
fi
echo ""

# Check if npm is installed
if ! command -v npm &> /dev/null; then
    echo "[ERROR] npm is not installed"
    echo "[INFO] npm should come with Node.js. Please reinstall Node.js"
    exit 1
fi

echo "[OK] npm is installed"
npm --version
echo ""

# Check if node_modules exists
if [ ! -d "node_modules" ]; then
    echo "[INFO] node_modules not found. Installing dependencies..."
    npm install
    if [ $? -ne 0 ]; then
        echo "[ERROR] Failed to install dependencies"
        exit 1
    fi
    echo "[OK] Dependencies installed successfully"
    echo ""
else
    echo "[OK] Dependencies already installed"
    echo ""
fi

# Check and install MongoDB
MONGODB_INSTALLED=false
MONGODB_RUNNING=false

if command -v mongod &> /dev/null; then
    MONGODB_INSTALLED=true
    echo "[OK] MongoDB is installed"
    
    # Check if MongoDB is running
    if systemctl is-active --quiet mongod 2>/dev/null || pgrep -x mongod > /dev/null 2>&1; then
        MONGODB_RUNNING=true
        echo "[OK] MongoDB is running"
    else
        echo "[WARNING] MongoDB is installed but not running"
        echo "[INFO] Starting MongoDB..."
        
        if command -v systemctl &> /dev/null; then
            sudo systemctl start mongod 2>/dev/null
            if [ $? -eq 0 ]; then
                echo "[OK] MongoDB started successfully"
                MONGODB_RUNNING=true
            else
                echo "[ERROR] Failed to start MongoDB"
            fi
        fi
    fi
else
    echo "[WARNING] MongoDB is not installed"
    read -p "Do you want to install MongoDB automatically? (y/n): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        install_mongodb
        if [ $? -eq 0 ]; then
            MONGODB_INSTALLED=true
            MONGODB_RUNNING=true
        else
            echo "[WARNING] Failed to install MongoDB, will use file-based storage"
        fi
    else
        echo "[INFO] Skipping MongoDB installation"
    fi
fi
echo ""

# Create .env.example if it doesn't exist
if [ ! -f ".env.example" ]; then
    echo "[INFO] Creating .env.example file..."
    cat > .env.example << 'EOF'
# Application Configuration Example
# Copy this file to .env and modify as needed

# Server Port
PORT=3000

# MongoDB Configuration
MONGODB_URI=mongodb://localhost:27017/productdb

# Data Source: 'file' or 'mongodb'
# Use 'mongodb' for production, 'file' for development without MongoDB
DATA_SOURCE=mongodb

# Node Environment
NODE_ENV=development
EOF
    echo "[OK] .env.example created"
fi

# Configure .env file
if [ ! -f ".env" ]; then
    echo "[INFO] Creating .env file from template..."
    
    # Set DATA_SOURCE based on MongoDB availability
    if [ "$MONGODB_RUNNING" = true ]; then
        DATA_SOURCE_VALUE="mongodb"
        echo "[INFO] Configuring application to use MongoDB"
    else
        DATA_SOURCE_VALUE="file"
        echo "[INFO] Configuring application to use file-based storage"
    fi
    
    cat > .env << EOF
PORT=3000
MONGODB_URI=mongodb://localhost:27017/productdb
DATA_SOURCE=$DATA_SOURCE_VALUE
NODE_ENV=development
EOF
    echo "[OK] .env file created (DATA_SOURCE=$DATA_SOURCE_VALUE)"
else
    echo "[OK] .env file already exists"
    
    # Update DATA_SOURCE if MongoDB status changed
    if [ "$MONGODB_RUNNING" = true ]; then
        if ! grep -q "DATA_SOURCE=mongodb" .env 2>/dev/null; then
            echo "[INFO] Updating .env to use MongoDB..."
            sed -i 's/DATA_SOURCE=.*/DATA_SOURCE=mongodb/' .env 2>/dev/null || \
            sed -i '' 's/DATA_SOURCE=.*/DATA_SOURCE=mongodb/' .env 2>/dev/null
        fi
    fi
fi
echo ""

# Add .env to .gitignore if not already there
if [ -f ".gitignore" ]; then
    if ! grep -q "^\.env$" .gitignore 2>/dev/null; then
        echo ".env" >> .gitignore
        echo "[OK] Added .env to .gitignore"
    fi
elif [ ! -f ".gitignore" ]; then
    echo ".env" > .gitignore
    echo "node_modules/" >> .gitignore
    echo "public/uploads/*" >> .gitignore
    echo "!public/uploads/.gitkeep" >> .gitignore
    echo "[OK] Created .gitignore file"
fi

# Crea"
echo "========================================"
echo "  Starting Application"
echo "========================================"
echo ""
echo "Configuration:"
echo "  - Port: $(grep PORT .env | cut -d '=' -f2)"
echo "  - Data Source: $(grep DATA_SOURCE .env | cut -d '=' -f2)"
if [ "$MONGODB_RUNNING" = true ]; then
    echo "  - MongoDB: Running on localhost:27017"
fi
echo ""
echo "Application will be available at: http://localhost:$(grep PORT .env | cut -d '=' -f2 | tr -d '[:space:]')sn't exist
if [ ! -d "public/uploads" ]; then
    echo "[INFO] Creating uploads directory..."
    mkdir -p "public/uploads"
    echo "[OK] Uploads directory created"
    echo ""
fi

echo "[INFO] Starting application..."
echo "========================================"
echo ""

# Start the application
npm start
