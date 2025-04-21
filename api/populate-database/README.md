# TikTok Processing API

This service processes TikTok links, extracts location data, and stores the results in Firestore.

## Local Development

1. Create a `.env` file from the template:
   ```bash
   cp .env.template .env
   ```

2. Edit the `.env` file and add your API keys and service account path.

3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

4. Run the service locally:
   ```bash
   python run_hypercorn.py
   ```

## Secure Deployment to Google Cloud

### Option 1: Using Google Cloud Run (RECOMMENDED)

This approach uses Google Cloud's built-in IAM and secret management.

1. Make your service account key available to Cloud Run by using Secret Manager:

   ```bash
   # Create a secret with your service account key
   gcloud secrets create tiktok-processor-sa-key \
     --data-file=/path/to/your-service-account-key.json \
     --project=your-project-id
   ```

2. Use the deployment script with your API keys:

   ```bash
   ./deploy.sh \
     --project-id your-project-id \
     --region europe-west1 \
     --gemini-key your-gemini-api-key \
     --places-key your-places-api-key
   ```

3. Update the service to use the secret:

   ```bash
   gcloud run services update tiktok-processor \
     --set-secrets=GOOGLE_APPLICATION_CREDENTIALS=/secrets/key.json:tiktok-processor-sa-key:latest \
     --update-volume-mounts=tiktok-processor-sa-key:/secrets/key.json:ro \
     --region=europe-west1 \
     --project=your-project-id
   ```

### Option 2: Using Docker Compose (DEVELOPMENT ONLY)

For local development or testing, you can use Docker Compose:

1. Create a `docker-compose.yml` file:

   ```yaml
   version: '3'
   
   services:
     tiktok-processor:
       build: .
       ports:
         - "8080:8080"
       volumes:
         - ./your-service-account-key.json:/secrets/key.json:ro
       environment:
         - GOOGLE_APPLICATION_CREDENTIALS=/secrets/key.json
         - GEMINI_API_KEY=your-gemini-api-key
         - GOOGLE_PLACE_API_KEY=your-places-api-key
         - ENVIRONMENT=development
         - DEBUG=true
   ```

2. Run with Docker Compose:

   ```bash
   docker-compose up
   ```

## Important Security Notes

1. NEVER commit service account keys to Git
2. NEVER include service account keys in Docker images
3. NEVER use `.env` files in production
4. Use IAM roles and service accounts properly
5. For production, use Google Secret Manager
6. Set appropriate CORS policies

## Troubleshooting

If you encounter authentication issues:

1. Verify your service account has the necessary permissions
2. Check that environment variables are set correctly
3. Confirm the service account key is mounted correctly
4. Check Docker logs for any permissions issues

## API Endpoints

- `GET /health` - Health check endpoint
- `POST /v1/process-tiktok` - Process a TikTok URL
- `POST /v1/process-pending` - Process pending TikTok links in Firestore