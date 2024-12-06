#!/bin/bash

# Script to build and run Apache container
# Usage: ./run-apache-test.sh

echo "Cleaning up existing container..."
podman rm test-htaccess -f 2>/dev/null || true

echo "Building Apache image..."
if ! podman build -t custom-apache-standalone-merge .; then
    echo "Error: Build failed"
    exit 1
fi

echo "Starting container..."
if ! podman run -d -p 8080:8080 \
    -v "$(pwd)/apache-test:/var/www/html/:Z" \
    --name test-htaccess \
    localhost/custom-apache-standalone-merge; then
    echo "Error: Failed to start container"
    exit 1
fi

echo "Container started successfully"
echo "Testing container..."
sleep 2  # Give Apache time to start

# Test if the container is running
if ! podman ps | grep -q test-htaccess; then
    echo "Error: Container is not running"
    podman logs test-htaccess
    exit 1
fi

echo "Container is running. Testing HTTP connection..."
if curl -s -I http://localhost:8080 >/dev/null; then
    echo "Success: HTTP connection established"
    echo "Container is ready at http://localhost:8080"
else
    echo "Error: Could not connect to HTTP server"
    podman logs test-htaccess
    exit 1
fi
