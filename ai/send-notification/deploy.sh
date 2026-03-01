#!/bin/bash

# Send Push Notification - GCP Cloud Function Deployment Script

set -e  # Exit on error

# ===== Configuration =====
PROJECT_ID="${GCP_PROJECT_ID:-project-add4b0f5-0080-47ef-80f}"
REGION="europe-west1"
FUNCTION_NAME="send_push_notification"

echo "======================================"
echo "Send Push Notification - Cloud Function Deployment"
echo "======================================"
echo "Region: $REGION"
echo "Function: $FUNCTION_NAME"
echo "======================================"

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo "Error: gcloud CLI is not installed"
    echo "Install from: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Check if .env file exists
if [ ! -f .env ]; then
    echo "Error: .env file not found"
    echo "Please create a .env file based on .env.example"
    exit 1
fi

# Load environment variables from .env file
echo ""
echo "Loading environment variables from .env file..."
set -a
source .env
set +a

# Set the GCP project
echo ""
echo "Setting GCP project..."
gcloud config set project $PROJECT_ID

# Enable required APIs
echo ""
echo "Enabling required GCP APIs..."
gcloud services enable cloudfunctions.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com

# Validate required environment variables
if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_SERVICE_KEY" ] || [ -z "$API_SECRET_KEY" ]; then
    echo "Error: Missing required environment variables"
    echo "Please ensure SUPABASE_URL, SUPABASE_SERVICE_KEY, and API_SECRET_KEY are set in .env"
    exit 1
fi

# Load Firebase credentials from service account JSON file
FIREBASE_CREDENTIALS_FILE="pinit-a97eb-8f62b614bdc2.json"
if [ ! -f "$FIREBASE_CREDENTIALS_FILE" ]; then
    echo "Error: Firebase credentials file not found: $FIREBASE_CREDENTIALS_FILE"
    exit 1
fi

# Write a YAML env-vars file because the JSON value breaks --set-env-vars parsing
ENV_YAML=$(mktemp)
cat > "$ENV_YAML" <<YAML
SUPABASE_URL: "${SUPABASE_URL}"
SUPABASE_SERVICE_KEY: "${SUPABASE_SERVICE_KEY}"
API_SECRET_KEY: "${API_SECRET_KEY}"
FIREBASE_CREDENTIALS: '$(cat "$FIREBASE_CREDENTIALS_FILE" | tr -d '\n')'
YAML

# Deploy the Cloud Function
echo ""
echo "Deploying Cloud Function..."
gcloud functions deploy $FUNCTION_NAME \
  --gen2 \
  --runtime=python312 \
  --region=$REGION \
  --source=. \
  --entry-point=send_push_notification \
  --trigger-http \
  --allow-unauthenticated \
  --env-vars-file "$ENV_YAML"

rm -f "$ENV_YAML"

echo ""
echo "======================================"
echo "Deployment complete!"
echo "======================================"

# Get the function URL
FUNCTION_URL=$(gcloud functions describe $FUNCTION_NAME --region $REGION --gen2 --format 'value(serviceConfig.uri)')
echo ""
echo "Function URL: $FUNCTION_URL"
echo ""
echo "Test endpoint:"
echo "  curl -X POST $FUNCTION_URL -H 'Content-Type: application/json' -d '{\"fcm_token\":\"TOKEN\",\"user_id\":\"USER_ID\",\"type\":\"video_processed\",\"title\":\"Test\",\"body\":\"Test notification\"}'"
echo ""
