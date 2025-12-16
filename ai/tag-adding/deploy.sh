#!/bin/bash

# Tag Generation Service - Cloud Run Deployment Script
# Usage: ./deploy.sh

set -e  # Exit on any error

# Configuration
PROJECT_ID="YOUR_GCP_PROJECT_ID"  # Replace with your GCP project ID
SERVICE_NAME="tag-generation-service"
REGION="us-central1"  # Change if needed
IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}"

echo "================================================"
echo "Deploying Tag Generation Service to Cloud Run"
echo "================================================"

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo "Error: gcloud CLI not found. Please install Google Cloud SDK."
    exit 1
fi

# Check if PROJECT_ID is set
if [ "$PROJECT_ID" = "YOUR_GCP_PROJECT_ID" ]; then
    echo "Error: Please set your PROJECT_ID in deploy.sh"
    exit 1
fi

echo "✓ Project ID: $PROJECT_ID"
echo "✓ Service: $SERVICE_NAME"
echo "✓ Region: $REGION"
echo ""

# Build Docker image
echo "Building Docker image..."
docker build -t $IMAGE_NAME .

# Push to Google Container Registry
echo "Pushing image to GCR..."
docker push $IMAGE_NAME

# Deploy to Cloud Run
echo "Deploying to Cloud Run..."
gcloud run deploy $SERVICE_NAME \
  --image $IMAGE_NAME \
  --platform managed \
  --region $REGION \
  --allow-unauthenticated \
  --memory 512Mi \
  --cpu 1 \
  --timeout 60s \
  --max-instances 10 \
  --set-env-vars "SUPABASE_URL=${SUPABASE_URL},SUPABASE_KEY=${SUPABASE_KEY},OPENAI_API_KEY=${OPENAI_API_KEY}" \
  --project $PROJECT_ID

# Get the service URL
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --platform managed --region $REGION --format 'value(status.url)' --project $PROJECT_ID)

echo ""
echo "================================================"
echo "✓ Deployment successful!"
echo "================================================"
echo "Service URL: $SERVICE_URL"
echo ""
echo "Health check: curl $SERVICE_URL/health"
echo ""
echo "Test Supabase endpoint:"
echo "curl -X POST $SERVICE_URL/generate-tags/supabase \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"location_ids\": [123]}'"
echo ""
echo "Test Places API endpoint:"
echo "curl -X POST $SERVICE_URL/generate-tags/places \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"location\": {\"name\": \"Test Restaurant\", \"vicinity\": \"123 Main St\"}}'"
echo ""
