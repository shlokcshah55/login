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
REGION="europe-west2"
SERVICE_NAME="tiktok-processor"
GEMINI_KEY="AIzaSyApUeW_QrlIPKMnYmUHneVjKdE69fJDJGs"
PLACES_KEY="AIzaSyCgqkj-ZgZOZb6vJk55H8bQ8Z_szrhla5I"
SUPABASE_URL="https://umjoqvsfqhirysdjxnaf.supabase.co"
SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVtam9xdnNmcWhpcnlzZGp4bmFmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDU2NzgxNjAsImV4cCI6MjA2MTI1NDE2MH0.cpGRBaTnfqKLkPxq6Wv0e7boGGH_qZgeqYH55Xr1k90"
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
      SUPABASE_ANON_KEY="$2"
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
docker buildx build --platform linux/amd64 -t "$IMAGE_NAME" -f Dockerfile . --push

if [ "$BUILD_ONLY" = true ]; then
  echo "Build completed. Exiting without deployment."
  exit 0
fi

echo "===== Deploying to Cloud Run ====="

# Collect all environment variables
MS_TOKENS=${MS_TOKENS:-""}
FIREBASE_PROJECT_ID=${FIREBASE_PROJECT_ID:-"pinit-10b36"}

# Check for required environment variables
if [ -z "$GEMINI_KEY" ]; then
  echo "Warning: GEMINI_KEY is not set or empty"
fi

if [ -z "$PLACES_KEY" ]; then
  echo "Warning: PLACES_KEY is not set or empty"
fi

if [ -z "$SUPABASE_URL" ]; then
  echo "Warning: SUPABASE_URL is not set or empty"
fi

if [ -z "$SUPABASE_ANON_KEY" ]; then
  echo "Warning: SUPABASE_ANON_KEY is not set or empty"
fi

# Print environment variables for debugging
echo "Deploying with environment variables:"
echo "  GEMINI_API_KEY: [REDACTED]"
echo "  GOOGLE_PLACE_API_KEY: [REDACTED]"
echo "  SUPABASE_URL: $SUPABASE_URL"
echo "  SUPABASE_ANON_KEY: [REDACTED]"

# Deploy to Cloud Run with all environment variables
gcloud run deploy "$SERVICE_NAME" \
  --image "$IMAGE_NAME" \
  --platform managed \
  --region "$REGION" \
  --project "$PROJECT_ID" \
  --set-env-vars="ENVIRONMENT=production,DEBUG=false,GEMINI_API_KEY=$GEMINI_KEY,GOOGLE_PLACE_API_KEY=$PLACES_KEY,SUPABASE_URL=$SUPABASE_URL,SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY,MS_TOKENS=$MS_TOKENS,FIREBASE_PROJECT_ID=$FIREBASE_PROJECT_ID" \
  --memory 1Gi \
  --cpu 1 \
  --concurrency 80 \
  --timeout 300s \
  --allow-unauthenticated

echo "===== Deployment completed ====="
echo "Service URL: $(gcloud run services describe $SERVICE_NAME --platform managed --region $REGION --project $PROJECT_ID --format 'value(status.url)')"