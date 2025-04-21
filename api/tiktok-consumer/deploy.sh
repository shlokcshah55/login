#!/bin/bash
# Deployment script for the TikTok Consumer API

# Exit on any error
set -e

# Display usage information
function show_usage {
  echo "Deploy the TikTok Consumer API to Google Cloud Run"
  echo ""
  echo "Usage: ./deploy.sh [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --project-id PROJECT_ID    Google Cloud project ID (required)"
  echo "  --region REGION            Google Cloud region (default: europe-west1)"
  echo "  --service-name NAME        Cloud Run service name (default: tiktok-consumer)"
  echo "  --pubsub-topic TOPIC       Pub/Sub topic to subscribe to (default: tiktok-links)"
  echo "  --build-only               Build the Docker image but don't deploy"
  echo "  --help                     Show this help message"
  echo ""
  echo "Example:"
  echo "  ./deploy.sh --project-id my-project-123 --region us-central1"
}

# Default values
PROJECT_ID="pinit-10b36"
REGION="europe-west1"
SERVICE_NAME="tiktok-api"
PUBSUB_TOPIC="tiktok-links"
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
    --pubsub-topic)
      PUBSUB_TOPIC="$2"
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

# Get the project number (needed for Pub/Sub permissions)
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")

# Deploy to Cloud Run with environment variables
gcloud run deploy "$SERVICE_NAME" \
  --image "$IMAGE_NAME" \
  --platform managed \
  --region "$REGION" \
  --project "$PROJECT_ID" \
  --set-env-vars="ENVIRONMENT=production,DEBUG=false" \
  --memory 512Mi \
  --cpu 1 \
  --concurrency 80 \
  --timeout 300s \
  --allow-unauthenticated

# Get the service URL
SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" --platform managed --region "$REGION" --project "$PROJECT_ID" --format 'value(status.url)')
echo "Service URL: $SERVICE_URL"

# Create Pub/Sub topic if it doesn't exist
if ! gcloud pubsub topics describe "$PUBSUB_TOPIC" --project "$PROJECT_ID" &>/dev/null; then
  echo "Creating Pub/Sub topic: $PUBSUB_TOPIC"
  gcloud pubsub topics create "$PUBSUB_TOPIC" --project "$PROJECT_ID"
fi

# Create Pub/Sub subscription with push endpoint
SUBSCRIPTION_ID="$SERVICE_NAME-subscription"
if ! gcloud pubsub subscriptions describe "$SUBSCRIPTION_ID" --project "$PROJECT_ID" &>/dev/null; then
  echo "Creating Pub/Sub subscription: $SUBSCRIPTION_ID with push endpoint to $SERVICE_URL"
  gcloud pubsub subscriptions create "$SUBSCRIPTION_ID" \
    --topic="$PUBSUB_TOPIC" \
    --push-endpoint="$SERVICE_URL" \
    --ack-deadline=60 \
    --message-retention-duration=7d \
    --project="$PROJECT_ID"
else
  echo "Updating existing Pub/Sub subscription: $SUBSCRIPTION_ID with push endpoint to $SERVICE_URL"
  gcloud pubsub subscriptions update "$SUBSCRIPTION_ID" \
    --push-endpoint="$SERVICE_URL" \
    --project="$PROJECT_ID"
fi

# Grant the Pub/Sub service account permission to invoke the Cloud Run service
gcloud run services add-iam-policy-binding "$SERVICE_NAME" \
  --member="serviceAccount:service-$PROJECT_NUMBER@gcp-sa-pubsub.iam.gserviceaccount.com" \
  --role="roles/run.invoker" \
  --region="$REGION" \
  --project="$PROJECT_ID"

echo "===== Deployment completed ====="
echo "Service deployed at: $SERVICE_URL"
echo "Pub/Sub topic: $PUBSUB_TOPIC"
echo "Pub/Sub subscription: $SUBSCRIPTION_ID"