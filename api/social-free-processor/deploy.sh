#!/bin/bash

# Social Free Processor API - GCP Cloud Run Deployment Script
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

PROJECT_ID="pinit-494520"

REGION="${GCP_REGION:-europe-west1}"
SERVICE_NAME="${SERVICE_NAME:-social-free-processor}"
IMAGE_NAME="${REGION}-docker.pkg.dev/${PROJECT_ID}/${SERVICE_NAME}/${SERVICE_NAME}"

# Cloud Tasks: the queue that drives async pipeline processing.
TASKS_QUEUE="${TASKS_QUEUE:-social-share-processing}"
TASKS_LOCATION="${TASKS_LOCATION:-$REGION}"

echo "======================================"
echo "Social Free Processor - Cloud Run Deployment"
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

require_env "OPENAI_API_KEY"
require_env "GOOGLE_PLACES_API_KEY"
require_env "SUPABASE_URL"
require_env "SUPABASE_SERVICE_KEY"
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
gcloud services enable cloudtasks.googleapis.com

# ===== Cloud Tasks setup =====
# Resolve the project number → default service account used both as the Cloud
# Run runtime identity and as the OIDC principal on worker task requests.
PROJECT_NUMBER="$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')"
TASKS_SERVICE_ACCOUNT="${TASKS_SERVICE_ACCOUNT:-${PROJECT_NUMBER}-compute@developer.gserviceaccount.com}"
CLOUD_TASKS_AGENT="service-${PROJECT_NUMBER}@gcp-sa-cloudtasks.iam.gserviceaccount.com"

echo ""
echo "Ensuring Cloud Tasks queue '${TASKS_QUEUE}' exists..."
gcloud tasks queues describe "$TASKS_QUEUE" --location="$TASKS_LOCATION" &> /dev/null || \
gcloud tasks queues create "$TASKS_QUEUE" \
  --location="$TASKS_LOCATION" \
  --max-attempts=5 \
  --min-backoff=10s \
  --max-backoff=300s \
  --max-concurrent-dispatches=10

# IAM (idempotent):
#   - runtime SA may enqueue tasks
#   - the Cloud Tasks service agent may mint OIDC tokens as the invoker SA
echo ""
echo "Ensuring Cloud Tasks IAM bindings..."
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${TASKS_SERVICE_ACCOUNT}" \
  --role="roles/cloudtasks.enqueuer" --condition=None &> /dev/null
gcloud iam service-accounts add-iam-policy-binding "$TASKS_SERVICE_ACCOUNT" \
  --member="serviceAccount:${CLOUD_TASKS_AGENT}" \
  --role="roles/iam.serviceAccountTokenCreator" --condition=None &> /dev/null

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
  --service-account "${TASKS_SERVICE_ACCOUNT}" \
  --set-env-vars "OPENAI_API_KEY=${OPENAI_API_KEY},GOOGLE_PLACES_API_KEY=${GOOGLE_PLACES_API_KEY},SUPABASE_URL=${SUPABASE_URL},SUPABASE_SERVICE_KEY=${SUPABASE_SERVICE_KEY},SEND_PUSH_NOTIF_SECRET=${SEND_PUSH_NOTIF_SECRET},PUSH_NOTIFICATION_URL=${PUSH_NOTIFICATION_URL:-},LOCATIONS_ADD_URL=${LOCATIONS_ADD_URL:-},GCP_PROJECT=${PROJECT_ID},TASKS_LOCATION=${TASKS_LOCATION},TASKS_QUEUE=${TASKS_QUEUE},TASKS_SERVICE_ACCOUNT=${TASKS_SERVICE_ACCOUNT}"

# Get the service URL
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region $REGION --format 'value(status.url)')

# Second pass: WORKER_URL isn't known until the service has a URL. Set it now
# so Cloud Tasks dispatches back to /tasks/process-share (and the worker's OIDC
# audience check matches). update-env-vars merges, preserving the vars above.
WORKER_URL="${SERVICE_URL}/tasks/process-share"
echo ""
echo "Setting WORKER_URL=${WORKER_URL} ..."
gcloud run services update $SERVICE_NAME --region $REGION \
  --update-env-vars "WORKER_URL=${WORKER_URL}" > /dev/null

echo ""
echo "======================================"
echo "Deployment complete!"
echo "======================================"
echo ""
echo "Service URL: $SERVICE_URL"
echo ""
echo "Test endpoints:"
echo "  Health check: curl $SERVICE_URL/health"
echo "  Process share: curl -X POST $SERVICE_URL/process-share -H 'Content-Type: application/json' -d '{\"url\":\"SOCIAL_URL\",\"userId\":\"USER_UUID\"}'"
echo ""

if [ "$SERVICE_URL" != "https://social-free-processor-1070859807237.europe-west1.run.app" ]; then
  echo "NOTE: the iOS share extension (ios/URLShareExtension/ShareViewController.swift) is"
  echo "hardcoded to POST to https://social-free-processor-1070859807237.europe-west1.run.app/process-share"
  echo "— if this is the first deploy under this service name, that URL should already match"
  echo "(Cloud Run URLs for a given service name + project + region are stable across deploys)."
  echo "If it does NOT match the URL above, update ShareViewController.swift accordingly."
fi
echo ""
