"""
Flask API for TikTok processing service
Exposes endpoints for Cloud Run deployment
"""
import os
import logging
import asyncio
import threading
import httpx
from dotenv import load_dotenv
from flask import Flask, request, jsonify
from processor import TikTokProcessor, detect_platform
from supabase import create_client, Client

load_dotenv()


# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize Flask app
app = Flask(__name__)

# Get API keys from environment variables
XAI_API_KEY = os.environ.get('XAI_API_KEY')
GOOGLE_PLACES_API_KEY = os.environ.get('GOOGLE_PLACES_API_KEY')
SUPABASE_URL = os.environ.get('SUPABASE_URL')
SUPABASE_SERVICE_KEY = os.environ.get('SUPABASE_SERVICE_KEY')
APPIFY_KEY = os.environ.get('APPIFY_KEY')
SEND_PUSH_NOTIF_SECRET = os.environ.get('SEND_PUSH_NOTIF_SECRET')

# Validate environment variables
if not XAI_API_KEY or not GOOGLE_PLACES_API_KEY:
    logger.error("Missing required environment variables: XAI_API_KEY or GOOGLE_PLACES_API_KEY")
    raise ValueError("Missing required API keys in environment variables")

if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
    logger.warning("Missing Supabase credentials - /process-share endpoint will not work")

if not SEND_PUSH_NOTIF_SECRET:
    logger.warning("Missing SEND_PUSH_NOTIF_SECRET - error notifications will not be sent")

# Initialize processor (singleton)
processor = TikTokProcessor(
    xai_key=XAI_API_KEY,
    gmaps_key=GOOGLE_PLACES_API_KEY,
    appify_client=APPIFY_KEY
)

# Initialize Supabase client
supabase_client: Client = None
if SUPABASE_URL and SUPABASE_SERVICE_KEY:
    supabase_client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
    logger.info("Supabase client initialized successfully")

# ===== Helper Functions =====

def send_error_notification(user_id: str, error_type: str = "generic", platform: str = "tiktok"):
    """
    Send push notification to user when processing fails

    Args:
        user_id: The user's Supabase ID
        error_type: Type of error - "already_saved", "no_location", or "generic"
    """
    try:
        if not supabase_client:
            logger.warning("Supabase client not initialized - cannot fetch fcm_token")
            return

        if not SEND_PUSH_NOTIF_SECRET:
            logger.warning("SEND_PUSH_NOTIF_SECRET not configured - skipping error notification")
            return

        # Fetch user's FCM token from Supabase
        response = supabase_client.table('users').select('fcm_token').eq('supabase_id', user_id).maybe_single().execute()

        if not response or not hasattr(response, 'data') or not response.data:
            logger.warning(f"User {user_id} not found in database")
            return

        fcm_token = response.data.get('fcm_token')

        if not fcm_token:
            logger.warning(f"User {user_id} has no fcm_token - cannot send notification")
            return

        # Determine notification content based on error type
        post_name = "that instagram post" if platform == "instagram" else "that tiktok"
        if error_type == "already_saved":
            title = "Already saved"
            body = f"you've already saved this location from {post_name}"
        elif error_type == "no_location":
            title = "No location found"
            body = f"sorry we couldn't find a location from {post_name} that you shared with us"
        else:  # generic
            title = "Oops something went wrong"
            body = f"sorry we couldn't process {post_name}. please try again later"

        # Send push notification
        notification_url = "https://send-push-notification-3e26rjbtca-ew.a.run.app/send_push_notification"
        headers = {
            "Authorization": f"Bearer {SEND_PUSH_NOTIF_SECRET}",
            "Content-Type": "application/json"
        }
        logger.info(f"Sending {error_type} error notification to user {user_id} with FCM token {fcm_token}")
        payload = {
            "fcm_token": fcm_token,
            "user_id": user_id,
            "type": "share_error",
            "title": title,
            "body": body
        }

        with httpx.Client(timeout=10.0) as client:
            response = client.post(notification_url, headers=headers, json=payload)
            response.raise_for_status()

        logger.info(f"Successfully sent {error_type} error notification to user {user_id}")

    except httpx.HTTPStatusError as e:
        logger.error(f"Push notification API returned error {e.response.status_code}: {e.response.text}")
    except Exception as e:
        logger.error(f"Error sending push notification: {e}", exc_info=True)


def save_location_to_supabase(user_id: str, place_data: dict, url: str, platform: str = "tiktok"):
    """Save location to Supabase database"""
    try:
        if not supabase_client:
            logger.error("Supabase client not initialized")
            return None

        place_id = place_data['place_id']
 
        # 1. Check if location exists
        response = supabase_client.table('locations').select('location_id').eq('google_place_id', place_id).execute()

        if response and hasattr(response, 'data') and response.data and len(response.data) > 0:
            location_id = response.data[0]['location_id']
            logger.info(f"Location already exists: {location_id}")
        else:
            # Create location
            try:
                api_url = "https://pinit-recommendations-api-1070859807237.europe-west2.run.app/locations/add"
                payload = {
                    'google_place_id': place_id,
                    'classify_photo': True
                }

                with httpx.Client(timeout=30.0) as client:
                    response = client.post(api_url, json=payload)
                    response.raise_for_status()

                api_result = response.json()
                location_id = api_result.get('location_id')

                if not location_id:
                    logger.error(f"API response missing location_id: {api_result}")
                    return None

                logger.info(f"Created new location via API: {location_id}")
            except httpx.HTTPStatusError as e:
                logger.error(f"API request failed with status {e.response.status_code}: {e.response.text}")
                return None
            except Exception as e:
                logger.error(f"Error calling location API: {e}", exc_info=True)
                return None
            
        logger.info(f"Using location url: {str(url)}")
        logger.info(f"All parameters to rpc: 'user_id': {user_id}, 'location_id': {location_id}, 'saved_method': '{platform}', 'acked': True, 'source_video_url': {str(url)}")

        # 3. Save location with tag updates using new RPC
        logger.info(type(location_id))
        try:
            result = supabase_client.rpc('save_location_with_tags', {
                'p_user_id': user_id,
                'p_location_id': location_id,
                'p_saved_method': platform,
                'p_acked': True,
                'p_source_video_url': str(url)
            }).execute()

            response = result.data

            if response and response.get('success'):
                tag_count = response.get('tag_count', 0)
                logger.info(f"Saved location {location_id} with {tag_count} tag updates ({platform} method)")
                return {
                    'location_id': location_id,
                }
            else:
                error = response.get('error', 'Unknown error') if response else 'No response'
                logger.error(f"Failed to save location via RPC: {error}")

                # Return error info so caller can handle "already saved" case
                return {
                    'error': error,
                    'location_id': location_id
                }
        except Exception as rpc_error:
            # The postgrest client throws APIError when the RPC returns a
            # non-row response like "Location already saved". Parse the
            # error message to detect this case.
            error_msg = str(rpc_error)
            if 'Location already saved' in error_msg:
                logger.info(f"Location {location_id} already saved by user (caught from RPC exception)")
                return {
                    'error': 'Location already saved',
                    'location_id': location_id
                }
            else:
                logger.error(f"RPC error saving location: {rpc_error}", exc_info=True)
                return None

    except Exception as e:
        logger.error(f"Error saving location to Supabase: {e}", exc_info=True)
        return None


def process_and_save_async(url: str, user_id: str):
    """
    Background thread function that:
    1. Processes TikTok URL
    2. Saves all locations to Supabase
    """
    try:
        platform = detect_platform(url)
        logger.info(f"Background processing started for user {user_id}, URL: {url}, platform: {platform}")

        # Check if this URL has already been processed by anyone
        if supabase_client:
            existing_actions = supabase_client.table('user_location_actions').select('location_id').eq('source_video_url', url).execute()
            if existing_actions and hasattr(existing_actions, 'data') and existing_actions.data:
                location_ids = list(set([action['location_id'] for action in existing_actions.data]))
                saved_locations = []
                for location_id in location_ids:
                    try:
                        result = supabase_client.rpc('save_location_with_tags', {
                            'p_user_id': user_id,
                            'p_location_id': location_id,
                            'p_saved_method': platform,
                            'p_acked': True,
                            'p_source_video_url': url
                        }).execute()

                        if result.data and result.data.get('success'):
                            saved_locations.append(location_id)
                            logger.info(f"Saved existing location {location_id} for user {user_id}")
                    except Exception as e:
                        logger.error(f"Error saving existing location {location_id}: {e}", exc_info=True)
                        continue

                if saved_locations:
                    logger.info(f"Successfully saved {len(saved_locations)} existing locations for user {user_id}")
                    return
                else:
                    logger.warning(f"Failed to save any existing locations for user {user_id}. Will re-process video.")
        
        # Otherwise process via apify and gpt 
        result = asyncio.run(processor.process_url(url))

        if not result.get("success"):
            error = result.get("error", "Unknown error")
            logger.error(f"Processing failed: {error}")
            send_error_notification(user_id, error_type="generic", platform=platform)
            return

        locations = result.get("locations", [])

        if not locations:
            logger.warning("No locations found in video")
            send_error_notification(user_id, error_type="no_location", platform=platform)
            return

        # Save all locations to database
        saved_locations = []
        already_saved_count = 0
        for loc_data in locations:
            logger.info(loc_data)
            try:
                location = save_location_to_supabase(
                    user_id=user_id,
                    place_data=loc_data['place'],
                    url=url,
                    platform=platform,
                )
                if location:
                    # Check if this was an "already saved" error
                    if 'error' in location and 'Location already saved' in location.get('error', ''):
                        already_saved_count += 1
                        logger.info(f"Location {location.get('location_id')} already saved by user")
                    else:
                        saved_locations.append(location)
            except Exception as e:
                logger.error(f"Error saving location: {e}", exc_info=True)
                continue

        # If all locations were already saved, send specific notification
        if already_saved_count > 0 and not saved_locations:
            logger.info(f"All {already_saved_count} locations already saved by user {user_id}")
            send_error_notification(user_id, error_type="already_saved", platform=platform)
            return

        if not saved_locations and already_saved_count == 0:
            logger.error("Failed to save any locations")
            send_error_notification(user_id, error_type="generic", platform=platform)
            return

        logger.info(f"Successfully saved {len(saved_locations)} locations for user {user_id}")

    except Exception as e:
        logger.error(f"Error in background processing: {e}", exc_info=True)
        send_error_notification(user_id, error_type="generic", platform=platform)


# ===== API Endpoints =====

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint for Cloud Run"""
    return jsonify({"status": "healthy", "service": "tiktok-processor"}), 200


@app.route('/process-share', methods=['POST'])
def process_share():
    """
    Process TikTok share from iOS share extension.
    Asynchronously processes video and saves all locations.
    Returns 202 Accepted immediately.

    Request body:
    {
        "url": "https://tiktok.com/...",
        "userId": "uuid-user-id"
    }

    Response (202):
    {
        "success": true,
        "message": "Processing started"
    }
    """
    try:
        data = request.get_json()

        if not data:
            return jsonify({
                "success": False,
                "error": "Request body must be JSON"
            }), 400

        url = data.get('url')
        user_id = data.get('userId')

        if not url or not user_id:
            return jsonify({
                "success": False,
                "error": "Missing required fields: url and userId"
            }), 400

        if not supabase_client:
            return jsonify({
                "success": False,
                "error": "Service not configured"
            }), 503

        logger.info(f"Received share request from user {user_id} for URL: {url}")

        # Start background processing (don't wait)
        thread = threading.Thread(
            target=process_and_save_async,
            args=(url, user_id)
        )
        thread.daemon = True
        thread.start()

        # Return immediately
        return jsonify({
            "success": True,
            "message": "Processing started"
        }), 202

    except Exception as e:
        logger.error(f"Error in /process-share: {e}", exc_info=True)
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500



@app.errorhandler(404)
def not_found(e):
    """Handle 404 errors"""
    return jsonify({
        "success": False,
        "error": "Endpoint not found"
    }), 404


@app.errorhandler(500)
def internal_error(e):
    """Handle 500 errors"""
    return jsonify({
        "success": False,
        "error": "Internal server error"
    }), 500


if __name__ == '__main__':
    # For local development
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port, debug=False)
