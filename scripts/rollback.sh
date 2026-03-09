#!/bin/bash

# Rollback script for Nginx deployment
set -e

# Configuration
CONTAINER_NAME="nginx-mlops"
IMAGE_NAME="nginx-mlops:latest"
BACKUP_IMAGE="nginx-mlops:backup"

echo "🔄 Starting rollback process..."

# Check if backup exists
if docker images | grep -q "nginx-mlops.*backup"; then
    echo "📦 Found backup image"
    
    # Stop current container
    echo "🛑 Stopping current container..."
    docker stop $CONTAINER_NAME || true
    docker rm $CONTAINER_NAME || true
    
    # Restore from backup
    echo "🔄 Restoring from backup..."
    docker tag $BACKUP_IMAGE $IMAGE_NAME
    
    # Start container with previous version
    echo "▶️ Starting previous version..."
    ./scripts/deploy.sh
    
    echo "✅ Rollback completed"
else
    echo "❌ No backup image found"
    exit 1
fi
