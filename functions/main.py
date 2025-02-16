from firebase_functions import https_fn, firestore_fn
from firebase_admin import initialize_app, firestore, auth
from flask import jsonify
from location_finder import LocationFinder
from gpt_utils import start_gpt_session, find_locations
from tiktok_retrieval import get_video_info
import json
import os
import asyncio

# Third-party dependencies
from TikTokApi import TikTokApi
from cleantext import clean
from dotenv import load_dotenv

initialize_app()
load_dotenv()

@https_fn.on_request(region="europe-west2", secrets=["GEMINI_API_KEY", "GOOGLE_PLACE_API_KEY"])
def search_places_endpoint(req: https_fn.Request) -> https_fn.Response:
    """
    HTTP Cloud Function to handle search requests.
    """
    GEMINI_API_KEY = os.environ.get('GEMINI_API_KEY')
    GOOGLE_PLACE_API_KEY = os.environ.get('GOOGLE_PLACE_API_KEY')  
    
    # Check if secrets are loaded
    if not GEMINI_API_KEY or not GOOGLE_PLACE_API_KEY:
        raise RuntimeError("Missing required environment variables: GEMINI_API_KEY, GOOGLE_PLACE_API_KEY")

    # Initialize LocationFinder
    finder = LocationFinder(GEMINI_API_KEY, GOOGLE_PLACE_API_KEY)
    # Extract the query parameter
    query = req.args.get('query')
    if not query:
        return https_fn.Response(
            json.dumps({"error": "Query parameter is required"}),
            status=400,
            headers={"Content-Type": "application/json"},
        )
    
    try:
        results = finder.search_places(query)
        return https_fn.Response(
            json.dumps(results),
            headers={"Content-Type": "application/json"},
        )
    except Exception as e:
        # Handle errors gracefully
        return https_fn.Response(
            json.dumps({"error": str(e)}),
            status=500,
            headers={"Content-Type": "application/json"},
        )
    
# endpoint url: https://europe-west2-pinit-10b36.cloudfunctions.net/search_places_endpoint

@https_fn.on_request(region="europe-west2", secrets=["GEMINI_API_KEY"])
def tiktok_video_info_endpoint(req: https_fn.Request) -> https_fn.Response:
    """
    HTTP Cloud Function that accepts a TikTok URL (via query parameter 'url'),
    retrieves video information using the TikTokApi, and stores it in Firestore.
    
    Example request: GET ?url=<tiktok_video_url>
    """
    # Extract the TikTok URL from the query parameters
    tiktok_url = req.args.get('url')
    if not tiktok_url:
        return https_fn.Response(
            json.dumps({"error": "Query parameter 'url' is required"}),
            status=400,
            headers={"Content-Type": "application/json"},
        )
    
    try:
        # Retrieve the video info asynchronously
        video_info_json = asyncio.run(get_video_info(tiktok_url))
        video_info = json.loads(video_info_json)


        # Extract location from video info using the GPT model
        gemini_api_key = os.environ.get('GEMINI_API_KEY')
        session = start_gpt_session(gemini_api_key)
        locations = find_locations(session, video_info)

        # Get a Firestore client
        db = firestore.client()
        posts_collection = db.collection('Posts')

        # Use the TikTok video ID as document ID if available.
        doc_id = video_info.get("id")
        if doc_id:
            doc_ref = posts_collection.document(str(doc_id))
        else:
            doc_ref = posts_collection.document()  # Auto-generated ID

        # 4. Check if the document exists.
        doc_snapshot = doc_ref.get()

        if doc_snapshot.exists:
            # Document exists: increment the save_count atomically.
            doc_ref.update({ "save_count": firestore.Increment(1) })
            # Retrieve updated document for the latest fields.
            updated_snapshot = doc_ref.get()
            existing_data = updated_snapshot.to_dict()
            location_reference = existing_data.get("locations")
            current_save_count = existing_data.get("save_count")
        else:
            # Document does not exist: create a new document.
            new_data = {
                "id": doc_id,
                "url": tiktok_url,
                "locations": locations,
                "save_count": 1
            }

            doc_ref.set(new_data)
            location_reference = new_data.get("locations")
            current_save_count = new_data.get("save_count")

        # Respond with success, including the stored video info and Firestore doc ID
        return https_fn.Response(
            json.dumps({
                "message": "Video info retrieved and stored successfully.",
                "video_info": video_info,
                "firestore_doc_id": doc_ref.id,
                "locations": locations
            }),
            headers={"Content-Type": "application/json"},
        )
    except Exception as e:
        # Handle any errors that occur
        return https_fn.Response(
            json.dumps({"error": str(e)}),
            status=500,
            headers={"Content-Type": "application/json"},
        )


@firestore_fn.on_document_created(document="incoming_tiktok_links/{doc_id}", region="europe-west2", secrets=["GEMINI_API_KEY"])
def process_tiktok_link(event: firestore_fn.Event[dict]) -> None:
    """
    Triggered when a new document is created in 'incoming_tiktok_links'.
    This function processes the TikTok URL, retrieves video info, extracts locations,
    and then updates/inserts the document in the 'Posts' collection accordingly.
    """

    # Retrieve the TikTok URL from the Firestore document.
    data = event.data
    tiktok_url = data.get('url')
    if not tiktok_url:
        print("No TikTok URL found in document.")
        return

    try:
        # Retrieve TikTok video info.
        video_info_json = asyncio.run(get_video_info(tiktok_url))
        video_info = json.loads(video_info_json)

        # Use Gemini to extract locations.
        gemini_api_key = os.environ.get('GEMINI_API_KEY')
        session = start_gpt_session(gemini_api_key)
        locations = find_locations(session, video_info)

        # Get a Firestore client and the target collection.
        db = firestore.client()
        posts_collection = db.collection('Posts')

        # Use the TikTok video ID (if available) as the document ID.
        doc_id = video_info.get("id")
        if doc_id:
            doc_ref = posts_collection.document(str(doc_id))
        else:
            doc_ref = posts_collection.document()  # Auto-generated ID

        # 4. Check if the document already exists.
        doc_snapshot = doc_ref.get()

        if doc_snapshot.exists:
            # Document exists: increment the save_count atomically.
            doc_ref.update({
                "save_count": firestore.Increment(1)
            })
            print(f"Existing document {doc_ref.id} updated with incremented save_count.")
        else:
            # Document does not exist: create a new one.
            new_data = {
                "id": doc_id,
                "url": tiktok_url,
                "locations": locations,
                "save_count": 1
            }
            doc_ref.set(new_data)
            print(f"New document {doc_ref.id} created.")

    except Exception as e:
        print(f"Error processing TikTok link: {e}")