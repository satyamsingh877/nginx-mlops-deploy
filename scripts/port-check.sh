#!/bin/bash

# Port availability checker
echo "🔍 Port Availability Checker"
echo "══════════════════════════════"

# Ports to check
COMMON_PORTS=(80 443 3000 5000 8080 8081 8082 8083 8084 8085 8000 8001 9000)

# Check specific port if provided
if [ -n "$1" ]; then
    PORTS_TO_CHECK=($1)
else
    PORTS_TO_CHECK=(${COMMON_PORTS[@]})
fi

echo ""
echo "📡 Checking ports..."

for PORT in "${PORTS_TO_CHECK[@]}"; do
    if lsof -Pi :$PORT -sTCP:LISTEN -t &>/dev/null; then
        PID=$(lsof -t -i:$PORT)
        PROCESS=$(ps -p $PID -o comm= 2>/dev/null || echo "Unknown")
        echo -e "❌ Port $PORT is in use by: $PROCESS (PID: $PID)"
        
        # Show more details if it's a Docker container
        if docker ps --format '{{.Names}}' | grep -q "$PROCESS" 2>/dev/null; then
            echo "   📦 This is a Docker container"
            docker ps --filter "name=$PROCESS" --format "   Container: {{.Names}} ({{.Status}})"
        fi
    else
        echo -e "✅ Port $PORT is available"
    fi
done

# Show all Docker containers and their ports
echo ""
echo "📦 Docker Containers and Ports:"
if [ "$(docker ps -q)" ]; then
    docker ps --format "table {{.Names}}\t{{.Ports}}\t{{.Status}}"
else
    echo "No running containers"
fi

# Check for Jenkins specifically
echo ""
if lsof -Pi :8080 -sTCP:LISTEN -t &>/dev/null; then
    JENKINS_PID=$(lsof -t -i:8080)
    JENKINS_PROCESS=$(ps -p $JENKINS_PID -o comm=)
    echo "🔧 Jenkins detection:"
    if [[ "$JENKINS_PROCESS" == *"jenkins"* ]]; then
        echo "   ✅ Jenkins is running on port 8080 (expected)"
    else
        echo "   ⚠️  Port 8080 is used by: $JENKINS_PROCESS (not Jenkins)"
    fi
else
    echo "🔧 Jenkins is not running on port 8080"
fi

echo ""
echo "💡 Recommendation: Use port 8081 for Nginx deployment"
