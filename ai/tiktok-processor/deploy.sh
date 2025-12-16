#!/bin/bash

# TikTok Processor - Docker Hub + Render Deployment Script
# This script builds and deploys the TikTok processor to Render via Docker Hub

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 TikTok Processor Deployment Script${NC}"
echo ""

# Check if docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Error: Docker is not installed${NC}"
    echo "Install from: https://docs.docker.com/get-docker/"
    exit 1
fi

# Configuration
DOCKER_USERNAME="shlokshah5532"
IMAGE_NAME="tiktok-processor"
FULL_IMAGE="${DOCKER_USERNAME}/${IMAGE_NAME}:latest"

# Optional: Render Deploy Hook (get this from Render dashboard -> Settings -> Deploy Hook)
# Uncomment and set if you want automatic redeployment
# RENDER_DEPLOY_HOOK="https://api.render.com/deploy/srv-xxxxx?key=xxxxx"

echo -e "${GREEN}📦 Image: ${FULL_IMAGE}${NC}"

# Load API keys from .env file
echo ""
echo -e "${YELLOW}🔑 Loading API Keys from .env file...${NC}"

if [ ! -f .env ]; then
    echo -e "${RED}❌ Error: .env file not found${NC}"
    echo "Create a .env file based on .env.example with your API keys"
    exit 1
fi

# Source the .env file
export $(cat .env | grep -v '^#' | xargs)

# Validate that keys were loaded
if [ -z "$OPENAI_API_KEY" ] || [ -z "$GOOGLE_PLACES_API_KEY" ]; then
    echo -e "${RED}❌ Error: OPENAI_API_KEY or GOOGLE_PLACES_API_KEY not found in .env file${NC}"
    echo "Make sure your .env file contains both keys"
    exit 1
fi

OPENAI_KEY=$OPENAI_API_KEY
PLACES_KEY=$GOOGLE_PLACES_API_KEY

echo -e "${GREEN}✓ API keys loaded successfully${NC}"

# Check if logged into Docker Hub
echo ""
echo -e "${YELLOW}🔐 Checking Docker Hub authentication...${NC}"
if ! docker info | grep -q "Username: ${DOCKER_USERNAME}"; then
    echo -e "${YELLOW}⚠️  Not logged into Docker Hub${NC}"
    echo "Logging in..."
    docker login
fi
echo -e "${GREEN}✓ Docker Hub authenticated${NC}"

# Build the image for linux/amd64 (Render platform)
echo ""
echo -e "${GREEN}🔨 Building container for linux/amd64...${NC}"
docker build --platform linux/amd64 -t ${FULL_IMAGE} .

# Push to Docker Hub
echo ""
echo -e "${GREEN}📤 Pushing to Docker Hub...${NC}"
docker push ${FULL_IMAGE}

echo -e "${GREEN}✓ Image pushed successfully${NC}"

# Optional: Trigger Render deployment via webhook
echo ""
echo -e "${GREEN}✅ Build and push complete!${NC}"
echo ""
echo -e "${GREEN}📝 Environment Variables for Render:${NC}"
echo "Make sure these are set in your Render service (Settings -> Environment):"
echo ""
echo -e "${YELLOW}OPENAI_API_KEY${NC}=${OPENAI_KEY:0:10}...${OPENAI_KEY: -4}"
echo -e "${YELLOW}GOOGLE_PLACES_API_KEY${NC}=${PLACES_KEY:0:10}...${PLACES_KEY: -4}"
echo ""
echo -e "${GREEN}🔍 To get your Render service URL:${NC}"
echo "1. Go to your Render dashboard"
echo "2. Click on your service"
echo "3. Copy the URL (e.g., https://tiktok-processor-xxxx.onrender.com)"
echo ""
echo -e "${GREEN}📝 Test your endpoint:${NC}"
echo "curl -X POST https://your-service.onrender.com/process \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"url\": \"YOUR_TIKTOK_URL\", \"userId\": \"test-user\"}'"
echo ""
echo -e "${GREEN}🎉 Done!${NC}"