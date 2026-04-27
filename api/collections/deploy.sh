#!/bin/bash

# Collections Generator Service - Cloud Run Deployment Script
# Usage: ./deploy.sh

set -e  # Exit on any error

# Configuration
PROJECT_ID="pinit-494520"
SERVICE_NAME="collections-generator"
REGION="europe-west1"
IMAGE_NAME="${REGION}-docker.pkg.dev/${PROJECT_ID}/${SERVICE_NAME}/${SERVICE_NAME}"

echo "================================================"
echo "Deploying Collections Generator Service to Cloud Run"
echo "================================================"

# Load environment variables from .env
if [ -f "$(dirname "$0")/.env" ]; then
  export $(grep -v '^#' "$(dirname "$0")/.env" | xargs)
else
  echo "Error: .env file not found next to deploy.sh"
  exit 1
fi

if ! command -v gcloud &> /dev/null; then
    echo "Error: gcloud CLI not found. Please install Google Cloud SDK."
    exit 1
fi

if [ "$PROJECT_ID" = "YOUR_GCP_PROJECT_ID" ]; then
    echo "Error: Please set your PROJECT_ID in deploy.sh"
    exit 1
fi

echo "✓ Project ID: $PROJECT_ID"
echo "✓ Service: $SERVICE_NAME"
echo "✓ Region: $REGION"
echo ""

echo "Ensuring Artifact Registry repository exists..."
gcloud artifacts repositories describe $SERVICE_NAME \
  --location=$REGION \
  --project=$PROJECT_ID &> /dev/null || \
gcloud artifacts repositories create $SERVICE_NAME \
  --repository-format=docker \
  --location=$REGION \
  --project=$PROJECT_ID

echo "Configuring Docker auth for Artifact Registry..."
gcloud auth configure-docker ${REGION}-docker.pkg.dev --quiet

echo "Building Docker image..."
docker build --platform linux/amd64 -t $IMAGE_NAME .

echo "Pushing image to GCR..."
docker push $IMAGE_NAME

echo "Deploying to Cloud Run..."
gcloud run deploy $SERVICE_NAME \
  --image $IMAGE_NAME \
  --platform managed \
  --region $REGION \
  --allow-unauthenticated \
  --memory 256Mi \
  --cpu 1 \
  --timeout 120s \
  --max-instances 10 \
  --set-env-vars "SUPABASE_URL=${SUPABASE_URL},SUPABASE_SERVICE_KEY=${SUPABASE_SERVICE_KEY},XAI_API_KEY=${XAI_API_KEY}" \
  --project $PROJECT_ID

SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --platform managed --region $REGION --format 'value(status.url)' --project $PROJECT_ID)

echo ""
echo "================================================"
echo "✓ Deployment successful!"
echo "================================================"
echo "Service URL: $SERVICE_URL"
echo ""
echo "Health check: curl $SERVICE_URL/health"
echo ""
echo "Test generate endpoint:"
echo "curl -X POST $SERVICE_URL/generate-collections \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"user_id\": \"<user-uuid>\"}'"
echo ""
