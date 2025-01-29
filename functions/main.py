from firebase_functions import https_fn
from firebase_admin import initialize_app
from firebase_functions.params import SecretParam
from flask import jsonify
from location_finder import LocationFinder
import json
import os
from dotenv import load_dotenv


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