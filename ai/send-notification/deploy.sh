PROJECT_ID=$(gcloud config get-value project)

gcloud functions deploy send-push-notifications \
  --gen2 \
  --runtime=python312 \
  --region=europe-west1 \
  --source=. \
  --entry-point=send_push_notification \
  --trigger-http \
  --allow-unauthenticated \
  --memory=256Mi \
  --timeout=60s \
  --docker-repository=projects/${PROJECT_ID}/locations/europe-west1/repositories/gcf-artifacts \
  --set-env-vars SUPABASE_URL="${SUPABASE_URL}" \
  --set-env-vars SUPABASE_SERVICE_KEY="${SUPABASE_SERVICE_KEY}" \
  --set-env-vars API_SECRET_KEY="${API_SECRET_KEY}"
