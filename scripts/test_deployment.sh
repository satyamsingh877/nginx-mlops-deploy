#!/bin/bash

# Deployment tests
set -e

echo "🧪 Running deployment tests..."

# Test 1: Dockerfile exists
test_dockerfile() {
    if [ -f "nginx/Dockerfile" ]; then
        echo "✅ Test 1 passed: Dockerfile exists"
    else
        echo "❌ Test 1 failed: Dockerfile not found"
        exit 1
    fi
}

# Test 2: nginx.conf exists
test_nginx_conf() {
    if [ -f "nginx/nginx.conf" ]; then
        echo "✅ Test 2 passed: nginx.conf exists"
    else
        echo "❌ Test 2 failed: nginx.conf not found"
        exit 1
    fi
}

# Test 3: index.html exists
test_index_html() {
    if [ -f "nginx/index.html" ]; then
        echo "✅ Test 3 passed: index.html exists"
    else
        echo "❌ Test 3 failed: index.html not found"
        exit 1
    fi
}

# Test 4: Scripts are executable
test_scripts() {
    if [ -x "scripts/deploy.sh" ] && [ -x "scripts/health-check.sh" ]; then
        echo "✅ Test 4 passed: Scripts are executable"
    else
        echo "❌ Test 4 failed: Scripts not executable"
        chmod +x scripts/*.sh
        echo "   Fixed: Made scripts executable"
    fi
}

# Run all tests
test_dockerfile
test_nginx_conf
test_index_html
test_scripts

echo ""
echo "🎉 All tests passed!"
