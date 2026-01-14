gcloud functions deploy send_push_notification \
  --gen2 \
  --runtime=python312 \
  --region=europe-west1 \
  --source=. \
  --entry-point=send_push_notification \
  --trigger-http \
  --allow-unauthenticated \
  --set-env-vars SUPABASE_URL="https://xxxxx.supabase.co" \
  --set-env-vars SUPABASE_SERVICE_KEY="YOUR_SERVICE_ROLE_KEY" \
  --set-env-vars API_SECRET_KEY="YOUR_API_AUTH_KEY"

