#!/bin/bash

# ============================================
# PHASE 3: DOCKER DEPLOYMENT SCRIPT
# ============================================
# This script automates the deployment of the application
# using Docker and Docker Compose
#
# Requirements:
# - Docker Engine installed
# - Docker Compose installed
# - .env file configured
# - Docker image already built and pushed to Docker Hub

set -e  # Exit on error

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${CYAN}🐳 DOCKER DEPLOYMENT - PHASE 3${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ============================================
# STEP 1: CHECK PREREQUISITES
# ============================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${CYAN}📋 STEP 1: Checking Prerequisites${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker not found!${NC}"
    echo "Install Docker first:"
    echo "  curl -fsSL https://get.docker.com -o get-docker.sh"
    echo "  sudo sh get-docker.sh"
    exit 1
fi
echo -e "${GREEN}✓ Docker installed: $(docker --version)${NC}"

# Check Docker Compose
if ! command -v docker compose &> /dev/null; then
    echo -e "${RED}❌ Docker Compose not found!${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker Compose installed: $(docker compose version)${NC}"

# Check if Docker daemon is running
if ! docker ps &> /dev/null; then
    echo -e "${RED}❌ Docker daemon is not running!${NC}"
    echo "Start Docker service: sudo systemctl start docker"
    exit 1
fi
echo -e "${GREEN}✓ Docker daemon is running${NC}"

# Check if user is in docker group
if ! groups | grep -q docker; then
    echo -e "${YELLOW}⚠ Current user is not in docker group${NC}"
    echo "Add user to docker group: sudo usermod -aG docker $USER"
    echo "Then logout and login again"
fi

echo ""

# ============================================
# STEP 2: ENVIRONMENT CONFIGURATION
# ============================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${CYAN}⚙️  STEP 2: Environment Configuration${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cd "$SCRIPT_DIR"

# Check .env file
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}⚠ .env file not found${NC}"
    if [ -f ".env.example" ]; then
        echo "Creating .env from .env.example..."
        cp .env.example .env
        echo -e "${GREEN}✓ .env created${NC}"
        echo ""
        echo -e "${YELLOW}⚠ IMPORTANT: Edit .env file with your configuration:${NC}"
        echo "  1. Set DOCKER_IMAGE to your Docker Hub image"
        echo "  2. Set MONGO_ROOT_PASSWORD"
        echo ""
        read -p "Press Enter after editing .env file..."
    else
        echo -e "${RED}❌ .env.example not found!${NC}"
        exit 1
    fi
fi

# Load .env
source .env

# Validate configuration
if [[ $DOCKER_IMAGE == *"your-dockerhub-username"* ]]; then
    echo -e "${RED}❌ DOCKER_IMAGE not configured in .env${NC}"
    echo "Please set your Docker Hub image name"
    exit 1
fi

if [ "$MONGO_ROOT_PASSWORD" == "your-secure-password-here" ]; then
    echo -e "${YELLOW}⚠ Using default MongoDB password${NC}"
    echo -e "${YELLOW}⚠ Consider changing it in .env file${NC}"
fi

echo -e "${GREEN}✓ Configuration loaded${NC}"
echo "  Docker Image: $DOCKER_IMAGE"
echo "  MongoDB User: $MONGO_ROOT_USERNAME"
echo "  Database: $MONGO_DATABASE"
echo ""

# ============================================
# STEP 3: STOP EXISTING SERVICES
# ============================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${CYAN}🛑 STEP 3: Stopping Existing Services${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Stop Phase 2 systemd service if exists
if systemctl is-active --quiet product-app 2>/dev/null; then
    echo "Stopping Phase 2 systemd service..."
    sudo systemctl stop product-app
    sudo systemctl disable product-app
    echo -e "${GREEN}✓ Phase 2 service stopped${NC}"
fi

# Stop existing Docker containers
if [ "$(docker ps -q -f name=product-)" ]; then
    echo "Stopping existing Docker containers..."
    docker compose down
    echo -e "${GREEN}✓ Existing containers stopped${NC}"
else
    echo -e "${GREEN}✓ No existing containers to stop${NC}"
fi

echo ""

# ============================================
# STEP 4: PULL DOCKER IMAGE
# ============================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${CYAN}📥 STEP 4: Pulling Docker Image${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Pulling image: $DOCKER_IMAGE"
if docker pull "$DOCKER_IMAGE"; then
    echo -e "${GREEN}✓ Image pulled successfully${NC}"
else
    echo -e "${RED}❌ Failed to pull image${NC}"
    echo "Make sure:"
    echo "  1. You are logged in to Docker Hub: docker login"
    echo "  2. The image exists and is accessible"
    echo "  3. Image name is correct in .env file"
    exit 1
fi

echo ""

# ============================================
# STEP 5: START DOCKER COMPOSE SERVICES
# ============================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${CYAN}🚀 STEP 5: Starting Services${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Starting services with Docker Compose..."
docker compose up -d

echo ""
echo "Waiting for services to be healthy..."
sleep 10

# Check service status
if docker compose ps | grep -q "healthy"; then
    echo -e "${GREEN}✓ Services started successfully${NC}"
else
    echo -e "${YELLOW}⚠ Services started but health check pending...${NC}"
fi

echo ""

# ============================================
# STEP 6: VERIFY DEPLOYMENT
# ============================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${CYAN}✅ STEP 6: Deployment Verification${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Running containers:"
docker compose ps
echo ""

echo "Docker volumes:"
docker volume ls | grep product
echo ""

# ============================================
# STEP 7: UPDATE NGINX (IF NEEDED)
# ============================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${CYAN}🔧 STEP 7: Nginx Configuration${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ -f "/etc/nginx/sites-available/product-app" ]; then
    echo -e "${GREEN}✓ Nginx config exists (should already point to localhost:3000)${NC}"
    echo ""
    echo "If needed, test and reload nginx:"
    echo "  sudo nginx -t"
    echo "  sudo systemctl reload nginx"
else
    echo -e "${YELLOW}⚠ Nginx config not found${NC}"
    echo "Use the nginx.conf from phase2/configs/ directory"
fi

echo ""

# ============================================
# DEPLOYMENT SUMMARY
# ============================================

PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || echo "your-server-ip")

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ DEPLOYMENT COMPLETED!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${BLUE}🌐 Access your application:${NC}"
echo "   http://$PUBLIC_IP"
echo "   http://localhost"
echo ""
echo -e "${BLUE}📊 Useful Commands:${NC}"
echo "   View logs:       docker compose logs -f"
echo "   View web logs:   docker compose logs -f web"
echo "   View db logs:    docker compose logs -f mongodb"
echo "   Stop services:   docker compose down"
echo "   Start services:  docker compose up -d"
echo "   Restart:         docker compose restart"
echo "   Status:          docker compose ps"
echo ""
echo -e "${BLUE}📦 Data Persistence:${NC}"
echo "   Database:        docker volume inspect product_mongodb_data"
echo "   Uploads:         docker volume inspect product_uploads_data"
echo ""
echo -e "${YELLOW}⚠️  Important:${NC}"
echo "   - MongoDB is running in Docker container (not Atlas)"
echo "   - Data is stored in Docker volumes"
echo "   - Services auto-restart on failure"
echo "   - Docker will start on system reboot"
echo ""
echo -e "${GREEN}🎉 Phase 3 deployment successful!${NC}"
