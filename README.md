# DevOps Midterm Project - Complete Guide

> **Language**: [English](README.md) | [Tiếng Việt](README.vi.md)

## 📋 Project Overview

This is a comprehensive DevOps midterm project for the course **502094 - Software Deployment, Operations And Maintenance**. The project demonstrates the complete lifecycle of deploying a web application through three progressive phases, each representing different levels of infrastructure maturity and DevOps practices.

### Three Phases of Deployment

| Phase | Description | Key Technologies | Complexity |
|-------|-------------|------------------|------------|
| **Phase 1** | Local Development | Node.js, MongoDB | ⭐ Basic |
| **Phase 2** | Production Deployment | Nginx, Systemd, HTTPS | ⭐⭐ Intermediate |
| **Phase 3** | Container Orchestration | Docker, Docker Compose | ⭐⭐⭐ Advanced |

## 🚀 Application Stack

### Core Technologies
- **Backend Framework**: Node.js v20 + Express.js v4.18
- **Database**: MongoDB v6.0 (with intelligent in-memory fallback)
- **Frontend**: EJS Templates + Bootstrap CSS
- **Reverse Proxy**: Nginx
- **Containerization**: Docker & Docker Compose v3.8
- **Process Manager**: systemd (Phase 2)

### Key Features
- ✅ **Full REST API** for product management (CRUD operations)
- ✅ **Server-side rendered UI** with responsive design
- ✅ **Image upload** with Multer (supports JPEG, PNG, GIF)
- ✅ **Automatic fallback** to in-memory storage when MongoDB is unavailable
- ✅ **Health checks** and system monitoring endpoints
- ✅ **Input validation** with express-validator
- ✅ **Auto-seeding** with sample data when database is empty
- ✅ **File management** with automatic cleanup of old images

## 📁 Project Structure

```
DevOps_Midterm/
├── README.md                           # Complete documentation (this file)
│
├── phase1/                             # Phase 1: Local Development
│   └── app/                            # Application source code
│       ├── main.js                     # Application entry point
│       ├── package.json                # Node.js dependencies
│       ├── deploy.sh                   # Deployment script
│       ├── .env.example                # Environment variables template
│       │
│       ├── config/                     # Configuration files
│       ├── controllers/                # Request handlers
│       │   └── productController.js    # Product CRUD operations
│       ├── models/                     # Data models
│       │   └── product.js              # Product schema (Mongoose)
│       ├── routes/                     # API & UI routes
│       │   ├── productRoutes.js        # REST API routes
│       │   └── uiRoutes.js             # Frontend routes
│       ├── services/                   # Business logic
│       │   └── dataSource.js           # Data source abstraction (MongoDB/Memory)
│       ├── validators/                 # Input validation
│       │   └── productValidator.js     # Product validation rules
│       ├── views/                      # EJS templates
│       │   ├── index.ejs               # Main UI page
│       │   └── partials/               # Reusable components
│       │       ├── head.ejs
│       │       └── footer.ejs
│       └── public/                     # Static assets
│           ├── css/
│           │   └── styles.css          # Custom styles
│           ├── js/
│           │   └── ui.js               # Frontend JavaScript
│           ├── images/                 # Static images
│           └── uploads/                # User uploaded images
│
├── phase2/                             # Phase 2: Production Deployment
│   └── configs/                        # Configuration files
│       ├── nginx.conf                  # Nginx reverse proxy configuration
│       └── backend.service             # systemd service file
│
└── phase3/                             # Phase 3: Docker Deployment
    ├── Dockerfile                      # Multi-stage Docker build
    ├── docker-compose.yml              # Container orchestration
    ├── nginx.conf                      # Nginx for containers
    ├── deploy-docker.sh                # Automated deployment script
    └── .env.example                    # Docker environment variables
```

---

## 🎯 Phase 1: Local Development & Basic Deployment

### Overview
Phase 1 focuses on setting up the core application with local development capabilities. The application can run standalone with MongoDB or automatically fall back to in-memory storage.

### Architecture
```
┌─────────────┐
│   Browser   │
└──────┬──────┘
       │ HTTP :3000
       ▼
┌─────────────────┐
│   Node.js App   │
│   (Express.js)  │
└────────┬────────┘
         │ Mongoose
         ▼
┌─────────────────┐
│    MongoDB      │
│  (or In-Memory) │
└─────────────────┘
```

### Prerequisites
```bash
# Required
Node.js 16+
npm 8+

# Optional (app will work without these)
MongoDB 6.0+
```

### Installation Steps

#### 1. Clone and Navigate
```bash
cd phase1/app
```

#### 2. Install Dependencies
```bash
npm install
```

This will install:
- `express` - Web framework
- `mongoose` - MongoDB ODM
- `ejs` - Template engine
- `express-validator` - Input validation
- `multer` - File upload handling
- `dotenv` - Environment configuration
- `uuid` - Unique ID generation

#### 3. Configure Environment
```bash
# Copy example environment file
cp .env.example .env

# Edit .env file
nano .env
```

**Environment Variables:**
```env
# Application Configuration
PORT=3000                                    # Server port
HOST=0.0.0.0                                # Server host
NODE_ENV=development                         # Environment mode

# MongoDB Configuration (Optional)
MONGO_URI=mongodb://localhost:27017/products_db
# Or use MongoDB Atlas
MONGODB_URI=mongodb+srv://user:pass@cluster.mongodb.net/products_db
```

#### 4. Start Application

**Development Mode** (with auto-reload):
```bash
npm run dev
```

**Production Mode**:
```bash
npm start
```

#### 5. Verify Installation
```bash
# Check if server is running
curl http://localhost:3000

# Test API endpoint
curl http://localhost:3000/products

# Should return: []
```

### Access Points
- **Web UI**: http://localhost:3000
- **API Base**: http://localhost:3000/products
- **Health Check**: http://localhost:3000/health

### Key Code Components

#### Product Model (`models/product.js`)
```javascript
// MongoDB Schema with validation
const productSchema = new mongoose.Schema({
  name: { type: String, required: true },
  price: { type: Number, required: true },
  description: String,
  color: String,
  imageUrl: String
}, { timestamps: true });
```

#### Data Source Abstraction (`services/dataSource.js`)
Automatically switches between MongoDB and in-memory storage:
```javascript
// Smart fallback system
if (mongoConnected) {
  return await Product.find();  // Use MongoDB
} else {
  return inMemoryProducts;      // Use in-memory array
}
```

---

## 🌐 Phase 2: Production Deployment with Nginx & HTTPS

### Overview
Phase 2 elevates the application to production-grade deployment with:
- Nginx reverse proxy for better performance and security
- systemd service for automatic startup and monitoring
- HTTPS/SSL support with Let's Encrypt
- Production best practices

### Architecture
```
┌─────────────┐
│   Internet  │
└──────┬──────┘
       │ HTTPS :443
       ▼
┌──────────────────┐
│  Nginx Reverse   │
│      Proxy       │
└────────┬─────────┘
         │ HTTP :3000
         ▼
┌──────────────────┐
│   Node.js App    │
│   (systemd)      │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│    MongoDB       │
└──────────────────┘
```

### Prerequisites
```bash
# Ubuntu/Debian server (20.04+ recommended)
sudo apt update
sudo apt install -y nginx nodejs npm mongodb
```

### Deployment Steps

#### 1. Transfer Application Files
```bash
# On your local machine
scp -r phase1/app ubuntu@your-server-ip:/home/ubuntu/DevOps_Midterm/phase1/

# Or clone from Git
ssh ubuntu@your-server-ip
git clone <your-repo-url> /home/ubuntu/DevOps_Midterm/
```

#### 2. Install Application
```bash
cd /home/ubuntu/DevOps_Midterm/phase1/app
npm install --production

# Create .env file
cp .env.example .env
nano .env
```

#### 3. Configure systemd Service
```bash
# Copy service file
sudo cp /home/ubuntu/DevOps_Midterm/phase2/configs/backend.service \
        /etc/systemd/system/product-app.service

# Edit if needed
sudo nano /etc/systemd/system/product-app.service
```

**Service File Content** (`phase2/configs/backend.service`):
```ini
[Unit]
Description=Product Management Node.js Application
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/DevOps_Midterm/phase1/app
ExecStart=/usr/bin/node /home/ubuntu/DevOps_Midterm/phase1/app/main.js

# Auto restart on failure
Restart=always
RestartSec=10

# Environment variables
Environment=NODE_ENV=production
Environment=PORT=3000
EnvironmentFile=/home/ubuntu/DevOps_Midterm/phase1/app/.env

# Logging
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

#### 4. Start Application Service
```bash
# Reload systemd
sudo systemctl daemon-reload

# Enable auto-start on boot
sudo systemctl enable product-app

# Start service
sudo systemctl start product-app

# Check status
sudo systemctl status product-app

# View logs
sudo journalctl -u product-app -f
```

#### 5. Configure Nginx Reverse Proxy
```bash
# Copy nginx configuration
sudo cp /home/ubuntu/DevOps_Midterm/phase2/configs/nginx.conf \
        /etc/nginx/sites-available/product-app

# Create symbolic link
sudo ln -s /etc/nginx/sites-available/product-app \
            /etc/nginx/sites-enabled/

# Remove default site
sudo rm /etc/nginx/sites-enabled/default

# Test configuration
sudo nginx -t

# Restart nginx
sudo systemctl restart nginx
```

**Nginx Configuration** (`phase2/configs/nginx.conf`):
```nginx
server {
    listen 80;
    server_name your-domain.com;  # Change this!

    client_max_body_size 10M;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Serve uploaded files directly (better performance)
    location /uploads/ {
        alias /home/ubuntu/DevOps_Midterm/phase1/app/public/uploads/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

#### 6. Setup HTTPS with Let's Encrypt (Optional but Recommended)
```bash
# Install Certbot
sudo apt install -y certbot python3-certbot-nginx

# Obtain SSL certificate
sudo certbot --nginx -d your-domain.com -d www.your-domain.com

# Test auto-renewal
sudo certbot renew --dry-run
```

Certbot will automatically:
- ✅ Obtain SSL certificate
- ✅ Configure Nginx for HTTPS
- ✅ Set up auto-renewal

### Testing Phase 2

```bash
# Test from server
curl http://localhost

# Test from external
curl http://your-server-ip
curl https://your-domain.com  # If HTTPS configured

# Test API
curl https://your-domain.com/products
```

### Monitoring & Maintenance

```bash
# View application logs
sudo journalctl -u product-app -f

# Restart application
sudo systemctl restart product-app

# Restart nginx
sudo systemctl restart nginx

# Check nginx error logs
sudo tail -f /var/log/nginx/error.log

# Check nginx access logs
sudo tail -f /var/log/nginx/access.log
```

---

## 🐳 Phase 3: Docker Containerization & Orchestration

### Overview
Phase 3 implements full containerization with Docker, providing:
- Consistent environments across development and production
- Easy scaling and deployment
- Isolated services with container networking
- Persistent data with Docker volumes
- MongoDB container (replacing cloud database)

### Architecture
```
┌─────────────────────────────────────────┐
│          Docker Host                    │
│                                         │
│  ┌────────────────┐  ┌──────────────┐  │
│  │   Nginx:80     │  │  Web App:3000│  │
│  │  (optional)    │─▶│  (Node.js)   │  │
│  └────────────────┘  └───────┬──────┘  │
│                              │          │
│                              ▼          │
│                     ┌──────────────┐   │
│                     │  MongoDB:    │   │
│                     │    27017     │   │
│                     └───────┬──────┘   │
│                             │          │
│  ┌──────────────────────────┴────────┐ │
│  │      Docker Volumes               │ │
│  │  - mongodb_data                   │ │
│  │  - uploads_data                   │ │
│  └───────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

### Prerequisites
```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install Docker Compose
sudo apt install -y docker-compose

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Verify installation
docker --version
docker-compose --version
```

### Deployment Steps

#### 1. Build Docker Image

**Dockerfile** (`phase3/Dockerfile`):
```dockerfile
# Multi-stage build for optimized size
FROM node:20-alpine AS builder
WORKDIR /app
COPY phase1/app/package*.json ./
RUN npm ci --only=production

FROM node:20-alpine
RUN apk add --no-cache dumb-init
RUN addgroup -g 1001 -S nodejs && adduser -S nodejs -u 1001

WORKDIR /app
COPY --from=builder --chown=nodejs:nodejs /app/node_modules ./node_modules
COPY --chown=nodejs:nodejs phase1/app/ ./

RUN mkdir -p /app/public/uploads && \
    chown -R nodejs:nodejs /app/public/uploads

USER nodejs
EXPOSE 3000
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "main.js"]
```

```bash
# Build image (from project root)
docker build -f phase3/Dockerfile -t product-app:latest .

# Test image locally
docker run -p 3000:3000 product-app:latest
```

#### 2. Push to Docker Hub (Optional)
```bash
# Login to Docker Hub
docker login

# Tag image
docker tag product-app:latest your-username/product-app:latest

# Push to registry
docker push your-username/product-app:latest
```

#### 3. Configure Docker Compose

Navigate to phase3 directory:
```bash
cd phase3
```

Create `.env` file:
```bash
cp .env.example .env
nano .env
```

**Environment Variables** (`.env`):
```env
# Docker Image
DOCKER_IMAGE=your-username/product-app:latest

# MongoDB Configuration
MONGO_ROOT_USERNAME=admin
MONGO_ROOT_PASSWORD=YourSecurePassword123!
MONGO_DATABASE=productdb

# Application Configuration
NODE_ENV=production
PORT=3000
```

**Docker Compose File** (`phase3/docker-compose.yml`):
```yaml
version: '3.8'

services:
  # MongoDB Database
  mongodb:
    image: mongo:6.0
    container_name: product-mongodb
    restart: always
    environment:
      MONGO_INITDB_ROOT_USERNAME: ${MONGO_ROOT_USERNAME}
      MONGO_INITDB_ROOT_PASSWORD: ${MONGO_ROOT_PASSWORD}
      MONGO_INITDB_DATABASE: ${MONGO_DATABASE}
    volumes:
      - mongodb_data:/data/db
      - mongodb_config:/data/configdb
    networks:
      - app-network
    healthcheck:
      test: ["CMD", "mongosh", "--eval", "db.adminCommand('ping')"]
      interval: 10s
      timeout: 5s
      retries: 5

  # Web Application
  web:
    image: ${DOCKER_IMAGE}
    container_name: product-web
    restart: always
    depends_on:
      mongodb:
        condition: service_healthy
    environment:
      NODE_ENV: production
      PORT: 3000
      MONGODB_URI: mongodb://${MONGO_ROOT_USERNAME}:${MONGO_ROOT_PASSWORD}@mongodb:27017/${MONGO_DATABASE}?authSource=admin
    volumes:
      - uploads_data:/app/public/uploads
    ports:
      - "3000:3000"
    networks:
      - app-network
    healthcheck:
      test: ["CMD", "node", "-e", "require('http').get('http://localhost:3000')"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  app-network:
    driver: bridge

volumes:
  mongodb_data:
    driver: local
  mongodb_config:
    driver: local
  uploads_data:
    driver: local
```

#### 4. Deploy with Docker Compose

```bash
# Start services in detached mode
docker compose up -d

# View logs
docker compose logs -f

# Check status
docker compose ps

# Stop services
docker compose down

# Stop and remove volumes (WARNING: deletes data!)
docker compose down -v
```

#### 5. Automated Deployment Script

Use the provided deployment script (`phase3/deploy-docker.sh`):
```bash
chmod +x deploy-docker.sh
./deploy-docker.sh
```

The script automates:
- ✅ Pulling latest images
- ✅ Stopping old containers
- ✅ Starting new containers
- ✅ Health checks
- ✅ Cleanup of old images

### Docker Management Commands

```bash
# View running containers
docker compose ps
docker ps

# View logs
docker compose logs -f web        # Web app logs
docker compose logs -f mongodb    # Database logs
docker compose logs --tail=100    # Last 100 lines

# Restart services
docker compose restart web
docker compose restart mongodb

# Execute commands in container
docker compose exec web sh        # Shell access
docker compose exec mongodb mongosh  # MongoDB shell

# Monitor resources
docker stats

# View volumes
docker volume ls
docker volume inspect phase3_mongodb_data

# Backup MongoDB data
docker compose exec mongodb mongodump --out=/data/backup

# View networks
docker network ls
docker network inspect phase3_app-network
```

### Scaling (Advanced)

```bash
# Scale web application to 3 instances
docker compose up -d --scale web=3

# Requires load balancer (nginx) in front
```

---

## 🔌 API Endpoints Reference

### Product Management API

#### List All Products
```bash
GET /products

# Response
[
  {
    "_id": "123",
    "name": "iPhone 15 Pro",
    "price": 999,
    "color": "Titanium Blue",
    "description": "Latest iPhone model",
    "imageUrl": "/uploads/image123.jpg",
    "createdAt": "2024-01-01T00:00:00.000Z"
  }
]
```

#### Get Single Product
```bash
GET /products/:id

# Example
GET /products/123
```

#### Create Product
```bash
POST /products
Content-Type: multipart/form-data

# Fields
name: string (required)
price: number (required)
color: string (optional)
description: string (optional)
imageFile: file (optional, JPEG/PNG/GIF, max 5MB)

# Example with curl
curl -X POST http://localhost:3000/products \
  -F "name=iPhone 15 Pro" \
  -F "price=999" \
  -F "color=Titanium Blue" \
  -F "description=Latest model" \
  -F "imageFile=@/path/to/image.jpg"
```

#### Update Product (Full)
```bash
PUT /products/:id
Content-Type: multipart/form-data

# All fields required (except imageFile)
name: string
price: number
color: string
description: string
imageFile: file (optional)
```

#### Update Product (Partial)
```bash
PATCH /products/:id
Content-Type: multipart/form-data

# Only include fields to update
name: string (optional)
price: number (optional)
imageFile: file (optional)
```

#### Delete Product
```bash
DELETE /products/:id

# Example
DELETE /products/123
```

### System Endpoints

#### Health Check
```bash
GET /health

# Response
{
  "status": "healthy",
  "hostname": "server123",
  "dataSource": "mongodb",
  "timestamp": "202401-0101T00:00:00.000Z"
}
```

#### Homepage
```bash
GET /

# Returns HTML page with product management UI
```

---

## ⚙️ Environment Variables Complete Reference

### Application Variables

```env
# === SERVER CONFIGURATION ===
PORT=3000                          # HTTP port (default: 3000)
HOST=0.0.0.0                      # Bind address (0.0.0.0 for all interfaces)
NODE_ENV=production               # Environment: development | production

# === DATABASE CONFIGURATION ===
# MongoDB Atlas (Cloud)
MONGODB_URI=mongodb+srv://user:password@cluster.mongodb.net/database?retryWrites=true&w=majority

# MongoDB Local
MONGO_URI=mongodb://localhost:27017/products_db

# === FILE UPLOAD ===
MAX_FILE_SIZE=5242880             # Max file size in bytes (default: 5MB)
UPLOAD_DIR=./public/uploads       # Upload directory (default: ./public/uploads)

# === DOCKER-SPECIFIC (Phase 3) ===
DOCKER_IMAGE=username/product-app:latest
MONGO_ROOT_USERNAME=admin
MONGO_ROOT_PASSWORD=SecurePassword123!
MONGO_DATABASE=productdb
DATA_SOURCE=mongodb               # mongodb | memory
```

---

## 🧪 Testing Guide

### Manual Testing

#### 1. Test Application Health
```bash
curl http://localhost:3000/health
```

#### 2. Test Product Creation
```bash
curl -X POST http://localhost:3000/products \
  -F "name=Test Product" \
  -F "price=99.99" \
  -F "color=Red" \
  -F "description=Test description"
```

#### 3. Test Product Listing
```bash
curl http://localhost:3000/products
```

#### 4. Test Product Update
```bash
curl -X PATCH http://localhost:3000/products/{id} \
  -F "price=79.99"
```

#### 5. Test Product Deletion
```bash
curl -X DELETE http://localhost:3000/products/{id}
```

#### 6. Test Image Upload
```bash
curl -X POST http://localhost:3000/products \
  -F "name=Product with Image" \
  -F "price=149.99" \
  -F "imageFile=@./test-image.jpg"
```

### UI Testing

1. Open browser: http://localhost:3000
2. Click "Add Product" button
3. Fill in form fields
4. Upload image
5. Submit form
6. Verify product appears in list
7. Test edit and delete buttons

---

## 🔍 Troubleshooting Guide

### Common Issues & Solutions

#### Issue 1: MongoDB Connection Failed
```
Error: connect ECONNREFUSED 127.0.0.1:27017
```

**Solutions:**
```bash
# Check if MongoDB is running
sudo systemctl status mongodb

# Start MongoDB
sudo systemctl start mongodb

# Or let app use in-memory fallback
# Remove MONGO_URI from .env
```

#### Issue 2: Port Already in Use
```
Error: listen EADDRINUSE: address already in use :::3000
```

**Solutions:**
```bash
# Find process using port 3000
sudo lsof -ti:3000

# Kill the process
sudo lsof -ti:3000 | xargs kill -9

# Or change PORT in .env
PORT=3001
```

#### Issue 3: Permission Denied on Uploads
```
Error: EACCES: permission denied, open '/app/public/uploads/...'
```

**Solutions:**
```bash
# Fix permissions
chmod -R 755 public/uploads
chown -R $USER:$USER public/uploads

# Or for systemd service
sudo chown -R ubuntu:ubuntu /home/ubuntu/DevOps_Midterm/phase1/app/public/uploads
```

#### Issue 4: Docker Container Won't Start
```bash
# View logs
docker compose logs web

# Common fixes:
# 1. Check .env file exists and is configured
ls -la .env

# 2. Rebuild image
docker compose build --no-cache

# 3. Remove old containers and volumes
docker compose down -v
docker compose up -d
```

#### Issue 5: Nginx 502 Bad Gateway
```
502 Bad Gateway
```

**Solutions:**
```bash
# Check if Node.js app is running
sudo systemctl status product-app

# Check if app is listening on correct port
sudo netstat -tulpn | grep 3000

# Check nginx error logs
sudo tail -f /var/log/nginx/error.log

# Restart services
sudo systemctl restart product-app
sudo systemctl restart nginx
```

#### Issue 6: Image Upload Fails
**Solutions:**
```bash
# Check upload directory exists
mkdir -p public/uploads

# Check nginx client_max_body_size
# Edit /etc/nginx/sites-available/product-app
client_max_body_size 10M;

# Restart nginx
sudo systemctl restart nginx
```

#### Issue 7: Docker MongoDB Connection Timeout
```bash
# Check MongoDB container is healthy
docker compose ps

# View MongoDB logs  
docker compose logs mongodb

# Restart MongoDB container
docker compose restart mongodb

# Check network connectivity
docker compose exec web ping mongodb
```

---

## 📊 Monitoring & Logging

### Phase 1 & 2: systemd Logging

```bash
# View real-time logs
sudo journalctl -u product-app -f

# View last 100 lines
sudo journalctl -u product-app -n 100

# View logs since boot
sudo journalctl -u product-app -b

# View logs for specific time range
sudo journalctl -u product-app --since "2024-01-01" --until "2024-01-02"

# Export logs to file
sudo journalctl -u product-app > app-logs.txt
```

### Phase 3: Docker Logging

```bash
# View all logs
docker compose logs -f

# View specific service logs
docker compose logs -f web
docker compose logs -f mongodb

# View last 50 lines
docker compose logs --tail=50

# View logs since 1 hour ago
docker compose logs --since 1h

# Follow logs with timestamps
docker compose logs -f -t
```

### Nginx Logging

```bash
# Access logs (successful requests)
sudo tail -f /var/log/nginx/access.log

# Error logs
sudo tail -f /var/log/nginx/error.log

# Application-specific logs
sudo  tail -f /var/log/nginx/product-app-access.log
sudo tail -f /var/log/nginx/product-app-error.log
```

### Application Monitoring

```bash
# Check system resources
htop
top

# Check disk usage
df -h

# Check memory usage
free -h

# Check Docker resources
docker stats

# Check process
ps aux | grep node
```

---

## 🚀 Deployment Checklist

### Pre-Deployment
- [ ] All dependencies installed
- [ ] Environment variables configured
- [ ] Database accessible
- [ ] Firewall rules configured
- [ ] SSL certificates obtained (Phase 2)
- [ ] Docker images built and tested (Phase 3)

### Phase 1 Checklist
- [ ] Node.js and npm installed
- [ ] Application dependencies installed (`npm install`)
- [ ] `.env` file created and configured
- [ ] Uploads directory exists with correct permissions
- [ ] Application starts successfully (`npm start`)
- [ ] Can access UI at http://localhost:3000
- [ ] API endpoints respond correctly

### Phase 2 Checklist
- [ ] Server provisioned (Ubuntu 20.04+)
- [ ] Application files transferred
- [ ] systemd service file copied
- [ ] Service enabled and started
- [ ] Service auto-starts on reboot
- [ ] Nginx installed and configured
- [ ] Nginx config tested (`nginx -t`)
- [ ] Domain DNS configured
- [ ] SSL certificate obtained
- [ ] HTTPS working correctly
- [ ] Logs accessible via journalctl

### Phase 3 Checklist
- [ ] Docker installed
- [ ] Docker Compose installed
- [ ] Docker image built successfully
- [ ] Image pushed to registry
- [ ] `.env` file configured in phase3/
- [ ] `docker-compose.yml` reviewed
- [ ] Containers start successfully
- [ ] Health checks passing
- [ ] Volumes created for persistent data
- [ ] Can access application
- [ ] MongoDB accessible from web container
- [ ] Logs accessible via `docker compose logs`

---

## 📚 Additional Resources

### Official Documentation
- [Node.js Documentation](https://nodejs.org/docs/) - Node.js API and guides
- [Express.js Guide](https://expressjs.com/) - Web framework documentation
- [MongoDB Documentation](https://docs.mongodb.com/) - Database documentation
- [Mongoose ODM](https://mongoosejs.com/) - MongoDB object modeling
- [Docker Documentation](https://docs.docker.com/) - Container platform
- [Docker Compose](https://docs.docker.com/compose/) - Multi-container orchestration
- [Nginx Documentation](https://nginx.org/en/docs/) - Web server and reverse proxy
- [Let's Encrypt](https://letsencrypt.org/docs/) - Free SSL certificates

### DevOps Best Practices
- [The Twelve-Factor App](https://12factor.net/) - Methodology for building SaaS apps
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Nginx Optimization](https://www.nginx.com/blog/tuning-nginx/)
- [Node.js Production Best Practices](https://expressjs.com/en/advanced/best-practice-performance.html)

### Security
- [OWASP Top 10](https://owasp.org/www-project-top-ten/) - Web application security risks
- [Node.js Security Best Practices](https://nodejs.org/en/docs/guides/security/)
- [Docker Security](https://docs.docker.com/engine/security/)

---

## 👥 Contributing

This is a midterm project for educational purposes. Students can:
- ✅ Use as a reference implementation
- ✅ Modify for their own projects
- ✅ Extend with additional features
- ✅ Choose different technologies
- ✅ Submit improvements via pull requests

### Suggested Enhancements
- Add user authentication (JWT, OAuth)
- Implement caching (Redis)
- Add CI/CD pipeline (GitHub Actions, Jenkins)
- Implement monitoring (Prometheus, Grafana)
- Add search functionality (Elasticsearch)
- Implement rate limiting
- Add WebSocket for real-time updates
- Implement microservices architecture

---

## 📄 License

This project is provided for educational purposes as part of the **Software Deployment, Operations and Maintenance** course (502094).

---

## 👨‍🏫 Course Information

**Instructor**: ThS. Mai Văn Mạnh
**Course Code**: 502094
**Course Name**: Software Deployment, Operations And Maintenance  
**Institution**: Ton Duc Thang University

---

## 💡 Support & Questions

For issues or questions:
1. Check this comprehensive README
2. Review error logs (systemd or Docker)
3. Refer to official documentation links above
4. Contact instructor during office hours
5. Post in course discussion forum

---

## 🎓 Learning Objectives

By completing this project, you will learn:

### Phase 1 Skills
- ✅ Node.js application development
- ✅ Express.js framework
- ✅ MongoDB integration
- ✅ RESTful API design
- ✅ File upload handling
- ✅ Environment configuration

### Phase 2 Skills
- ✅ Linux server administration
- ✅ systemd service management
- ✅ Nginx reverse proxy configuration
- ✅ SSL/TLS certificate management
- ✅ Production deployment practices
- ✅ Log management

### Phase 3 Skills
- ✅ Docker containerization
- ✅ Multi-stage Docker builds
- ✅ Docker Compose orchestration
- ✅ Container networking
- ✅ Volume management
- ✅ Container monitoring

### DevOps Principles
- ✅ Infrastructure as Code
- ✅ Continuous Deployment
- ✅ Monitoring and Logging
- ✅ Security best practices
- ✅ Scalability considerations
- ✅ Documentation practices

---

**Last Updated**: March 2026  
**Project Version**: 1.0.0