#!/bin/bash
# ========================================
# MongoDB Installation Script for Ubuntu
# ========================================

echo "========================================"
echo "  MongoDB Installation Script"
echo "========================================"
echo ""

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then 
    echo "[INFO] This script requires sudo privileges"
    echo "[INFO] You may be prompted for your password"
    echo ""
fi

# Check if MongoDB is already installed
if command -v mongod &> /dev/null; then
    MONGO_VERSION=$(mongod --version | grep "db version" | head -1)
    echo "[INFO] MongoDB is already installed: $MONGO_VERSION"
    
    # Check if MongoDB is running
    if systemctl is-active --quiet mongod 2>/dev/null; then
        echo "[OK] MongoDB is running"
    else
        echo "[WARNING] MongoDB is not running"
        read -p "Do you want to start MongoDB? (y/n): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo systemctl start mongod
            sudo systemctl enable mongod
            echo "[OK] MongoDB started and enabled"
        fi
    fi
    
    echo ""
    echo "MongoDB Status:"
    sudo systemctl status mongod --no-pager -l
    exit 0
fi

echo "[INFO] MongoDB is not installed. Starting installation..."
echo ""

# Detect OS
if [ ! -f /etc/os-release ]; then
    echo "[ERROR] Cannot detect OS version"
    exit 1
fi

. /etc/os-release
echo "[INFO] Detected OS: $NAME $VERSION"
echo ""

# Check if Ubuntu
if [[ "$ID" != "ubuntu" ]]; then
    echo "[WARNING] This script is designed for Ubuntu"
    read -p "Do you want to continue anyway? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Install prerequisites
echo "[INFO] Installing prerequisites..."
sudo apt-get install -y curl gnupg wget

if [ $? -ne 0 ]; then
    echo "[ERROR] Failed to install prerequisites"
    exit 1
fi

echo "[OK] Prerequisites installed"
echo ""

# Import MongoDB public GPG key
echo "[INFO] Importing MongoDB GPG key..."
curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | \
    sudo gpg --dearmor -o /usr/share/keyrings/mongodb-server-7.0.gpg

if [ $? -ne 0 ]; then
    echo "[ERROR] Failed to import MongoDB GPG key"
    exit 1
fi

echo "[OK] MongoDB GPG key imported"
echo ""

# Create MongoDB list file based on Ubuntu version
echo "[INFO] Creating MongoDB repository list..."

# Use jammy (22.04) repo for Ubuntu 22.04 and newer
if [[ "$VERSION_ID" =~ ^(22\.04|23\.|24\.) ]]; then
    UBUNTU_CODENAME="jammy"
else
    UBUNTU_CODENAME="focal"
fi

echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu $UBUNTU_CODENAME/mongodb-org/7.0 multiverse" | \
    sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list

echo "[OK] MongoDB repository added"
echo ""

# Update package list
echo "[INFO] Updating package list..."
sudo apt-get update

if [ $? -ne 0 ]; then
    echo "[ERROR] Failed to update package list"
    exit 1
fi

echo "[OK] Package list updated"
echo ""

# Install MongoDB
echo "[INFO] Installing MongoDB Community Edition 7.0..."
echo "[INFO] This may take a few minutes..."
sudo apt-get install -y mongodb-org

if [ $? -ne 0 ]; then
    echo "[ERROR] Failed to install MongoDB"
    exit 1
fi

echo "[OK] MongoDB installed successfully"
echo ""

# Start MongoDB service
echo "[INFO] Starting MongoDB service..."
sudo systemctl daemon-reload
sudo systemctl start mongod

if [ $? -ne 0 ]; then
    echo "[WARNING] Failed to start MongoDB automatically"
    echo "[INFO] You may need to start it manually with: sudo systemctl start mongod"
else
    echo "[OK] MongoDB service started"
fi

# Enable MongoDB to start on boot
echo "[INFO] Enabling MongoDB to start on boot..."
sudo systemctl enable mongod

if [ $? -eq 0 ]; then
    echo "[OK] MongoDB enabled on boot"
fi

echo ""
echo "========================================"
echo "  MongoDB Installation Complete!"
echo "========================================"
echo ""

# Display MongoDB status
echo "MongoDB Status:"
sudo systemctl status mongod --no-pager -l
echo ""

# Display MongoDB version
if command -v mongod &> /dev/null; then
    echo "Installed MongoDB Version:"
    mongod --version | grep "db version"
    echo ""
fi

# Display useful commands
echo "========================================"
echo "  Useful MongoDB Commands"
echo "========================================"
echo ""
echo "Check status:    sudo systemctl status mongod"
echo "Start service:   sudo systemctl start mongod"
echo "Stop service:    sudo systemctl stop mongod"
echo "Restart service: sudo systemctl restart mongod"
echo "Connect to DB:   mongosh"
echo ""
echo "MongoDB is now listening on: localhost:27017"
echo "Data directory: /var/lib/mongodb"
echo "Log file: /var/log/mongodb/mongod.log"
echo ""

# Check if mongosh is installed
if ! command -v mongosh &> /dev/null; then
    echo "[INFO] MongoDB Shell (mongosh) is not installed"
    read -p "Do you want to install MongoDB Shell? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "[INFO] Installing mongosh..."
        sudo apt-get install -y mongodb-mongosh
        if [ $? -eq 0 ]; then
            echo "[OK] MongoDB Shell installed"
            echo "[INFO] You can now connect using: mongosh"
        fi
    fi
fi

echo ""
echo "[INFO] Installation complete! You can now run your application."
