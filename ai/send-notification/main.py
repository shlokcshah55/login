import functions_framework
from firebase_admin import credentials, messaging, initialize_app
import json
import os

# Initialize Firebase Admin SDK
# Use Application Default Credentials in Cloud Functions
try:
    initialize_app()
except ValueError:
    # Already initialized
    pass

@functions_framework.http
def send_push_notification(request):
    """
    Sends FCM push notification to a specific device token.
    
    Expected JSON body:
    {
        "fcm_token": "user's FCM device token",
        "title": "Notification title",
        "body": "Notification body",
        "data": {"key": "value"}  // optional extra data
    }
    
    Required header:
    Authorization: Bearer <your-secret-key>
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
    
    # Verify authorization
    auth_header = request.headers.get('Authorization', '')
    expected_token = os.environ.get('API_SECRET_KEY', '')
    
    if not auth_header.startswith('Bearer ') or auth_header[7:] != expected_token:
        return (json.dumps({'error': 'Unauthorized'}), 401, headers)
    
    # Only accept POST requests
    if request.method != 'POST':
        return (json.dumps({'error': 'Method not allowed'}), 405, headers)
    
    try:
        # Parse request body
        request_json = request.get_json(silent=True)
        
        if not request_json:
            return (json.dumps({'error': 'Invalid JSON body'}), 400, headers)
        
        # Validate required fields
        fcm_token = request_json.get('fcm_token')
        if not fcm_token:
            return (json.dumps({'error': 'Missing fcm_token'}), 400, headers)
        
        title = request_json.get('title', 'New Notification')
        body = request_json.get('body', '')
        data = request_json.get('data', {})
        
        # Ensure data is a dict with string values
        if not isinstance(data, dict):
            data = {}
        
        # Convert all data values to strings (FCM requirement)
        data = {k: str(v) for k, v in data.items()}
        
        # Build the FCM message
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            token=fcm_token,
            data=data,
            # iOS-specific configuration
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(
                        sound='default',
                        badge=1,
                        content_available=True,
                    )
                )
            ),
            # Android-specific configuration
            android=messaging.AndroidConfig(
                priority='high',
                notification=messaging.AndroidNotification(
                    sound='default',
                    priority='high',
                )
            )
        )
        
        # Send the notification
        response = messaging.send(message)
        
        print(f"✅ Successfully sent notification to token: {fcm_token[:20]}...")
        
        return (json.dumps({
            'success': True,
            'message_id': response
        }), 200, headers)
        
    except messaging.ApiCallError as e:
        print(f"❌ FCM API Error: {e}")
        return (json.dumps({
            'error': 'FCM API error',
            'details': str(e)
        }), 500, headers)
        
    except Exception as e:
        print(f"❌ Error sending notification: {str(e)}")
        return (json.dumps({
            'error': 'Internal server error',
            'details': str(e)
        }), 500, headers)