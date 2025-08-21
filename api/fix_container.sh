#!/bin/bash

# Script to fix and restart the RideShare API container on Azure VM

echo "🔧 Fixing RideShare API container..."

# Stop and remove the existing API container
echo "Stopping existing API container..."
docker-compose stop api
docker-compose rm -f api

# Rebuild the API image with the fixed Dockerfile
echo "Rebuilding API image..."
docker-compose build api

# Start the API container
echo "Starting API container..."
docker-compose up -d api

# Wait a few seconds and check status
sleep 5
echo "Checking container status..."
docker-compose ps

echo "Checking API container logs..."
docker-compose logs --tail=20 api

echo "✅ Fix complete! Check the logs above for any issues."
echo "API should be accessible at: http://$(curl -s ifconfig.me)/"
echo "API docs at: http://$(curl -s ifconfig.me)/docs"
