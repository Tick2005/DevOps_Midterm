# ============================================
# PRODUCTION DOCKERFILE FOR NODE.JS APPLICATION
# ============================================
# Multi-stage build for optimized image size
# Base image: Node.js 20 LTS on Alpine Linux

# Stage 1: Build stage
FROM node:20-alpine AS builder

# Set working directory
WORKDIR /app

# Copy package files
COPY phase1/app/package*.json ./

# Install production dependencies only
RUN npm ci --only=production --omit=dev

# Stage 2: Production stage
FROM node:20-alpine

# Install dumb-init for proper signal handling
RUN apk add --no-cache dumb-init

# Create non-root user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Set working directory
WORKDIR /app

# Copy dependencies from builder
COPY --from=builder --chown=nodejs:nodejs /app/node_modules ./node_modules

# Copy application code
COPY --chown=nodejs:nodejs phase1/app/ ./

# Create uploads directory with correct permissions
RUN mkdir -p /app/public/uploads && \
    chown -R nodejs:nodejs /app/public/uploads

# Switch to non-root user
USER nodejs

# Expose application port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3000', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Use dumb-init to handle signals properly
ENTRYPOINT ["dumb-init", "--"]

# Start application
CMD ["node", "main.js"]
