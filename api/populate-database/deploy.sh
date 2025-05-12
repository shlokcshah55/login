#!/bin/bash
# Deployment script for the TikTok Processing API

# Exit on any error
set -e

# Display usage information
function show_usage {
  echo "Deploy the TikTok Processing API to Google Cloud Run"
  echo ""
  echo "Usage: ./deploy.sh [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --project-id PROJECT_ID    Google Cloud project ID (required)"
  echo "  --region REGION            Google Cloud region (default: europe-west1)"
  echo "  --service-name NAME        Cloud Run service name (default: tiktok-processor)"
  echo "  --gemini-key KEY           Gemini API key (will be set as environment variable)"
  echo "  --places-key KEY           Google Places API key (will be set as environment variable)"
  echo "  --supabase-url URL         Supabase project URL (will be set as environment variable)"
  echo "  --supabase-key KEY         Supabase anonymous API key (will be set as environment variable)"
  echo "  --build-only               Build the Docker image but don't deploy"
  echo "  --help                     Show this help message"
  echo ""
  echo "Example:"
  echo "  ./deploy.sh --project-id my-project-123 --region us-central1"
}

# Default values
PROJECT_ID="pinit-10b36"
REGION="europe-west1"
SERVICE_NAME="process-tiktok-link"
GEMINI_KEY="AIzaSyApUeW_QrlIPKMnYmUHneVjKdE69fJDJGs"
PLACES_KEY="AIzaSyCgqkj-ZgZOZb6vJk55H8bQ8Z_szrhla5I"
SUPABASE_URL=""
SUPABASE_KEY=""
BUILD_ONLY=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --project-id)
      PROJECT_ID="$2"
      shift 2
      ;;
    --region)
      REGION="$2"
      shift 2
      ;;
    --service-name)
      SERVICE_NAME="$2"
      shift 2
      ;;
    --gemini-key)
      GEMINI_KEY="$2"
      shift 2
      ;;
    --places-key)
      PLACES_KEY="$2"
      shift 2
      ;;
    --supabase-url)
      SUPABASE_URL="$2"
      shift 2
      ;;
    --supabase-key)
      SUPABASE_KEY="$2"
      shift 2
      ;;
    --build-only)
      BUILD_ONLY=true
      shift
      ;;
    --help)
      show_usage
      exit 0
      ;;
    *)
      echo "Error: Unknown option $1"
      show_usage
      exit 1
      ;;
  esac
done

# Check required parameters
if [ -z "$PROJECT_ID" ]; then
  echo "Error: --project-id is required"
  show_usage
  exit 1
fi

# Set up Docker image name
IMAGE_NAME="gcr.io/$PROJECT_ID/$SERVICE_NAME"

echo "===== Building multi-architecture Docker image: $IMAGE_NAME ====="
# Set up Docker buildx for multi-platform builds
docker buildx create --name mybuilder --use || true
docker buildx inspect --bootstrap

# Build and push in one step (required for multi-platform images)
echo "===== Building and pushing multi-platform image to Google Container Registry ====="
docker buildx build --platform linux/amd64 -t "$IMAGE_NAME" . --push

if [ "$BUILD_ONLY" = true ]; then
  echo "Build completed. Exiting without deployment."
  exit 0
fi

echo "===== Deploying to Cloud Run ====="
ENV_VARS=""
if [ -n "$GEMINI_KEY" ]; then
  ENV_VARS="$ENV_VARS --set-env-vars=GEMINI_API_KEY=$GEMINI_KEY"
fi
if [ -n "$PLACES_KEY" ]; then
  ENV_VARS="$ENV_VARS --set-env-vars=GOOGLE_PLACE_API_KEY=$PLACES_KEY"
fi

# Deploy to Cloud Run with appropriate service account
gcloud run deploy "$SERVICE_NAME" \
  --image "$IMAGE_NAME" \
  --platform managed \
  --region "$REGION" \
  --project "$PROJECT_ID" \
  $ENV_VARS \
  --set-env-vars="ENVIRONMENT=production,DEBUG=false,SUPABASE_URL=$SUPABASE_URL,SUPABASE_ANON_KEY=$SUPABASE_KEY" \
  --memory 1Gi \
  --cpu 1 \
  --concurrency 80 \
  --timeout 300s \
  --allow-unauthenticated

echo "===== Deployment completed ====="
echo "Service URL: $(gcloud run services describe $SERVICE_NAME --platform managed --region $REGION --project $PROJECT_ID --format 'value(status.url)')"