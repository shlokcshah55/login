#!/bin/bash

# TikTok Processor API - GCP Cloud Run Deployment Script
# This script builds and deploys the Docker image to Google Cloud Run

set -euo pipefail  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

load_dotenv_file() {
    local file_path="$1"
    [[ -f "$file_path" ]] || return 0

    while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
        local line="$raw_line"

        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"

        [[ -z "$line" ]] && continue
        [[ "${line:0:1}" == "#" ]] && continue
        [[ "$line" != *"="* ]] && continue

        local key="${line%%=*}"
        local value="${line#*=}"

        key="${key%"${key##*[![:space:]]}"}"
        value="${value#"${value%%[![:space:]]*}"}"

        if [[ "$value" =~ ^\".*\"$ ]] || [[ "$value" =~ ^\'.*\'$ ]]; then
            value="${value:1:${#value}-2}"
        fi

        export "$key=$value"
    done < "$file_path"
}

require_env() {
    local key="$1"
    if [[ -z "${!key:-}" ]]; then
        echo "Error: missing required environment variable: $key" >&2
        exit 1
    fi
}

load_dotenv_file "${SCRIPT_DIR}/.env"
load_dotenv_file "${REPO_ROOT}/.env"

# ===== Configuration =====
# You can modify these or pass them as environment variables

PROJECT_ID="${GCP_PROJECT_ID:-project-add4b0f5-0080-47ef-80f}"
REGION="${GCP_REGION:-europe-west1}"
SERVICE_NAME="${SERVICE_NAME:-tiktok-processor}"
IMAGE_NAME="${REGION}-docker.pkg.dev/${PROJECT_ID}/${SERVICE_NAME}/${SERVICE_NAME}"

echo "======================================"
echo "TikTok Processor - Cloud Run Deployment"
echo "======================================"
echo "Project ID: $PROJECT_ID"
echo "Region: $REGION"
echo "Service Name: $SERVICE_NAME"
echo "Image: $IMAGE_NAME"
echo "======================================"

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo "Error: gcloud CLI is not installed"
    echo "Install from: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Check if .env file exists
if [ ! -f "${SCRIPT_DIR}/.env" ] && [ ! -f "${REPO_ROOT}/.env" ]; then
    echo "Error: .env file not found"
    echo "Please create a .env file with required environment variables"
    exit 1
fi

if [ -z "${SEND_PUSH_NOTIF_SECRET:-}" ] && [ -n "${API_SECRET_KEY:-}" ]; then
    SEND_PUSH_NOTIF_SECRET="${API_SECRET_KEY}"
    export SEND_PUSH_NOTIF_SECRET
fi

require_env "SEND_PUSH_NOTIF_SECRET"

# Set the GCP project
echo ""
echo "Setting GCP project..."
gcloud config set project $PROJECT_ID

# Enable required APIs (if not already enabled)
echo ""
echo "Enabling required GCP APIs..."
gcloud services enable run.googleapis.com
gcloud services enable artifactregistry.googleapis.com

# Ensure Artifact Registry repository exists
echo ""
echo "Ensuring Artifact Registry repository exists..."
gcloud artifacts repositories describe $SERVICE_NAME \
  --location=$REGION \
  --project=$PROJECT_ID &> /dev/null || \
gcloud artifacts repositories create $SERVICE_NAME \
  --repository-format=docker \
  --location=$REGION \
  --project=$PROJECT_ID

# Configure Docker auth for Artifact Registry
echo ""
echo "Configuring Docker auth for Artifact Registry..."
gcloud auth configure-docker ${REGION}-docker.pkg.dev --quiet

# Build the Docker image locally
echo ""
echo "Building Docker image locally..."
docker build --platform linux/amd64 -t $IMAGE_NAME "${SCRIPT_DIR}"

# Push to Artifact Registry
echo ""
echo "Pushing image to Artifact Registry..."
docker push $IMAGE_NAME

# Deploy to Cloud Run
echo ""
echo "Deploying to Cloud Run..."
gcloud run deploy $SERVICE_NAME \
  --image $IMAGE_NAME \
  --platform managed \
  --region $REGION \
  --allow-unauthenticated \
  --memory 4Gi \
  --cpu 2 \
  --timeout 300 \
  --concurrency 10 \
  --max-instances 10 \
  --set-env-vars "PLAYWRIGHT_BROWSERS_PATH=/ms-playwright,PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1,DISPLAY=:99,DBUS_SESSION_BUS_ADDRESS=/dev/null,OPENAI_API_KEY=${OPENAI_API_KEY},GOOGLE_PLACES_API_KEY=${GOOGLE_PLACES_API_KEY},SUPABASE_URL=${SUPABASE_URL},SUPABASE_SERVICE_KEY=${SUPABASE_SERVICE_KEY},APPIFY_KEY=${APPIFY_KEY},SEND_PUSH_NOTIF_SECRET=${SEND_PUSH_NOTIF_SECRET},PUSH_NOTIFICATION_URL=${PUSH_NOTIFICATION_URL}"

echo ""
echo "======================================"
echo "Deployment complete!"
echo "======================================"

# Get the service URL
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region $REGION --format 'value(status.url)')
echo ""
echo "Service URL: $SERVICE_URL"
echo ""
echo "Test endpoints:"
echo "  Health check: curl $SERVICE_URL/health"
echo "  Process TikTok: curl -X POST $SERVICE_URL/process -H 'Content-Type: application/json' -d '{\"url\":\"TIKTOK_URL\"}'"
echo ""
