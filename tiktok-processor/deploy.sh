#!/bin/bash

# TikTok Processor - Cloud Run Deployment Script
# This script builds and deploys the TikTok processor to Google Cloud Run

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 TikTok Processor Deployment Script${NC}"
echo ""

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}❌ Error: gcloud CLI is not installed${NC}"
    echo "Install from: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Get current project
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)

if [ -z "$PROJECT_ID" ]; then
    echo -e "${RED}❌ Error: No GCP project set${NC}"
    echo "Run: gcloud config set project YOUR-PROJECT-ID"
    exit 1
fi

echo -e "${GREEN}📦 Project: ${PROJECT_ID}${NC}"

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

# Configuration
SERVICE_NAME="tiktok-processor"
REGION="europe-west2"
IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}"

echo ""
echo -e "${GREEN}🔨 Building container...${NC}"
gcloud builds submit --tag ${IMAGE_NAME}

echo ""
echo -e "${GREEN}🚀 Deploying to Cloud Run...${NC}"
gcloud run deploy ${SERVICE_NAME} \
  --image ${IMAGE_NAME} \
  --platform managed \
  --region ${REGION} \
  --allow-unauthenticated \
  --set-env-vars OPENAI_API_KEY=${OPENAI_KEY},GOOGLE_PLACES_API_KEY=${PLACES_KEY} \
  --min-instances 1 \
  --max-instances 10 \
  --memory 4Gi \
  --cpu 2 \
  --timeout 300s

# Get the service URL
SERVICE_URL=$(gcloud run services describe ${SERVICE_NAME} --region ${REGION} --format 'value(status.url)')

echo ""
echo -e "${GREEN}✅ Deployment complete!${NC}"
echo ""
echo -e "${GREEN}📍 Service URL:${NC}"
echo -e "${YELLOW}${SERVICE_URL}${NC}"
echo ""
echo -e "${GREEN}📝 Next steps:${NC}"
echo "1. Test the endpoint:"
echo "   curl -X POST ${SERVICE_URL}/process \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"url\": \"YOUR_TIKTOK_URL\", \"userId\": \"test-user\"}'"
echo ""
echo "2. Update your Flutter app (lib/main.dart line 206):"
echo -e "   ${YELLOW}final apiUrl = '${SERVICE_URL}/process';${NC}"
echo ""
echo -e "${GREEN}🎉 Done!${NC}"
