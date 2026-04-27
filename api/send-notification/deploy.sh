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

require_env "SUPABASE_URL"
require_env "SUPABASE_SERVICE_KEY"
require_env "API_SECRET_KEY"

# PROJECT_ID="${GCP_PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}"
PROJECT_ID="${PROJECT_ID:-pinit-494520}"
REGION="${GCP_REGION:-europe-west1}"
SERVICE_NAME="${SERVICE_NAME:-send-push-notifications}"

if [[ -z "$PROJECT_ID" || "$PROJECT_ID" == "(unset)" ]]; then
  echo "Error: no GCP project configured. Set GCP_PROJECT_ID or run 'gcloud config set project <id>'." >&2
  exit 1
fi

echo "Deploying ${SERVICE_NAME} to ${PROJECT_ID} (${REGION})"
echo "Using source: ${SCRIPT_DIR}"
echo "API_SECRET_KEY loaded: yes"

gcloud functions deploy "${SERVICE_NAME}" \
  --gen2 \
  --runtime=python312 \
  --region="${REGION}" \
  --source="${SCRIPT_DIR}" \
  --entry-point=send_push_notification \
  --trigger-http \
  --allow-unauthenticated \
  --memory=256Mi \
  --timeout=60s \
  --docker-repository="projects/${PROJECT_ID}/locations/${REGION}/repositories/gcf-artifacts" \
  --set-env-vars="SUPABASE_URL=${SUPABASE_URL},SUPABASE_SERVICE_KEY=${SUPABASE_SERVICE_KEY},API_SECRET_KEY=${API_SECRET_KEY}"
