import functions_framework
from firebase_admin import credentials, messaging, initialize_app, get_app
from supabase import create_client, Client
import hmac
import json
import os

from deeplink import (
    DeepLinkResolutionError,
    KNOWN_TYPES,
    find_existing_deep_link,
    normalize_notification_type,
    resolve_deep_link,
)

# 1. Initialize Firebase Admin SDK using the bundled service account JSON
_CRED_PATH = os.environ.get(
    'GOOGLE_APPLICATION_CREDENTIALS',
    'pinit-a97eb-8f62b614bdc2.json',
)
try:
    get_app()
except ValueError:
    initialize_app(credentials.Certificate(_CRED_PATH))

# 2. Lazy Supabase client — initialised on first request so that missing
#    env vars at container start don't crash the healthcheck.
_supabase: Client | None = None

def _get_supabase() -> Client:
    global _supabase
    if _supabase is None:
        url = os.environ['SUPABASE_URL']
        key = os.environ['SUPABASE_SERVICE_KEY']
        _supabase = create_client(url, key)
    return _supabase

@functions_framework.http
def send_push_notification(request):
    """
    Sends FCM push notification and persists it to Supabase.
    
    Expected JSON body:
    {
        "fcm_token": "device_token",
        "user_id": "supabase_user_uuid",
        "type": "video_processed",
        "title": "Notification Title",
        "body": "Notification Body",
        "metadata": {
            "locationId": "123",
            "locationName": "Beach Cafe"
        }
    }
    """
    
    # Handle CORS preflight
    if request.method == 'OPTIONS':
        headers = {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'POST',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization',
            'Access-Control-Max-Age': '3600'
        }
        return ('', 204, headers)
    
    # CORS headers for actual request
    headers = {
        'Access-Control-Allow-Origin': '*',
        'Content-Type': 'application/json'
    }
    
    # 3. Verify Authorization
    auth_header = request.headers.get('Authorization', '')
    expected_token = os.environ.get('API_SECRET_KEY', '')

    # Fail closed if the shared secret is not configured, otherwise an empty
    # expected_token would authorize any request presenting an empty bearer.
    if not expected_token:
        print("❌ API_SECRET_KEY is not configured; rejecting request")
        return (json.dumps({'error': 'Server misconfigured'}), 500, headers)

    provided_token = auth_header[7:] if auth_header.startswith('Bearer ') else ''
    if not hmac.compare_digest(provided_token, expected_token):
        return (json.dumps({'error': 'Unauthorized'}), 401, headers)
    
    if request.method != 'POST':
        return (json.dumps({'error': 'Method not allowed'}), 405, headers)
    
    try:
        request_json = request.get_json(silent=True)
        if not request_json:
            return (json.dumps({'error': 'Invalid JSON body'}), 400, headers)
        
        # 4. Extract and Validate Fields
        fcm_token = request_json.get('fcm_token')
        user_id = request_json.get('user_id')  # Required for DB persistence
        notif_type_raw = request_json.get('type')  # Maps to Flutter NotificationType enum
        
        if not all([fcm_token, user_id, notif_type_raw]):
            return (json.dumps({'error': 'Missing fcm_token, user_id, or type'}), 400, headers)

        notif_type = normalize_notification_type(notif_type_raw)
        if not notif_type:
            return (json.dumps({'error': 'Missing type'}), 400, headers)
        if notif_type not in KNOWN_TYPES:
            return (
                json.dumps(
                    {
                        "error": "Unknown notification type",
                        "type": str(notif_type_raw),
                    }
                ),
                400,
                headers,
            )
        
        title = request_json.get('title', 'New Notification')
        body = request_json.get('body', '')
        metadata = request_json.get('metadata', {})  # Subclass specific data (e.g. locationId)
        if metadata is None:
            metadata = {}
        if not isinstance(metadata, dict):
            return (
                json.dumps({"error": "metadata must be an object"}),
                400,
                headers,
            )

        # Auto-populate deepLink in metadata + FCM data when missing.
        if find_existing_deep_link(metadata) is None:
            deep_link = resolve_deep_link(notif_type, metadata)
            if deep_link is not None:
                metadata["deepLink"] = deep_link

        # 5. Persist to Supabase Database
        # We save this first to generate the unique notification_id
        db_record = {
            "user_id": user_id,
            "type": notif_type,
            "title": title,
            "message": body,
            "metadata": metadata,
            "is_read": False
        }
        
        db_response = _get_supabase().table("notifications").insert(db_record).execute()
        
        if not db_response.data:
            raise Exception("Failed to insert notification into database")
            
        # Get the UUID generated by Supabase
        notification_id = db_response.data[0]['id']

        # 6. Prepare FCM Data Payload
        # We merge the DB ID and the metadata so Flutter can parse the subclass
        # All values MUST be strings for FCM data
        fcm_data = {
            "id": str(notification_id),
            "type": str(notif_type),
            "timestamp": db_response.data[0]['created_at'],
            "title": title,
            "body": body,
        }
        
        # Flatten metadata into the top-level data object for the Flutter factory
        for key, value in metadata.items():
            fcm_data[key] = str(value)
        
        # 7. Build the FCM Message
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            token=fcm_token,
            data=fcm_data,
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(
                        sound='default',
                        badge=1,
                        content_available=True,
                    )
                )
            ),
            android=messaging.AndroidConfig(
                priority='high',
                notification=messaging.AndroidNotification(
                    sound='default',
                    priority='high',
                )
            )
        )
        
        # 8. Send the notification
        fcm_response = messaging.send(message)
        
        return (json.dumps({
            'success': True,
            'notification_id': str(notification_id),
            'fcm_message_id': fcm_response
        }), 200, headers)
        
    except DeepLinkResolutionError as e:
        return (
            json.dumps({"error": "Invalid metadata for notification type", "details": str(e)}),
            400,
            headers,
        )
    except ValueError as e:
        # Catches FCM-specific errors (invalid token, etc.)
        print(f"❌ FCM Error: {e}")
        return (json.dumps({'error': 'FCM error'}), 500, headers)

    except Exception as e:
        print(f"❌ Error: {str(e)}")
        return (json.dumps({'error': 'Internal server error'}), 500, headers)
