"""
TikTok Processing API for Cloud Run
This service processes TikTok links from Firestore, extracts data using the TikTok API,
and updates the Firestore database with results.
"""
import os
import json
import asyncio
import logging
from typing import Dict, Any, Optional
import time

from flask import Flask, request, jsonify
from dotenv import load_dotenv
from asgiref.sync import async_to_sync

# Import TikTok processing utilities
from tiktok_retrieval import get_cleaned_video_info
from gpt_utils import start_gpt_session, find_locations

from firestore_db import get_firestore_client
from places_api import get_places_api

# Load environment variables
load_dotenv()

# Initialize Flask app
app = Flask(__name__)

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

@app.route("/health", methods=["GET"])
def health_check():
    """Simple health check endpoint to verify the service is running"""
    # Also check database connection
    db_client = get_firestore_client()
    db_connected = db_client is not None and db_client.is_connected()
    
    return jsonify({
        "status": "ok", 
        "timestamp": time.time(),
        "database_connected": db_connected
    }), 200

@app.route("/process-tiktok", methods=["POST"])
def process_tiktok_link():
    """
    Process a single TikTok link provided directly in the request
    
    Request JSON format:
    {
        "url": "https://www.tiktok.com/...",
        "userId": "user123",  # Optional user ID
        "documentId": "doc123"  # Optional Firestore document ID
    }
    """
    try:
        data = request.json
        if not data or not data.get("url"):
            return jsonify({"error": "Missing required field: url"}), 400
        
        tiktok_url = data.get("url")
        user_id = data.get("userId")
        document_id = data.get("documentId")
        
        logging.info(f"Processing TikTok URL: {tiktok_url} for user: {user_id}")
        
        # Use async_to_sync to call our async function from a sync context
        process_url = async_to_sync(process_tiktok_url)
        result = process_url(tiktok_url, user_id, document_id)
        
        if result.get("error"):
            return jsonify(result), 500
        
        return jsonify(result), 200
        
    except Exception as e:
        logging.exception(f"Error processing TikTok link: {e}")
        return jsonify({"error": f"Server error: {str(e)}"}), 500

@app.route("/process-pending", methods=["POST"])
def process_pending_links():
    """
    Process all pending TikTok links in the incoming_tiktok_links collection
    
    Optional Request JSON format:
    {
        "limit": 10,  # Maximum number of links to process
        "userId": "user123"  # Optional filter by user ID
    }
    """
    try:
        data = request.json or {}
        limit = data.get("limit", 10)  # Default to 10 links
        user_id = data.get("userId")  # Optional user ID filter
        
        # Use async_to_sync to run the async function
        process_batch = async_to_sync(process_pending_batch)
        process_batch(limit, user_id)
        
        return jsonify({
            "status": "success", 
            "message": f"Processing up to {limit} pending TikTok links"
        }), 202  # 202 Accepted to indicate processing has started
        
    except Exception as e:
        logging.exception(f"Error initiating batch processing: {e}")
        return jsonify({"error": f"Server error: {str(e)}"}), 500

# --- Async Processing Functions ---

async def process_pending_batch(limit: int, user_id: Optional[str] = None):
    """Process a batch of pending TikTok links"""
    try:
        # Get the database client
        db_client = get_firestore_client()
        if not db_client or not db_client.is_connected():
            logging.error("Cannot process pending links: Database connection not available")
            return
        
        # Get pending links from database
        pending_links = db_client.get_pending_tiktok_links(limit, user_id)
        
        if not pending_links:
            logging.info("No pending TikTok links found to process")
            return
            
        # Process each link
        processing_tasks = []
        for link_data in pending_links:
            doc_id = link_data.get("id")
            tiktok_url = link_data.get("tiktokUrl")
            
            if not tiktok_url:
                logging.warning(f"Document {doc_id} has no TikTok URL. Skipping.")
                continue
                
            # Update status to processing
            db_client.update_tiktok_status(doc_id, "processing")
            
            # Add to processing tasks
            link_user_id = link_data.get("userId")
            processing_tasks.append(process_tiktok_url(tiktok_url, link_user_id, doc_id))
        
        # Wait for all tasks to complete
        if processing_tasks:
            results = await asyncio.gather(*processing_tasks, return_exceptions=True)
            logging.info(f"Processed {len(results)} TikTok links")
            
    except Exception as e:
        logging.exception(f"Error in batch processing: {e}")

async def process_tiktok_url(url: str, user_id: Optional[str] = None, doc_id: Optional[str] = None) -> Dict[str, Any]:
    """
    Process a single TikTok URL and update Firestore
    
    Args:
        url: The TikTok URL to process
        user_id: Optional user ID associated with the request
        doc_id: Optional Firestore document ID to update
        
    Returns:
        Dict with results or error information
    """
    try:
        # Get database client if document ID was provided
        db_client = None
        if doc_id:
            db_client = get_firestore_client()
            if not db_client or not db_client.is_connected():
                logging.warning("Database connection not available, continuing without database updates")
        
        # Get TikTok data
        logging.info(f"Getting video info for {url}")
        video_info = await get_cleaned_video_info(url)
        
        if not video_info:
            error_msg = "Failed to retrieve TikTok video data"
            logging.error(f"{error_msg} for URL: {url}")
            
            # Update document status if we have db connection
            if db_client and doc_id:
                db_client.update_tiktok_status(doc_id, "failed", error_msg)
                
            return {"error": error_msg, "url": url}
        
        # Extract locations with Gemini if API key is available
        locations = []
        place_ids = []
        if GEMINI_API_KEY:
            try:
                logging.info(f"Extracting locations for {url}")
                session = start_gpt_session(GEMINI_API_KEY)
                locations = find_locations(session, video_info)
                logging.info(f"Found locations: {locations}")
                
                # Process each location with Google Places API
                if locations:
                    for location in locations:
                        # Process location in Google Places API
                        place_id = await process_location(location)
                        if place_id:
                            # Add place_id to the location information
                            location["place_id"] = place_id
                            place_ids.append(place_id)
                
            except Exception as e:
                logging.error(f"Error extracting locations: {e}")
                # Continue processing even if location extraction fails
        
        # For local testing without database, return the video info directly
        if not db_client:
            logging.info("Database client not available, returning video info without storage")
            return {
                "status": "success",
                "message": "TikTok data processed successfully (database storage skipped)",
                "video_info": video_info,
                "locations": locations,
                "place_ids": place_ids
            }
        
        # Store the processed data in database
        result = db_client.store_processed_tiktok(video_info, url, locations, user_id)
        
        # Add place_ids to the post document if available
        post_doc_id = result.get("post_doc_id")
        if post_doc_id and place_ids:
            for place_id in place_ids:
                db_client.link_post_to_location(post_doc_id, place_id)
        
        # Update the original document if we have a document ID
        if db_client and doc_id and not result.get("error"):
            # Prepare additional data for the update
            additional_data = {
                "postDocId": result.get("post_doc_id"),
                "locations": locations,
                "place_ids": place_ids
            }
            
            # Update the document status
            db_client.update_tiktok_status(doc_id, "completed", additional_data=additional_data)
        
        # Add place_ids to the result
        result["place_ids"] = place_ids
        return result
            
    except Exception as e:
        error_msg = f"Error processing TikTok URL {url}: {str(e)}"
        logging.exception(error_msg)
        
        # Update document status if we have the database connection
        if doc_id:
            try:
                db_client = get_firestore_client()
                if db_client and db_client.is_connected():
                    db_client.update_tiktok_status(doc_id, "failed", str(e))
            except Exception as update_error:
                logging.error(f"Failed to update error status: {update_error}")
        
        return {"error": error_msg, "url": url}

async def process_location(location_info: Dict[str, str]) -> Optional[str]:
    """
    Process a location by searching for it in Google Places API and storing in Firestore.
    
    Args:
        location_info: Dictionary with "landmark" and "location" keys
        
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
        db_client = get_firestore_client()
        if not db_client or not db_client.is_connected():
            logging.warning("Database connection not available, not storing location data")
            return place_data.get("place_id")
        
        # Store the location data in Firestore
        location_id = db_client.store_location(place_data)
        
        return place_data.get("place_id")
        
    except Exception as e:
        logging.error(f"Error processing location {query}: {e}")
        return None

if __name__ == "__main__":
    # For local development, use Flask's built-in server
    port = int(os.environ.get("PORT", 8080))
    debug = os.environ.get("DEBUG", "False").lower() == "true"
    app.run(host="0.0.0.0", port=port, debug=debug)