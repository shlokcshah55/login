#!/bin/bash

set -euo pipefail

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

PROJECT_ID="pinit-494520"
REGION="${GCP_REGION:-europe-west1}"
SERVICE_NAME="${SERVICE_NAME:-notes-import}"
IMAGE_NAME="${REGION}-docker.pkg.dev/${PROJECT_ID}/${SERVICE_NAME}/${SERVICE_NAME}"

require_env "OPENAI_API_KEY"
require_env "GOOGLE_PLACES_API_KEY"
require_env "SUPABASE_URL"
require_env "SUPABASE_SERVICE_KEY"
require_env "API_SECRET_KEY"

if ! command -v gcloud &> /dev/null; then
    echo "Error: gcloud CLI is not installed"
    exit 1
fi

echo "======================================"
echo "Notes Import - Cloud Run Deployment"
echo "======================================"
echo "Project ID: $PROJECT_ID"
echo "Region: $REGION"
echo "Service Name: $SERVICE_NAME"
echo "Image: $IMAGE_NAME"
echo "======================================"

gcloud config set project "$PROJECT_ID"
gcloud services enable run.googleapis.com
gcloud services enable artifactregistry.googleapis.com

gcloud artifacts repositories describe "$SERVICE_NAME" \
  --location="$REGION" \
  --project="$PROJECT_ID" &> /dev/null || \
gcloud artifacts repositories create "$SERVICE_NAME" \
  --repository-format=docker \
  --location="$REGION" \
  --project="$PROJECT_ID"

gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet

docker build --platform linux/amd64 -t "$IMAGE_NAME" "${SCRIPT_DIR}"
docker push "$IMAGE_NAME"

gcloud run deploy "$SERVICE_NAME" \
  --image "$IMAGE_NAME" \
  --platform managed \
  --region "$REGION" \
  --allow-unauthenticated \
  --memory 1Gi \
  --cpu 1 \
  --timeout 300 \
  --concurrency 10 \
  --max-instances 10 \
  --set-env-vars "OPENAI_API_KEY=${OPENAI_API_KEY},GOOGLE_PLACES_API_KEY=${GOOGLE_PLACES_API_KEY},SUPABASE_URL=${SUPABASE_URL},SUPABASE_SERVICE_KEY=${SUPABASE_SERVICE_KEY},LOCATION_ADD_API_URL=${LOCATION_ADD_API_URL},API_SECRET_KEY=${API_SECRET_KEY},PUSH_NOTIFICATION_URL=${PUSH_NOTIFICATION_URL:-}"

SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" --region "$REGION" --format 'value(status.url)')

echo ""
echo "Service URL: $SERVICE_URL"
echo "Health check: curl $SERVICE_URL/health"
