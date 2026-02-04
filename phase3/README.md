# Phase 3: Docker Deployment with Docker Compose

## Overview
Phase 3 migrates the application from traditional host-based deployment to a fully containerized architecture using Docker and Docker Compose. The entire application stack now runs in containers, including:
- **Web Application** (Node.js Express)
- **MongoDB Database** (replacing MongoDB Atlas)

## Architecture Changes from Phase 2

| Component | Phase 2 | Phase 3 |
|-----------|---------|---------|
| Web App | systemd service on host | Docker container |
| Database | MongoDB Atlas (cloud) | MongoDB container |
| Process Manager | systemd | Docker restart policies |
| Networking | localhost | Docker bridge network |
| Storage | Host filesystem | Docker volumes |
| Reverse Proxy | Nginx on host | Nginx on host (unchanged) |

## Prerequisites

### 1. Docker Installation
```bash
# Install Docker Engine
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add current user to docker group
sudo usermod -aG docker $USER

# Logout and login again to apply group changes
```

### 2. Enable Docker on System Boot
```bash
# Enable Docker service to start on boot
sudo systemctl enable docker

# Verify Docker will start on boot
sudo systemctl is-enabled docker
```

### 3. Verify Installation
```bash
# Check Docker version
docker --version

# Check Docker Compose version
docker compose version

# Test Docker
docker run hello-world
```

## Deployment Steps

### Step 1: Build Docker Image Locally

**Navigate to project root:**
```bash
cd DevOps_Midterm
```

**Build the image:**
```bash
# Build image (this uses phase3/Dockerfile which references phase1/app/)
docker build -f phase3/Dockerfile -t your-dockerhub-username/product-app:latest .

# Verify image was created
docker images | grep product-app
```

**Important Notes:**
- The Dockerfile is in `phase3/` but it copies code from `phase1/app/`
- Build command must be run from project root (`DevOps_Midterm/`)
- Use multi-stage build for optimized production image
- Image size should be ~150-200MB (Alpine-based)

### Step 2: Push Image to Docker Hub

**Login to Docker Hub:**
```bash
docker login
# Enter your username and password
```

**Tag and push:**
```bash
# Tag image (if not already tagged correctly)
docker tag your-dockerhub-username/product-app:latest your-dockerhub-username/product-app:latest

# Push to Docker Hub
docker push your-dockerhub-username/product-app:latest

# Verify upload
docker search your-dockerhub-username/product-app
```

**Take screenshots for report:**
- Docker build output
- Docker images list
- Docker push output
- Docker Hub repository page

### Step 3: Configure Environment

**Navigate to phase3 directory:**
```bash
cd phase3
```

**Create .env file:**
```bash
# Copy template
cp .env.example .env

# Edit configuration
nano .env
```

**Update these values in .env:**
```env
# Your Docker Hub image
DOCKER_IMAGE=your-dockerhub-username/product-app:latest

# MongoDB credentials (choose strong password)
MONGO_ROOT_USERNAME=admin
MONGO_ROOT_PASSWORD=YourSecurePassword123!
MONGO_DATABASE=productdb
```

### Step 4: Stop Phase 2 Services

**Stop systemd service:**
```bash
# Stop the service
sudo systemctl stop product-app

# Disable from auto-start
sudo systemctl disable product-app

# Verify it's stopped
sudo systemctl status product-app
```

**Note:** Nginx reverse proxy should remain running on the host.

### Step 5: Deploy with Docker Compose

**Make deployment script executable:**
```bash
chmod +x deploy-docker.sh
```

**Run deployment:**
```bash
./deploy-docker.sh
```

The script will:
1. ✅ Check Docker and Docker Compose installation
2. ✅ Validate .env configuration
3. ✅ Stop existing containers
4. ✅ Pull image from Docker Hub
5. ✅ Start services with docker-compose
6. ✅ Verify deployment

**Or deploy manually:**
```bash
# Pull latest image
docker compose pull

# Start services
docker compose up -d

# Check status
docker compose ps
```

### Step 6: Verify Deployment

**Check running containers:**
```bash
docker compose ps

# Expected output:
# NAME              STATUS              PORTS
# product-web       Up (healthy)        0.0.0.0:3000->3000/tcp
# product-mongodb   Up (healthy)
```

**View logs:**
```bash
# All services
docker compose logs -f

# Web app only
docker compose logs -f web

# MongoDB only
docker compose logs -f mongodb
```

**Test application:**
```bash
# Test from server
curl http://localhost:3000

# Test from browser
http://your-domain.com
```

**Check volumes:**
```bash
# List volumes
docker volume ls | grep product

# Inspect database volume
docker volume inspect product_mongodb_data

# Inspect uploads volume
docker volume inspect product_uploads_data
```

## Service Management

### Common Commands

```bash
# Start services
docker compose up -d

# Stop services
docker compose down

# Restart services
docker compose restart

# View status
docker compose ps

# View logs (follow)
docker compose logs -f

# View resource usage
docker stats

# Execute command in container
docker compose exec web sh
docker compose exec mongodb mongosh
```

### Update Application

```bash
# 1. Build new image locally
cd DevOps_Midterm
docker build -f phase3/Dockerfile -t your-username/product-app:latest .

# 2. Push to Docker Hub
docker push your-username/product-app:latest

# 3. Pull and restart on server
cd phase3
docker compose pull
docker compose up -d
```

### Backup and Restore

**Backup MongoDB data:**
```bash
# Create backup
docker compose exec mongodb mongodump --out /backup
docker cp product-mongodb:/backup ./mongodb-backup-$(date +%Y%m%d)

# Backup uploads
docker cp product-web:/app/public/uploads ./uploads-backup-$(date +%Y%m%d)
```

**Restore from backup:**
```bash
# Restore MongoDB
docker compose exec mongodb mongorestore /backup

# Restore uploads
docker cp ./uploads-backup product-web:/app/public/uploads
```

## Persistent Data

All data is stored in Docker volumes:

| Volume | Purpose | Mount Point |
|--------|---------|-------------|
| `product_mongodb_data` | MongoDB database files | `/data/db` |
| `product_mongodb_config` | MongoDB configuration | `/data/configdb` |
| `product_uploads_data` | User uploaded files | `/app/public/uploads` |

**Volumes survive container restarts and recreations.** Data is only lost if volumes are explicitly deleted.

## Networking

### Docker Network
- **Network name:** `product-app-network`
- **Driver:** bridge
- **Internal communication:** Services use container names as hostnames
  - Web app connects to MongoDB using `mongodb://mongodb:27017`
  - No external MongoDB port exposure needed

### Port Mapping
- **Web container:** Port 3000 exposed to host
- **MongoDB container:** No ports exposed (internal only)
- **Nginx:** Port 80/443 on host → reverse proxy to `localhost:3000`

## Restart Policies and Auto-Start

### Container Restart Policy
All services are configured with `restart: always`:
- Containers automatically restart on failure
- Containers start when Docker daemon starts
- Persistent across system reboots

### Enable Docker on Boot
```bash
# Enable Docker service
sudo systemctl enable docker

# Check status
sudo systemctl is-enabled docker
# Output: enabled
```

### Test Auto-Start
```bash
# Reboot server
sudo reboot

# After reboot, verify containers are running
docker compose ps
```

## Troubleshooting

### Container Won't Start

**Check logs:**
```bash
docker compose logs web
docker compose logs mongodb
```

**Check container status:**
```bash
docker compose ps
docker inspect product-web
```

**Common issues:**
- MongoDB not ready → Wait for health check
- Wrong environment variables → Check .env file
- Port 3000 already in use → Stop Phase 2 services
- Permission denied → Check file ownership in volumes

### MongoDB Connection Issues

**Test MongoDB connectivity:**
```bash
# From web container
docker compose exec web sh
wget -O- http://mongodb:27017
# Should return: "It looks like you are trying to access MongoDB..."

# Direct MongoDB access
docker compose exec mongodb mongosh -u admin -p yourpassword --authenticationDatabase admin
```

**Check MongoDB logs:**
```bash
docker compose logs mongodb | grep -i error
```

### Application Not Accessible

**Check Nginx:**
```bash
sudo nginx -t
sudo systemctl status nginx
sudo systemctl reload nginx
```

**Check port binding:**
```bash
netstat -tulpn | grep 3000
# Should show Docker proxy listening on port 3000
```

**Test connectivity:**
```bash
curl http://localhost:3000
curl http://127.0.0.1:3000
```

### Data Not Persisting

**Verify volumes are mounted:**
```bash
docker compose exec web ls -la /app/public/uploads
docker compose exec mongodb ls -la /data/db
```

**Check volume bindings:**
```bash
docker inspect product-web | grep -A 10 Mounts
docker inspect product-mongodb | grep -A 10 Mounts
```

### Image Pull Fails

**Check Docker Hub credentials:**
```bash
docker login
```

**Check image name:**
```bash
# Verify image exists on Docker Hub
docker search your-username/product-app

# Try manual pull
docker pull your-username/product-app:latest
```

## Security Considerations

### Container Security
- ✅ Non-root user (`nodejs`) inside container
- ✅ No unnecessary packages (Alpine-based)
- ✅ Read-only root filesystem where possible
- ✅ Signal handling with dumb-init

### Network Security
- ✅ MongoDB not exposed to internet
- ✅ Internal communication only within Docker network
- ✅ Nginx reverse proxy handles external traffic
- ✅ HTTPS termination at Nginx (Phase 2 setup)

### Data Security
- ✅ MongoDB credentials in .env (not in code)
- ✅ .env excluded from git (.gitignore)
- ✅ Volume permissions properly set
- ✅ MongoDB authentication enabled

## Evidence for Technical Report

### Required Screenshots

1. **Docker Installation**
   ```bash
   docker --version
   docker compose version
   systemctl is-enabled docker
   ```

2. **Image Build Process**
   ```bash
   docker build -f phase3/Dockerfile -t username/product-app:latest .
   docker images | grep product-app
   ```

3. **Docker Hub Push**
   ```bash
   docker push username/product-app:latest
   # Screenshot of Docker Hub repository page
   ```

4. **Running Containers**
   ```bash
   docker compose ps
   docker ps
   ```

5. **Volume Configuration**
   ```bash
   docker volume ls | grep product
   docker volume inspect product_mongodb_data
   ```

6. **Service Logs**
   ```bash
   docker compose logs --tail=50
   ```

7. **Application Access**
   - Screenshot of application running via HTTPS
   - Browser showing valid SSL certificate

8. **Restart Policy Test**
   ```bash
   # Before reboot
   docker compose ps
   
   # Reboot system
   sudo reboot
   
   # After reboot (automatic)
   docker compose ps
   ```

9. **Data Persistence Test**
   - Create data in application
   - Restart containers: `docker compose restart`
   - Verify data still exists

10. **Inter-service Communication**
    ```bash
    docker compose exec web sh
    # Inside container:
    ping mongodb
    wget -O- http://mongodb:27017
    ```

## Migration Checklist

- [ ] Docker and Docker Compose installed
- [ ] Docker enabled to start on boot
- [ ] Dockerfile created and tested
- [ ] Image built locally
- [ ] Image pushed to Docker Hub
- [ ] .env file configured with correct credentials
- [ ] Phase 2 systemd service stopped and disabled
- [ ] docker-compose.yml configured
- [ ] Containers started with docker compose up -d
- [ ] Both containers showing "healthy" status
- [ ] Application accessible via domain/HTTPS
- [ ] File uploads working and persisting
- [ ] MongoDB data persisting across restarts
- [ ] Tested server reboot (containers auto-start)
- [ ] Nginx reverse proxy updated (if needed)
- [ ] All evidence collected for report

## Comparison: Phase 2 vs Phase 3

| Aspect | Phase 2 | Phase 3 |
|--------|---------|---------|
| **Deployment** | Manual setup on host | Containerized with Docker |
| **Process Manager** | systemd | Docker restart policies |
| **Database** | MongoDB Atlas (cloud) | MongoDB container (local) |
| **Portability** | Host-dependent | Platform-independent |
| **Scalability** | Single instance | Easy horizontal scaling |
| **Isolation** | Process-level | Container-level |
| **Networking** | localhost | Docker bridge network |
| **Data Storage** | Host filesystem | Docker volumes |
| **Deployment Time** | ~10-15 minutes | ~5 minutes (after image built) |
| **Reproducibility** | Manual steps | Fully automated |

## Benefits of Docker Deployment

### For Development
- ✅ Consistent environment across all machines
- ✅ Easy to recreate from scratch
- ✅ No "works on my machine" issues
- ✅ Fast deployment and rollback

### For Production
- ✅ Isolated runtime environment
- ✅ Resource limits and monitoring
- ✅ Easy updates (just pull new image)
- ✅ Portable across cloud providers
- ✅ Automatic restart on failure

### For Operations
- ✅ Infrastructure as Code
- ✅ Version-controlled configuration
- ✅ Simplified backup and restore
- ✅ Easy scaling (docker compose scale)

## Next Steps (Optional)

### Container Orchestration
- Kubernetes for multi-node deployment
- Docker Swarm for simpler orchestration
- Cloud container services (ECS, AKS, GKE)

### CI/CD Pipeline
- Automate image building on git push
- Automated testing before deployment
- Blue-green or canary deployments

### Monitoring
- Prometheus + Grafana for metrics
- ELK stack for log aggregation
- Container health monitoring

### Performance
- Resource limits (CPU, memory)
- Horizontal scaling (multiple replicas)
- Load balancing across containers

## References

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [MongoDB Docker Image](https://hub.docker.com/_/mongo)
- [Node.js Docker Best Practices](https://github.com/nodejs/docker-node/blob/main/docs/BestPractices.md)
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)

---

**Phase 3 Complete!** 🎉

Your application is now fully containerized and production-ready with Docker!
