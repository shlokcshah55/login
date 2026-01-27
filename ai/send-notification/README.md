# Send Push Notification Cloud Function

Google Cloud Function for sending Firebase Cloud Messaging (FCM) push notifications.

## Overview

This Cloud Function provides an HTTP endpoint for sending push notifications to user devices via FCM. It requires authentication and integrates with Supabase for configuration.

## Prerequisites

- Google Cloud CLI (`gcloud`) installed and configured
- Firebase project with FCM enabled
- Supabase project with configuration

## Setup

### 1. Create Environment File

Copy the example environment file and fill in your values:

```bash
cp .env.example .env
```

Edit `.env` with your actual values:

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your_anon_key_here
SUPABASE_SERVICE_KEY=your_service_role_key_here

# Optional - will be auto-generated if not provided
API_SECRET_KEY=your_api_secret_key_here
```

### 2. Find Your Supabase Keys

1. Go to your Supabase project dashboard
2. Navigate to Settings > API
3. Copy:
   - **URL** → `SUPABASE_URL`
   - **anon/public** → `SUPABASE_ANON_KEY`
   - **service_role** (secret!) → `SUPABASE_SERVICE_KEY`

⚠️ **Important**: Keep `SUPABASE_SERVICE_KEY` secret! It has admin access to your database.

## Deployment

### Deploy to Google Cloud Functions

Run the deployment script:

```bash
cd ai/send-notification
chmod +x deploy.sh
./deploy.sh
```

The script will:
1. Load environment variables from `.env`
2. Validate required configuration
3. Enable necessary GCP APIs
4. Deploy the Cloud Function
5. Output the function URL and API secret key

### What Gets Deployed

The Cloud Function receives these environment variables:
- `API_SECRET_KEY` - For authenticating requests
- `SUPABASE_URL` - Supabase project URL
- `SUPABASE_SERVICE_KEY` - Supabase admin key
- `SUPABASE_ANON_KEY` - Supabase public key

## Usage

### API Endpoint

```
POST https://us-central1-pinit-a97eb.cloudfunctions.net/send_push_notification
```

### Request Format

```bash
curl -X POST <FUNCTION_URL> \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer <API_SECRET_KEY>' \
  -d '{
    "fcm_token": "user_device_token",
    "title": "Notification Title",
    "body": "Notification message",
    "data": {
      "type": "video_processed",
      "id": "notif_123",
      "locationName": "Beach Cafe",
      "locationId": "loc_456",
      "timestamp": "2026-01-10T15:30:00.000Z"
    }
  }'
```

### Request Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `fcm_token` | string | Yes | User's FCM device token |
| `title` | string | No | Notification title (default: "New Notification") |
| `body` | string | No | Notification body text |
| `data` | object | No | Custom data payload (all values must be strings) |

### Response

**Success (200):**
```json
{
  "success": true,
  "message_id": "projects/pinit-a97eb/messages/123456"
}
```

**Error (400/401/500):**
```json
{
  "error": "Error message",
  "details": "Additional error details"
}
```

## Authentication

All requests must include the `Authorization` header with the API secret key:

```
Authorization: Bearer <API_SECRET_KEY>
```

The API secret key is:
- Auto-generated during first deployment if not provided
- Displayed after successful deployment
- Should be stored in Supabase Vault for backend use

## Saving API Key to Supabase

After deployment, save the API key to Supabase Vault:

```sql
INSERT INTO vault.secrets (name, secret)
VALUES ('gcp_notification_api_key', '<API_SECRET_KEY>');
```

Then use it in your backend:

```sql
SELECT decrypted_secret
FROM vault.decrypted_secrets
WHERE name = 'gcp_notification_api_key';
```

## Example: Send from Python Backend

```python
import httpx
import os

def send_notification(fcm_token, title, body, data=None):
    url = "https://us-central1-pinit-a97eb.cloudfunctions.net/send_push_notification"

    headers = {
        "Authorization": f"Bearer {os.getenv('API_SECRET_KEY')}",
        "Content-Type": "application/json"
    }

    payload = {
        "fcm_token": fcm_token,
        "title": title,
        "body": body,
        "data": data or {}
    }

    response = httpx.post(url, headers=headers, json=payload)
    return response.json()

# Usage
send_notification(
    fcm_token="user_device_token_here",
    title="Video Processed",
    body="We have saved Sunset Beach Cafe from the shared TikTok",
    data={
        "type": "video_processed",
        "id": "notif_123",
        "locationName": "Sunset Beach Cafe",
        "locationId": "loc_456",
        "timestamp": "2026-01-10T15:30:00.000Z"
    }
)
```

## Platform Configuration

The function automatically configures platform-specific settings:

### iOS (APNs)
- Sound: Default
- Badge: 1
- Content available: True

### Android
- Priority: High
- Sound: Default
- Notification priority: High

## Troubleshooting

### Deployment Fails

**Error: `SUPABASE_URL not found`**
- Make sure `.env` file exists in the current directory
- Check that the file contains `SUPABASE_URL=...`

**Error: `gcloud CLI is not installed`**
- Install from: https://cloud.google.com/sdk/docs/install

**Error: `Not authenticated`**
- Run: `gcloud auth login`

### Function Errors

**401 Unauthorized**
- Check `Authorization` header is present
- Verify API secret key is correct

**400 Invalid JSON**
- Ensure request body is valid JSON
- Check `Content-Type: application/json` header is set

**500 FCM API Error**
- Verify FCM token is valid and not expired
- Check Firebase project has FCM enabled
- Ensure service account has Firebase Admin role

## Security Notes

1. **Never commit `.env` file** - It contains secrets
2. **Keep `SUPABASE_SERVICE_KEY` secret** - It has admin access
3. **Keep `API_SECRET_KEY` secret** - It authenticates requests
4. **Use HTTPS only** - The function URL uses HTTPS
5. **Rotate keys periodically** - Best practice for security

## Development

### Local Testing

The function is designed for Cloud Functions environment. For local testing:

1. Use Functions Framework:
```bash
pip install functions-framework
functions-framework --target=send_push_notification --debug
```

2. Set environment variables:
```bash
export API_SECRET_KEY="test_key"
export SUPABASE_URL="https://your-project.supabase.co"
export SUPABASE_SERVICE_KEY="your_service_key"
```

### Dependencies

Defined in `requirements.txt`:
- `functions-framework` - Cloud Functions runtime
- `firebase-admin` - Firebase Admin SDK for FCM

## Related Documentation

- [Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging)
- [Google Cloud Functions](https://cloud.google.com/functions/docs)
- [Supabase](https://supabase.com/docs)
- [Notification System Documentation](../../NOTIFICATIONS_INTERNAL_REPRESENTATION.md)

## Support

For issues or questions, please check:
1. Cloud Function logs: `gcloud functions logs read send_push_notification --region=us-central1`
2. Firebase Console for FCM errors
3. Supabase Dashboard for database issues
