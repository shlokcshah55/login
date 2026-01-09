"""
Flask API for TikTok processing service
Exposes endpoints for Cloud Run deployment
"""
import os
import logging
import asyncio
import threading
import httpx
from flask import Flask, request, jsonify
from processor import TikTokProcessor
from supabase import create_client, Client


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

# Validate environment variables
if not OPENAI_API_KEY or not GOOGLE_PLACES_API_KEY:
    logger.error("Missing required environment variables: OPENAI_API_KEY or GOOGLE_PLACES_API_KEY")
    raise ValueError("Missing required API keys in environment variables")

if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
    logger.warning("Missing Supabase credentials - /process-share endpoint will not work")

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

def save_location_to_supabase(user_id: str, place_data: dict, video_data: dict, url: str):
    """Save location to Supabase database"""
    try:
        if not supabase_client:
            logger.error("Supabase client not initialized")
            return None

        place_id = place_data['place_id']
        name = place_data['name']
        address = place_data['address']
        location = place_data['location']
        types = place_data.get('types', [])
        rating = place_data.get('rating')

        # 1. Check if location exists
        response = supabase_client.table('locations').select('location_id').eq('google_place_id', place_id).maybe_single().execute()

        if response and hasattr(response, 'data') and response.data:
            location_id = response.data['location_id']
            logger.info(f"Location already exists: {location_id}")
        else:
            # Create location
            try:
                api_url = "https://pinit-recommendations-api-630839392908.europe-west2.run.app/locations/add"
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

        # 3. Save location with tag updates using new RPC
        logger.info(type(location_id))
        result = supabase_client.rpc('save_location_with_tags', {
            'p_user_id': user_id,
            'p_location_id': location_id,
            'p_saved_method': 'tiktok',  
            'p_acked': True
        }).execute()

        response = result.data

        if response and response.get('success'):
            tag_count = response.get('tag_count', 0)
            logger.info(f"Saved location {location_id} with {tag_count} tag updates (TikTok method)")
            return {
                'location_id': location_id,
                'name': name
            }
        else:
            error = response.get('error', 'Unknown error') if response else 'No response'
            logger.error(f"Failed to save location via RPC: {error}")
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
        logger.info(f"Background processing started for user {user_id}, URL: {url}")

        result = asyncio.run(processor.process_url(url))

        if not result.get("success"):
            error = result.get("error", "Unknown error")
            logger.error(f"Processing failed: {error}")
            return

        locations = result.get("locations", [])

        if not locations:
            logger.warning("No locations found in video")
            return

        # Save all locations to database
        saved_locations = []
        for loc_data in locations:
            logger.info(loc_data)
            try:
                location = save_location_to_supabase(
                    user_id=user_id,
                    place_data=loc_data['place'],
                    video_data=loc_data['video_data'],
                    url=url
                )
                if location:
                    saved_locations.append(location)
            except Exception as e:
                logger.error(f"Error saving location: {e}", exc_info=True)
                continue

        if not saved_locations:
            logger.error("Failed to save any locations")
            return

        logger.info(f"Successfully saved {len(saved_locations)} locations for user {user_id}")

    except Exception as e:
        logger.error(f"Error in background processing: {e}", exc_info=True)


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


@app.route('/process', methods=['POST'])
def process_tiktok():
    """
    Process a TikTok URL and extract location information

    Request body:
    {
        "url": "https://www.tiktok.com/@user/video/123456789",
    }

    Response:
    {
        "success": true,
        "place": {
            "place_id": "ChIJ...",
            "name": "Place Name",
            "address": "123 Main St, City, Country",
            "location": {"lat": 40.7128, "lng": -74.0060},
            "types": ["restaurant", "food"],
            "rating": 4.5
        },
        "video_data": {
            "id": "123456789",
            "description": "Video description",
            "author": "username"
        },
        "extracted_query": "Place Name City"
    }
    """
    try:
        # Parse request body
        data = request.get_json()

        if not data:
            return jsonify({
                "success": False,
                "error": "Request body must be JSON"
            }), 400

        # Validate required fields
        url = data.get('url')

        if not url:
            return jsonify({
                "success": False,
                "error": "Missing required field: url"
            }), 400


        logger.info(f"Processing request for URL: {url}")

        # Process the TikTok URL (run async function in sync context)
        result = asyncio.run(processor.process_url(url))

        # Return result
        if result.get("success"):
            logger.info(f"Successfully processed URL: {url}")
            return jsonify(result), 200
        else:
            logger.warning(f"Failed to process URL: {url}, Error: {result.get('error')}")
            return jsonify(result), 422  # Unprocessable Entity

    except Exception as e:
        logger.error(f"Unexpected error in /process endpoint: {e}", exc_info=True)
        return jsonify({
            "success": False,
            "error": f"Internal server error: {str(e)}"
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
