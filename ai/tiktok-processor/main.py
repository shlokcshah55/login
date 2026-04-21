"""
Flask API for TikTok processing service
Exposes endpoints for Cloud Run deployment
"""
import os
import logging
import asyncio
import threading
import httpx
from urllib.parse import urlparse
from flask import Flask, request, jsonify
from processor import TikTokProcessor
from supabase import create_client, Client
from dotenv import load_dotenv

# Load environment variables from .env file
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
OPENAI_API_KEY = os.environ.get('OPENAI_API_KEY')
GOOGLE_PLACES_API_KEY = os.environ.get('GOOGLE_PLACES_API_KEY')
SUPABASE_URL = os.environ.get('SUPABASE_URL')
SUPABASE_SERVICE_KEY = os.environ.get('SUPABASE_SERVICE_KEY')
APPIFY_KEY = os.environ.get('APPIFY_KEY')
SEND_PUSH_NOTIF_SECRET = os.environ.get('SEND_PUSH_NOTIF_SECRET')

# locations/add endpoint — override with LOCATIONS_ADD_URL env var for local testing
# e.g. LOCATIONS_ADD_URL=http://localhost:8000/locations/add
LOCATIONS_ADD_URL = os.environ.get(
    'LOCATIONS_ADD_URL',
    'https://pinit-recommendations-api-1070859807237.europe-west2.run.app/locations/add',
)
DEFAULT_PUSH_NOTIFICATION_URL = (
    'https://europe-west1-project-add4b0f5-0080-47ef-80f.cloudfunctions.net/send-push-notifications'
)


def _normalize_url(value: str | None, default: str) -> str:
    """Return a usable absolute URL for outbound HTTP calls."""
    candidate = (value or '').strip().strip('"').strip("'")
    if not candidate:
        return default
    if not candidate.startswith(('http://', 'https://')):
        candidate = f'https://{candidate}'

    parsed = urlparse(candidate)
    if not parsed.scheme or not parsed.netloc:
        logger.warning("Invalid PUSH_NOTIFICATION_URL %r, falling back to default", value)
        return default
    return candidate


PUSH_NOTIFICATION_URL = _normalize_url(
    os.environ.get('PUSH_NOTIFICATION_URL'),
    DEFAULT_PUSH_NOTIFICATION_URL,
)

# Validate environment variables
if not OPENAI_API_KEY or not GOOGLE_PLACES_API_KEY:
    logger.error("Missing required environment variables: OPENAI_API_KEY or GOOGLE_PLACES_API_KEY")
    raise ValueError("Missing required API keys in environment variables")

if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
    logger.warning("Missing Supabase credentials - /process-share endpoint will not work")

if not SEND_PUSH_NOTIF_SECRET:
    logger.warning("Missing SEND_PUSH_NOTIF_SECRET - error notifications will not be sent")

# Initialize processor (singleton)
processor = TikTokProcessor(
    openaiKey=OPENAI_API_KEY,
    gmaps_key=GOOGLE_PLACES_API_KEY,
    appify_client=APPIFY_KEY
)

# Initialize Supabase client
supabase_client: Client = None
if SUPABASE_URL and SUPABASE_SERVICE_KEY:
    supabase_client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
    logger.info("Supabase client initialized successfully")

# ===== Helper Functions =====

def send_error_notification(user_id: str, error_type: str = "generic", tiktok_url: str = None):
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
        if error_type == "already_saved":
            title = "Already saved"
            body = "you've already saved this location from that tiktok"
        elif error_type == "no_location":
            title = "No location found"
            body = "sorry we couldn't find a location from that tiktok that you shared with us"
        else:  # generic
            title = "Oops something went wrong"
            body = "sorry we couldn't process that tiktok. please try again later"

        # Send push notification through the currently deployed notification function
        notification_url = PUSH_NOTIFICATION_URL
        headers = {
            "Authorization": f"Bearer {SEND_PUSH_NOTIF_SECRET}",
            "Content-Type": "application/json"
        }
        payload = {
            "fcm_token": fcm_token,
            "user_id": user_id,
            "type": "processing_error",
            "title": title,
            "body": body,
            "metadata": {
                "errorType": error_type,
                **({"tiktokUrl": tiktok_url} if tiktok_url else {}),
            },
        }

        logger.info(f"Sending error notification to {notification_url} for user {user_id}")
        with httpx.Client(timeout=10.0) as client:
            response = client.post(notification_url, headers=headers, json=payload)
            response.raise_for_status()

        logger.info(f"Successfully sent {error_type} error notification to user {user_id}")

    except httpx.HTTPStatusError as e:
        logger.error(f"Push notification API returned error {e.response.status_code}: {e.response.text}")
    except Exception as e:
        logger.error(f"Error sending push notification: {e}", exc_info=True)


def send_success_notification(user_id: str, saved_locations: list):
    """
    Send a single push notification when one or more locations are successfully saved.
    If multiple locations, clusters them into one notification.
    """
    try:
        if not supabase_client:
            logger.warning("Supabase client not initialized - cannot fetch fcm_token")
            return

        if not SEND_PUSH_NOTIF_SECRET:
            logger.warning("SEND_PUSH_NOTIF_SECRET not configured - skipping success notification")
            return

        response = supabase_client.table('users').select('fcm_token').eq('supabase_id', user_id).maybe_single().execute()

        if not response or not hasattr(response, 'data') or not response.data:
            logger.warning(f"User {user_id} not found in database")
            return

        fcm_token = response.data.get('fcm_token')

        if not fcm_token:
            logger.warning(f"User {user_id} has no fcm_token - cannot send notification")
            return

        first_name = saved_locations[0].get('name') or 'a location'
        extra = len(saved_locations) - 1

        if extra > 0:
            body = f"We found {first_name} + {extra} more place{'s' if extra > 1 else ''} from your video."
        else:
            body = f"We found {first_name} from your video."

        notification_url = PUSH_NOTIFICATION_URL
        headers = {
            "Authorization": f"Bearer {SEND_PUSH_NOTIF_SECRET}",
            "Content-Type": "application/json"
        }
        payload = {
            "fcm_token": fcm_token,
            "user_id": user_id,
            "type": "video_processed",
            "title": "Saved!",
            "body": body,
            "metadata": {
                "locationId": saved_locations[0].get('location_id'),
                "locationName": first_name,
                "totalLocations": len(saved_locations),
            },
        }

        logger.info(f"Sending success notification to {notification_url} for user {user_id}")
        with httpx.Client(timeout=10.0) as client:
            resp = client.post(notification_url, headers=headers, json=payload)
            resp.raise_for_status()

        logger.info(f"Successfully sent success notification to user {user_id}")

    except httpx.HTTPStatusError as e:
        logger.error(f"Push notification API returned error {e.response.status_code}: {e.response.text}")
    except Exception as e:
        logger.error(f"Error sending success notification: {e}", exc_info=True)


def save_video_insights(location_id: int, url: str, loc_data: dict, video_data: dict):
    """
    Upsert global video insights (shared across all users who save the same
    video) and write per-user video_extras (special offers) onto the action row.
    """
    try:
        if not supabase_client:
            return

        # ── Global: upsert video_insights ─────────────────────────────────
        insight_row = {
            'source_video_url': url,
            'location_id': location_id,
            'key_dishes': loc_data.get('key_dishes') or [],
            'special_offers': loc_data.get('special_offers') or [],
            'creator_notes': loc_data.get('creator_notes'),
            'vibe_signals': loc_data.get('vibe_signals') or {},
            'sentiment': loc_data.get('sentiment'),
            'creator_handle': (video_data or {}).get('creator_handle'),
            'video_description': (video_data or {}).get('description', ''),
            'extraction_model': 'gpt-4o-mini',
        }

        supabase_client.table('video_insights').upsert(
            insight_row,
            on_conflict='source_video_url,location_id',
        ).execute()

        logger.info(f"Upserted video_insights for location {location_id}, url={url}")

    except Exception as e:
        # Non-fatal — the location is already saved, insights are bonus
        logger.warning(f"Failed to upsert video_insights: {e}", exc_info=True)


def save_video_extras(user_id: str, location_id: int, url: str, loc_data: dict):
    """
    Write per-user video_extras (special offers, personal notes) onto the
    user_location_actions row that was just created.
    """
    try:
        if not supabase_client:
            return

        special_offers = loc_data.get('special_offers') or []
        if not special_offers:
            return

        video_extras = {
            'special_offers': special_offers,
        }

        supabase_client.table('user_location_actions').update({
            'video_extras': video_extras,
        }).eq('user_id', user_id) \
          .eq('location_id', location_id) \
          .eq('source_video_url', url) \
          .execute()

        logger.info(f"Updated video_extras for user {user_id}, location {location_id}")

    except Exception as e:
        logger.warning(f"Failed to update video_extras: {e}", exc_info=True)


def save_location_to_supabase(user_id: str, place_data: dict, url: str,
                              loc_data: dict = None, video_data: dict = None):
    """
    Save location to Supabase database, then persist video insights
    and per-user video extras.
    """
    try:
        if not supabase_client:
            logger.error("Supabase client not initialized")
            return None

        place_id = place_data['place_id']

        # Always call locations/add to ensure vibe tags and data are populated
        # Derive source from the video URL
        source = 'instagram' if 'instagram' in url else 'tiktok'
        try:
            payload = {
                'google_place_id': place_id,
                'source': source,
                'classify_photo': True,
            }

            with httpx.Client(timeout=30.0) as client:
                response = client.post(LOCATIONS_ADD_URL, json=payload)
                response.raise_for_status()

            api_result = response.json()
            location_id = api_result.get('location_id')

            if not location_id:
                logger.error(f"API response missing location_id: {api_result}")
                return None

            logger.info(f"Location via /locations/add API: {location_id}")
        except httpx.HTTPStatusError as e:
            logger.error(f"API request failed with status {e.response.status_code}: {e.response.text}")
            return None
        except Exception as e:
            logger.error(f"Error calling location API: {e}", exc_info=True)
            return None
            
        logger.info(f"Using location tiktok url: {str(url)}")
        logger.info(f"All parameters to rpc: 'user_id': {user_id}, 'location_id': {location_id}, 'saved_method': 'tiktok', 'acked': True, 'source_video_url': {str(url)}")

        # 3. Save location with tag updates using new RPC
        logger.info(type(location_id))
        # If the url has instagram in it saved method will be instagram, otherwise tiktok (to differentiate from manual saves)
        result = supabase_client.rpc('save_location_with_tags', {
            'p_user_id': user_id,
            'p_location_id': location_id,
            'p_saved_method': 'instagram' if 'instagram' in url else 'tiktok',
            'p_acked': True,
            'p_source_video_url': str(url)
        }).execute()

        response = result.data

        if response and response.get('success'):
            tag_count = response.get('tag_count', 0)
            logger.info(f"Saved location {location_id} with {tag_count} tag updates (TikTok method)")

            # ── Persist video insights & per-user extras ──────────────
            if loc_data:
                save_video_insights(location_id, url, loc_data, video_data or {})
                save_video_extras(user_id, location_id, url, loc_data)

            return {
                'location_id': location_id,
                'name': place_data.get('name'),
            }
        else:
            error = response.get('error', 'Unknown error') if response else 'No response'
            logger.error(f"Failed to save location via RPC: {error}")

            # Return error info so caller can handle "already saved" case
            return {
                'error': error,
                'location_id': location_id
            }

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
        logger.info(f"Background processing started for user {user_id}, URL: {url}")

        # Check if this URL has already been processed by anyone
        if supabase_client:
            existing_actions = supabase_client.table('user_location_actions').select('location_id').eq('source_video_url', url).execute()
            if existing_actions and hasattr(existing_actions, 'data') and existing_actions.data:
                location_ids = list(set([action['location_id'] for action in existing_actions.data]))
                saved_locations = []
                for location_id in location_ids:
                    try:
                        # Call locations/add to ensure vibe tags and data are populated
                        loc_row = supabase_client.table('locations').select('google_place_id').eq('location_id', location_id).maybe_single().execute()
                        if loc_row and loc_row.data and loc_row.data.get('google_place_id'):
                            try:
                                source = 'instagram' if 'instagram' in url else 'tiktok'
                                with httpx.Client(timeout=30.0) as client:
                                    resp = client.post(LOCATIONS_ADD_URL, json={
                                        'google_place_id': loc_row.data['google_place_id'],
                                        'source': source,
                                        'classify_photo': True,
                                    })
                                    resp.raise_for_status()
                                logger.info(f"Ensured location {location_id} has vibe tags via /locations/add")
                            except Exception as e:
                                logger.warning(f"locations/add call failed for {location_id}, continuing: {e}")

                        result = supabase_client.rpc('save_location_with_tags', {
                            'p_user_id': user_id,
                            'p_location_id': location_id,
                            'p_saved_method': 'tiktok',
                            'p_acked': True,
                            'p_source_video_url': url
                        }).execute()

                        if result.data and result.data.get('success'):
                            name_row = supabase_client.table('locations').select('name').eq('location_id', location_id).maybe_single().execute()
                            loc_name = name_row.data.get('name') if name_row and name_row.data else None
                            saved_locations.append({'location_id': location_id, 'name': loc_name})
                            logger.info(f"Saved existing location {location_id} for user {user_id}")
                    except Exception as e:
                        logger.error(f"Error saving existing location {location_id}: {e}", exc_info=True)
                        continue

                if saved_locations:
                    logger.info(f"Successfully saved {len(saved_locations)} existing locations for user {user_id}")
                    send_success_notification(user_id, saved_locations)
                    return
                else:
                    logger.warning(f"Failed to save any existing locations for user {user_id}. Will re-process video.")
        
        # Otherwise process via apify and gpt 
        result = asyncio.run(processor.process_url(url))

        if not result.get("success"):
            error = result.get("error", "Unknown error")
            logger.error(f"Processing failed: {error}")
            send_error_notification(user_id, error_type="generic", tiktok_url=url)
            return

        locations = result.get("locations", [])

        if not locations:
            logger.warning("No locations found in video")
            send_error_notification(user_id, error_type="no_location", tiktok_url=url)
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
                    loc_data=loc_data,
                    video_data=loc_data.get('video_data'),
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
            send_error_notification(user_id, error_type="already_saved", tiktok_url=url)
            return

        if not saved_locations and already_saved_count == 0:
            logger.error("Failed to save any locations")
            send_error_notification(user_id, error_type="generic", tiktok_url=url)
            return

        logger.info(f"Successfully saved {len(saved_locations)} locations for user {user_id}")
        send_success_notification(user_id, saved_locations)

    except Exception as e:
        logger.error(f"Error in background processing: {e}", exc_info=True)
        send_error_notification(user_id, error_type="generic", tiktok_url=url)


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
