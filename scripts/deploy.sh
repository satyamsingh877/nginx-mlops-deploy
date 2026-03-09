#!/bin/bash

# Nginx MLOps Deployment Script
set -e

# Configuration
HOST_PORT=${DEPLOY_PORT:-8081}  # Use env var or default to 8081
CONTAINER_PORT=80
CONTAINER_NAME="nginx-mlops"
IMAGE_NAME="nginx-mlops:latest"
DEPLOY_DIR="/opt/nginx-mlops"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo -e "${GREEN}🚀 Nginx MLOps Deployment Script${NC}"
echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo "📌 Configuration:"
echo "  - Host Port: $HOST_PORT"
echo "  - Container Port: $CONTAINER_PORT"
echo "  - Container Name: $CONTAINER_NAME"
echo "  - Image: $IMAGE_NAME"
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    echo -e "${YELLOW}⚠️  Running as root user${NC}"
fi

# Check Docker
echo -e "${BLUE}🔍 Checking Docker...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker is not installed${NC}"
    exit 1
fi

if ! docker info &> /dev/null; then
    echo -e "${RED}❌ Docker daemon is not running${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Docker is running${NC}"

# Check port availability
echo -e "${BLUE}🔍 Checking port $HOST_PORT...${NC}"
if lsof -Pi :$HOST_PORT -sTCP:LISTEN -t &> /dev/null; then
    echo -e "${RED}❌ Port $HOST_PORT is already in use by:${NC}"
    lsof -i :$HOST_PORT
    exit 1
fi
echo -e "${GREEN}✅ Port $HOST_PORT is available${NC}"

# Create deployment directory
echo -e "${BLUE}📁 Preparing deployment directory...${NC}"
mkdir -p $DEPLOY_DIR
cp -r nginx/* $DEPLOY_DIR/
cd $DEPLOY_DIR
echo -e "${GREEN}✅ Deployment directory ready${NC}"

# Build Docker image
echo -e "${BLUE}🏗️  Building Docker image...${NC}"
docker build -t $IMAGE_NAME .
echo -e "${GREEN}✅ Docker image built successfully${NC}"

# Stop and remove existing container
if docker ps -a | grep -q $CONTAINER_NAME; then
    echo -e "${YELLOW}🔄 Stopping existing container...${NC}"
    docker stop $CONTAINER_NAME &> /dev/null || true
    docker rm $CONTAINER_NAME &> /dev/null || true
    echo -e "${GREEN}✅ Existing container removed${NC}"
fi

# Run new container
echo -e "${BLUE}▶️  Starting new container on port $HOST_PORT...${NC}"
docker run -d \
    --name $CONTAINER_NAME \
    -p $HOST_PORT:$CONTAINER_PORT \
    --restart unless-stopped \
    --log-opt max-size=10m \
    --log-opt max-file=3 \
    $IMAGE_NAME

# Wait for container to start
sleep 3

# Verify container is running
if [ "$(docker ps -q -f name=$CONTAINER_NAME)" ]; then
    echo -e "${GREEN}✅ Container started successfully!${NC}"
    
    # Show container details
    echo ""
    echo -e "${BLUE}📊 Container Details:${NC}"
    docker ps --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    # Show logs
    echo ""
    echo -e "${BLUE}📋 Recent logs:${NC}"
    docker logs --tail 5 $CONTAINER_NAME
else
    echo -e "${RED}❌ Container failed to start${NC}"
    docker logs $CONTAINER_NAME
    exit 1
fi

echo ""
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Deployment Complete!${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "🌐 Application: ${BLUE}http://localhost:$HOST_PORT${NC}"
echo -e "🔍 Health check: ${BLUE}http://localhost:$HOST_PORT/health${NC}"
echo -e "📊 Metrics: ${BLUE}http://localhost:$HOST_PORT/metrics${NC}"
echo ""

# Save deployment info
cat > $DEPLOY_DIR/deployment-info.json << EOF
{
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "port": $HOST_PORT,
    "container_name": "$CONTAINER_NAME",
    "image": "$IMAGE_NAME",
    "status": "success"
}
EOF
