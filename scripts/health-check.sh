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

# Check if container exists
if ! docker ps | grep -q $CONTAINER_NAME; then
    echo -e "${RED}❌ Container $CONTAINER_NAME is not running${NC}"
    exit 1
fi

# Check container health
echo -e "${BLUE}📊 Container Status:${NC}"
docker ps --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Check HTTP endpoint
echo ""
echo -e "${BLUE}🌐 Checking HTTP endpoint...${NC}"
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -s -f -o /dev/null "http://localhost:$HOST_PORT"; then
        STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$HOST_PORT")
        echo -e "${GREEN}✅ Main page is accessible (HTTP $STATUS_CODE)${NC}"
        break
    else
        RETRY_COUNT=$((RETRY_COUNT + 1))
        if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
            echo -e "${RED}❌ Main page not accessible after $MAX_RETRIES attempts${NC}"
            exit 1
        fi
        echo -e "${YELLOW}⏳ Waiting for application... ($RETRY_COUNT/$MAX_RETRIES)${NC}"
        sleep $RETRY_INTERVAL
    fi
done

# Check health endpoint
echo -e "${BLUE}🏥 Checking health endpoint...${NC}"
if curl -s -f "http://localhost:$HOST_PORT/health" | grep -q "healthy"; then
    echo -e "${GREEN}✅ Health endpoint is healthy${NC}"
else
    echo -e "${RED}❌ Health check failed${NC}"
    exit 1
fi

# Check metrics endpoint
echo -e "${BLUE}📈 Checking metrics endpoint...${NC}"
if curl -s -f -o /dev/null "http://localhost:$HOST_PORT/metrics"; then
    echo -e "${GREEN}✅ Metrics endpoint is accessible${NC}"
else
    echo -e "${YELLOW}⚠️  Metrics endpoint not available (optional)${NC}"
fi

# Get response time
echo -e "${BLUE}⏱️  Measuring response time...${NC}"
RESPONSE_TIME=$(curl -o /dev/null -s -w "%{time_total}\n" "http://localhost:$HOST_PORT")
echo -e "   Response time: ${RESPONSE_TIME}s"

# Check container logs for errors
echo -e "${BLUE}📋 Checking recent logs for errors...${NC}"
ERROR_COUNT=$(docker logs --tail 50 $CONTAINER_NAME 2>&1 | grep -i error | wc -l)
if [ $ERROR_COUNT -eq 0 ]; then
    echo -e "${GREEN}✅ No errors found in recent logs${NC}"
else
    echo -e "${YELLOW}⚠️  Found $ERROR_COUNT errors in recent logs${NC}"
    docker logs --tail 20 $CONTAINER_NAME 2>&1 | grep -i error || true
fi

echo ""
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ All health checks passed!${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "📊 Summary:"
echo -e "  - Application: ${GREEN}Healthy${NC}"
echo -e "  - Port: $HOST_PORT"
echo -e "  - Response time: ${RESPONSE_TIME}s"
echo -e "  - Container: $CONTAINER_NAME"
