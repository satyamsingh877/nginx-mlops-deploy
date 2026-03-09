#!/bin/bash

# Health check script for Nginx MLOps deployment
set -e

# Configuration
HOST_PORT=${DEPLOY_PORT:-8081}
CONTAINER_NAME="nginx-mlops"
MAX_RETRIES=30
RETRY_INTERVAL=2

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo -e "${BLUE}🔍 Health Check Script${NC}"
echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo "📡 Checking application on port $HOST_PORT"
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

# Check if container exists
if ! docker ps | grep -q $CONTAINER_NAME; then
    print_error "Container $CONTAINER_NAME is not running"
    
    # Check if container exists but is stopped
    if docker ps -a | grep -q $CONTAINER_NAME; then
        print_status "Container exists but is stopped. Last logs:"
        docker logs --tail 20 $CONTAINER_NAME
    fi
    exit 1
fi

# Check container health
print_status "Container Status:"
docker ps --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Check HTTP endpoint
echo ""
print_status "Checking HTTP endpoint..."
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -s -f -o /dev/null "http://localhost:$HOST_PORT" 2>/dev/null; then
        STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$HOST_PORT" 2>/dev/null)
        print_success "Main page is accessible (HTTP $STATUS_CODE)"
        
        # Get page title
        PAGE_TITLE=$(curl -s "http://localhost:$HOST_PORT" 2>/dev/null | grep -o "<title>.*</title>" | sed 's/<title>\(.*\)<\/title>/\1/')
        if [ -n "$PAGE_TITLE" ]; then
            echo "   Page title: $PAGE_TITLE"
        fi
        break
    else
        RETRY_COUNT=$((RETRY_COUNT + 1))
        if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
            print_error "Main page not accessible after $MAX_RETRIES attempts"
            echo "   Last error:"
            curl -v "http://localhost:$HOST_PORT" 2>&1 | tail -5
            exit 1
        fi
        echo -n "."
        sleep $RETRY_INTERVAL
    fi
done
echo ""

# Check health endpoint
print_status "Checking health endpoint..."
HEALTH_RESPONSE=$(curl -s "http://localhost:$HOST_PORT/health" 2>/dev/null)
if echo "$HEALTH_RESPONSE" | grep -q "healthy"; then
    print_success "Health endpoint is healthy"
    echo "   Response: $HEALTH_RESPONSE"
else
    print_error "Health check failed"
    echo "   Response: $HEALTH_RESPONSE"
    exit 1
fi

# Check metrics endpoint (optional)
print_status "Checking metrics endpoint..."
if curl -s -f -o /dev/null "http://localhost:$HOST_PORT/metrics" 2>/dev/null; then
    print_success "Metrics endpoint is accessible"
    
    # Show basic metrics
    CONNECTIONS=$(curl -s "http://localhost:$HOST_PORT/metrics" 2>/dev/null | grep -o "Active connections: [0-9]*" || echo "")
    if [ -n "$CONNECTIONS" ]; then
        echo "   $CONNECTIONS"
    fi
else
    print_warning "Metrics endpoint not available (optional)"
fi

# Get response time
print_status "Measuring response time..."
RESPONSE_TIME=$(curl -o /dev/null -s -w "%{time_total}\n" "http://localhost:$HOST_PORT" 2>/dev/null)
print_success "Response time: ${RESPONSE_TIME}s"

# Check container logs for errors
print_status "Checking recent logs for errors..."
ERROR_COUNT=$(docker logs --tail 50 $CONTAINER_NAME 2>&1 | grep -i error | wc -l | tr -d ' ')
if [ "$ERROR_COUNT" -eq "0" ]; then
    print_success "No errors found in recent logs"
else
    print_warning "Found $ERROR_COUNT errors in recent logs"
    echo "   Recent errors:"
    docker logs --tail 20 $CONTAINER_NAME 2>&1 | grep -i error | head -5 | sed 's/^/   ➜ /'
fi

# Check disk usage
print_status "Checking container disk usage..."
CONTAINER_SIZE=$(docker ps --filter "name=$CONTAINER_NAME" --format "{{.Size}}" 2>/dev/null || echo "unknown")
echo "   Container size: $CONTAINER_SIZE"

echo ""
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ All health checks passed!${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "📊 Summary:"
echo -e "  • Application: ${GREEN}Healthy${NC}"
echo -e "  • Port: $HOST_PORT"
echo -e "  • Response time: ${RESPONSE_TIME}s"
echo -e "  • Container: $CONTAINER_NAME"
echo -e "  • Status: $(docker ps --filter "name=$CONTAINER_NAME" --format "{{.Status}}")"
