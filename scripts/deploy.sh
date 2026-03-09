#!/bin/bash

# Nginx MLOps Deployment Script
set -e

# Configuration
HOST_PORT=${DEPLOY_PORT:-8081}
CONTAINER_PORT=80
CONTAINER_NAME="nginx-mlops"
IMAGE_NAME="nginx-mlops:latest"
DEPLOY_DIR="$HOME/nginx-mlops-deploy"

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
echo "  - Deploy Dir: $DEPLOY_DIR"
echo ""

# Function to print status
print_status() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"
}

# Function to print success
print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

# Function to print error
print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Function to print warning
print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    print_warning "Running as root user"
fi

# Check Docker
print_status "Checking Docker..."
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed"
    exit 1
fi

if ! docker info &> /dev/null; then
    print_error "Docker daemon is not running"
    exit 1
fi
print_success "Docker is running"

# Check port availability
print_status "Checking port $HOST_PORT..."
if command -v lsof &> /dev/null; then
    if lsof -Pi :$HOST_PORT -sTCP:LISTEN -t &> /dev/null; then
        print_error "Port $HOST_PORT is already in use by:"
        lsof -i :$HOST_PORT
        exit 1
    fi
elif command -v netstat &> /dev/null; then
    if netstat -tuln | grep -q ":$HOST_PORT "; then
        print_error "Port $HOST_PORT is already in use"
        netstat -tuln | grep ":$HOST_PORT "
        exit 1
    fi
else
    print_warning "Cannot check port availability (lsof/netstat not found)"
fi
print_success "Port $HOST_PORT is available"

# Create deployment directory
print_status "Preparing deployment directory..."
mkdir -p $DEPLOY_DIR
if [ -d "nginx" ]; then
    cp -r nginx/* $DEPLOY_DIR/ 2>/dev/null || true
else
    print_warning "nginx directory not found, using current directory"
fi
cd $DEPLOY_DIR
print_success "Deployment directory ready"

# Build Docker image
print_status "Building Docker image..."
if docker build -t $IMAGE_NAME .; then
    print_success "Docker image built successfully"
else
    print_error "Failed to build Docker image"
    exit 1
fi

# Stop and remove existing container
if docker ps -a | grep -q $CONTAINER_NAME; then
    print_status "Stopping existing container..."
    docker stop $CONTAINER_NAME &> /dev/null || true
    docker rm $CONTAINER_NAME &> /dev/null || true
    print_success "Existing container removed"
fi

# Run new container
print_status "Starting new container on port $HOST_PORT..."
if docker run -d \
    --name $CONTAINER_NAME \
    -p $HOST_PORT:$CONTAINER_PORT \
    --restart unless-stopped \
    --log-opt max-size=10m \
    --log-opt max-file=3 \
    $IMAGE_NAME; then
    
    print_success "Container started"
else
    print_error "Failed to start container"
    exit 1
fi

# Wait for container to be ready
print_status "Waiting for container to be ready..."
sleep 3

# Verify container is running
if [ "$(docker ps -q -f name=$CONTAINER_NAME)" ]; then
    print_success "Container is running"
    
    # Wait for nginx to start
    print_status "Waiting for nginx to start..."
    max_retries=10
    retry_count=0
    while [ $retry_count -lt $max_retries ]; do
        if docker exec $CONTAINER_NAME wget -q --spider http://localhost/ 2>/dev/null; then
            print_success "Nginx is responding"
            break
        fi
        retry_count=$((retry_count + 1))
        echo -n "."
        sleep 1
    done
    echo ""
    
    if [ $retry_count -eq $max_retries ]; then
        print_warning "Nginx may not be fully ready yet"
    fi
    
    # Show container details
    echo ""
    print_status "Container Details:"
    docker ps --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    # Show recent logs
    echo ""
    print_status "Recent logs:"
    docker logs --tail 5 $CONTAINER_NAME
else
    print_error "Container failed to start"
    docker logs $CONTAINER_NAME
    exit 1
fi

echo ""
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Deployment Complete!${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "🌐 Application: ${BLUE}http://localhost:$HOST_PORT${NC}"
echo -e "🔍 Health check: ${BLUE}http://localhost:$HOST_PORT/health${NC}"
echo ""

# Save deployment info
cat > $DEPLOY_DIR/deployment-info.json << EOF
{
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "port": $HOST_PORT,
    "container_name": "$CONTAINER_NAME",
    "image": "$IMAGE_NAME",
    "status": "success",
    "host": "$(hostname)"
}
EOF

print_success "Deployment info saved"
