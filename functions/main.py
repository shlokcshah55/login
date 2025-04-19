from firebase_functions import https_fn, firestore_fn
from firebase_admin import initialize_app, firestore, auth
from flask import jsonify
from functions.location_finder import LocationFinder
from api.gpt_utils import start_gpt_session, find_locations
from api.tiktok_retrieval import get_cleaned_video_info # Updated import
import json
import os
import asyncio
import logging # Add logging import

# DOCKER TEST: This comment will force a container redeployment  
# Third-party dependencies (Keep relevant ones if still needed elsewhere)
# from TikTokApi import TikTokApi # Likely no longer needed directly here
# from cleantext import clean # Likely no longer needed directly here
from dotenv import load_dotenv

initialize_app()
load_dotenv()

# Setup basic logging for Cloud Functions (adjust format as needed)
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

@https_fn.on_request(region="europe-west2", secrets=["GEMINI_API_KEY", "GOOGLE_PLACE_API_KEY"])
def search_places_endpoint(req: https_fn.Request) -> https_fn.Response:
    """
    HTTP Cloud Function to handle search requests.
    """
    # Use logging instead of print for serverless functions
    logging.info("search_places_endpoint triggered.")
    GEMINI_API_KEY = os.environ.get('GEMINI_API_KEY')
    GOOGLE_PLACE_API_KEY = os.environ.get('GOOGLE_PLACE_API_KEY')

    # Check if secrets are loaded
    if not GEMINI_API_KEY or not GOOGLE_PLACE_API_KEY:
        logging.error("Missing required environment variables: GEMINI_API_KEY or GOOGLE_PLACE_API_KEY")
        # Return a generic error to the client
        return https_fn.Response(
            json.dumps({"error": "Server configuration error."}),
            status=500,
            headers={"Content-Type": "application/json"},
        )

    # Initialize LocationFinder
    finder = LocationFinder(GEMINI_API_KEY, GOOGLE_PLACE_API_KEY)
    # Extract the query parameter
    query = req.args.get('query')
    if not query:
        logging.warning("Query parameter is missing.")
        return https_fn.Response(
            json.dumps({"error": "Query parameter is required"}),
            status=400,
            headers={"Content-Type": "application/json"},
        )

    logging.info(f"Processing search query: {query}")
    try:
        results = finder.search_places(query)
        logging.info(f"Search successful for query: {query}")
        return https_fn.Response(
            json.dumps(results),
            headers={"Content-Type": "application/json"},
        )
    except Exception as e:
        logging.error(f"Error during search_places for query '{query}': {e}", exc_info=True)
        # Handle errors gracefully
        return https_fn.Response(
            json.dumps({"error": "An error occurred during search."}), # Generic error
            status=500,
            headers={"Content-Type": "application/json"},
        )

# endpoint url: https://europe-west2-pinit-10b36.cloudfunctions.net/search_places_endpoint

@firestore_fn.on_document_created(document="incoming_tiktok_links/{doc_id}", region="europe-west2", secrets=["GEMINI_API_KEY"])
def process_tiktok_link(event: firestore_fn.Event) -> None:
    """
    Triggered when a new document is created in 'incoming_tiktok_links'.
    Processes the TikTok URL, retrieves video info, extracts locations,
    and then updates/inserts the document in the 'Posts' collection accordingly.
    """
    # For 'on_document_created', event.data is directly the DocumentSnapshot
    # not a Change object with before/after
    data = event.data.to_dict() if event.data else None
    if not data:
        logging.error("Error: No data found in Firestore event.")
        return

    tiktok_url = data.get('url')
    if not tiktok_url:
        logging.error("No TikTok URL found in document.")
        return
    
    logging.info(f"Processing Firestore event for TikTok URL: {tiktok_url}")
    
    # Instead of using asyncio.run() directly, create a new event loop
    # This approach is more compatible with Firebase Functions environment
    try:
        # Create and set a new event loop
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        
        # Run the processing function in the new loop
        # Pass event.data.reference instead of event.data.after.reference
        result = loop.run_until_complete(_process_tiktok_link_async(tiktok_url, event.data.reference))
        
        # Close the loop when done
        loop.close()
        
        logging.info(f"Successfully processed Firestore event for {tiktok_url}")
    except Exception as e:
        logging.error(f"Error processing TikTok link via Firestore trigger for URL {tiktok_url}: {e}", exc_info=True)
        # Update the original document with error status
        try:
            # Use event.data.reference instead of event.data.after.reference
            event.data.reference.update({
                "status": "error", 
                "error_message": str(e),
                "processed_at": firestore.SERVER_TIMESTAMP
            })
        except Exception as update_err:
            logging.error(f"Failed to update error status: {update_err}")


@firestore.transactional
def update_post_in_transaction_firestore(transaction, doc_ref, video_info, tiktok_url, locations):
    """
    Helper function to update or create a post document in a Firestore transaction.
    Extracted to keep the async function cleaner.
    """
    snapshot = doc_ref.get(transaction=transaction)
    if snapshot.exists:
        logging.info(f"Document {doc_ref.id} exists. Incrementing save_count.")
        # Document exists: increment the save_count atomically
        transaction.update(doc_ref, {
            "save_count": firestore.Increment(1),
            "last_processed_timestamp": firestore.SERVER_TIMESTAMP
        })
    else:
        logging.info(f"Document {doc_ref.id} does not exist. Creating new document.")
        # Document does not exist: create a new one
        new_data = {
            "id": video_info.get("id"),
            "url": tiktok_url,
            "locations": locations,
            "save_count": 1,
            "first_processed_timestamp": firestore.SERVER_TIMESTAMP
        }
        transaction.set(doc_ref, new_data)


