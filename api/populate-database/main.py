"""
TikTok Processing API for Cloud Run
This service processes TikTok links from Supabase, extracts data using the TikTok API,
and updates the Supabase database with results.
"""
import os
import json
import asyncio
import logging
from typing import Dict, Any, Optional, List
import time
import uuid
from datetime import datetime, timedelta

from flask import Flask, request, jsonify, Response
from flask_cors import CORS
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from dotenv import load_dotenv
from asgiref.sync import async_to_sync

# Import TikTok processing utilities
from tiktok_retrieval import get_cleaned_video_info
import sys
sys.path.append("..")  # Adjust the path to import local modules
from utils.gpt_utils import start_gpt_session, find_locations, filter_restaurant_locations

from supabase_db import get_supabase_client
from places_api import get_places_api
from utils.metrics import track_api_request, track_error
from utils.request_validation import validate_tiktok_url

# Load environment variables
load_dotenv()

# Initialize Flask app
app = Flask(__name__)

# Enable CORS for all routes with proper configuration
CORS(app, resources={r"/*": {"origins": os.environ.get("ALLOWED_ORIGINS", "*").split(","),
                             "methods": ["GET", "POST", "OPTIONS"],
                             "allow_headers": ["Content-Type", "Authorization"]}})

# Configure rate limiting
limiter = Limiter(
    app=app,
    key_func=get_remote_address,
    default_limits=["200 per day", "50 per hour"],
    storage_uri=os.environ.get("REDIS_URL", "memory://"),
    strategy="fixed-window"
)

# Configure logging
if os.environ.get("ENVIRONMENT") == "production":
    from google.cloud import logging as cloud_logging
    client = cloud_logging.Client()
    client.setup_logging(log_level=logging.INFO)
else:
    # Local development logging
    logging.basicConfig(level=logging.INFO, 
                      format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')

# Get secrets from environment
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")
SERVICE_NAME = os.environ.get("SERVICE_NAME", "tiktok-processing-api")
API_VERSION = os.environ.get("API_VERSION", "v1")

@app.errorhandler(429)
def handle_rate_limit_error(error):
    """Handle rate limit exceeded errors"""
    track_error("rate_limit_exceeded", str(error))
    return jsonify({
        "error": "Rate limit exceeded", 
        "message": str(error.description)
    }), 429

@app.errorhandler(500)
def handle_server_error(error):
    """Handle internal server errors"""
    error_id = str(uuid.uuid4())
    track_error("server_error", error_id)
    return jsonify({
        "error": "Internal server error",
        "error_id": error_id,
        "message": "An unexpected error occurred. Please try again later."
    }), 500

# Health endpoint not limited by rate limits
@app.route("/health", methods=["GET"])
@limiter.exempt
def health_check():
    """Simple health check endpoint to verify the service is running"""
    # Also check database connection
    db_client = get_supabase_client()
    db_connected = db_client is not None and db_client.is_connected()
    
    # Check Places API connectivity
    places_api_client = get_places_api()
    places_api_connected = places_api_client is not None
    
    # Get system information
    system_info = {
        "api_version": API_VERSION,
        "service_name": SERVICE_NAME,
        "environment": os.environ.get("ENVIRONMENT", "development"),
        "database_connected": db_connected,
        "places_api_connected": places_api_connected,
        "gemini_api_configured": bool(GEMINI_API_KEY),
        "timestamp": datetime.utcnow().isoformat()
    }
    
    status_code = 200 if db_connected and places_api_connected else 503
    
    return jsonify(system_info), status_code

@app.route(f"/{API_VERSION}/process-tiktok", methods=["POST"])
@limiter.limit("20 per minute")
def process_tiktok_link():
    """
    Process a single TikTok link provided directly in the request
    
    Request JSON format:
    {
        "url": "https://www.tiktok.com/...",
        "userId": "user123",  # Optional user ID
        "documentId": "doc123"  # Optional Supabase document ID
    }
    """
    # Track API request
    track_api_request("process_tiktok")
    
    try:
        # Validate request body
        data = request.json
        if not data or not data.get("url"):
            track_error("missing_field", "url")
            return jsonify({"error": "Missing required field: url"}), 400
        
        tiktok_url = data.get("url")
        user_id = data.get("userId")
        
        # Validate TikTok URL
        if not validate_tiktok_url(tiktok_url):
            track_error("invalid_url", tiktok_url)
            return jsonify({"error": "Invalid TikTok URL format"}), 400
        
        logging.info(f"Processing TikTok URL: {tiktok_url} for user: {user_id}")

        # Use async_to_sync to call our async function from a sync context
        process_url = async_to_sync(process_tiktok_url)
        result = process_url(tiktok_url, user_id)

        return jsonify(result), 200
        
    except Exception as e:
        error_id = str(uuid.uuid4())
        logging.exception(f"Error processing TikTok link (ID: {error_id}): {e}")
        track_error("unhandled_exception", f"{error_id}: {str(e)}")
        return jsonify({
            "error": "Failed to process TikTok link",
            "error_id": error_id,
            "message": "An unexpected error occurred while processing the TikTok link"
        }), 500



# --- Async Processing Functions ---

async def process_tiktok_url(url: str, user_id: Optional[str] = None) -> Dict[str, Any]:
    """
    Process a single TikTok URL and update Supabase

    Args:
        url: The TikTok URL to process
        user_id: Optional user ID associated with the request
        doc_id: Optional Supabase document ID to update

    Returns:
        Dict with results or error information
    """
    try:
        # Get database client if document ID was provided
        db_client = get_supabase_client()
        if not db_client or not db_client.is_connected():
            logging.warning("Database connection not available, continuing without database updates")

        # Get TikTok data
        logging.info(f"Getting video info for {url}")
        video_info = await get_cleaned_video_info(url)


        # Extract locations with Gemini if API key is available
        locations = []
        filtered_locations = []
        place_ids = []
        if GEMINI_API_KEY:
            try:
                logging.info(f"Extracting locations for {url}")
                session = start_gpt_session(GEMINI_API_KEY)

                # First extract all potential locations
                locations = find_locations(session, video_info)
                logging.info(f"Initially found locations: {locations}")

                # Then filter to get only genuine restaurant locations
                if locations:
                    filtered_locations = filter_restaurant_locations(session, locations)
                    logging.info(f"Filtered restaurant locations: {filtered_locations}")

                # Process each filtered location with Google Places API
                if filtered_locations:
                    # Get TikTok video ID from the video_info
                    tiktok_id = video_info.get("id")
                    logging.info(f"Processing filtered locations with TikTok ID: {tiktok_id}")

                    for location in filtered_locations:
                        # Process location in Google Places API
                        place_id = await process_location(location, tiktok_id, user_id, url)
                        if place_id:
                            # Add place_id to the location information
                            location["place_id"] = place_id
                            place_ids.append(place_id)

            except Exception as e:
                logging.error(f"Error extracting or filtering locations: {e}")
                # Continue processing even if location extraction fails

        # For local testing without database, return the video info directly
        if not db_client:
            logging.info("Database client not available, returning video info without storage")
            return {
                "status": "success",
                "message": "TikTok data processed successfully (database storage skipped)",
                "video_info": video_info,
                "all_locations": locations,
                "restaurant_locations": filtered_locations,
                "place_ids": place_ids
            }

        return filtered_locations

    except Exception as e:
        error_msg = f"Error processing TikTok URL {url}: {str(e)}"
        logging.exception(error_msg)

        # Update document status if we have the database connection


        return {"error": error_msg, "url": url}

async def process_location(location_info: Dict[str, str], tiktok_id: Optional[str] = None, user_id: Optional[str] = None, url: Optional[str] = None) -> Optional[str]:
    """
    Process a location by searching for it in Google Places API and storing in Supabase.
    
    Args:
        location_info: Dictionary with "landmark" and "location" keys
        tiktok_id: Optional TikTok video ID to associate with this location
        user_id: Optional user ID to associate with saved posts
        
    Returns:
        The Google Place ID if successful, None otherwise
    """
    if not location_info or "landmark" not in location_info or "location" not in location_info:
        return None
        
    # Create search query from location info
    landmark = location_info.get("landmark", "").strip()
    location = location_info.get("location", "").strip()
    
    if not landmark or landmark.lower() == "not found":
        return None
        
    # Combine landmark and location for search
    query = landmark
    if location and location.lower() != "not found":
        query = f"{landmark}, {location}"
    
    try:
        # Get Places API client
        places_api = get_places_api()
        if not places_api:
            logging.error("Places API client not available")
            return None
        
        # Search for the place
        place_data = places_api.search_place(query)
        if not place_data:
            logging.warning(f"No place data found for query: {query}")
            return None
        
        # Get database client
        db_client = get_supabase_client()
        if not db_client or not db_client.is_connected():
            logging.warning("Database connection not available, not storing location data")
            return place_data.get("place_id")
        print('This is url', url)
        # Store the location data in Supabase with the TikTok ID and user ID
        location_id = db_client.store_location(place_data, tiktok_id, user_id, url)
        print('stored location id', location_id)    

        
        return place_data.get("place_id")
        
    except Exception as e:
        logging.error(f"Error processing location {query}: {e}")
        return None

if __name__ == "__main__":
    print("Available routes:")
    for rule in app.url_map.iter_rules():
        print(f"Route: {rule}, Methods: {rule.methods}")
    # For local development, use Flask's built-in server
    port = int(os.environ.get("PORT", 8080))
    debug = os.environ.get("DEBUG", "False").lower() == "true"
    app.run(host="0.0.0.0", port=port, debug=debug)