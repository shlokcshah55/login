"""
Flask API for Tag Generation Service
Exposes endpoints for both Supabase and Google Places API tag generation
"""
import os
import logging
from flask import Flask, request, jsonify
from main import TagMatcher

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize Flask app
app = Flask(__name__)

# Validate environment variables at startup
REQUIRED_ENV_VARS = ['SUPABASE_URL', 'SUPABASE_KEY', 'OPENAI_API_KEY']
missing_vars = [var for var in REQUIRED_ENV_VARS if not os.getenv(var)]
if missing_vars:
    logger.error(f"Missing required environment variables: {', '.join(missing_vars)}")
    raise ValueError(f"Missing required environment variables: {', '.join(missing_vars)}")

logger.info("Tag Generation API initialized successfully")


@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint for Cloud Run"""
    return jsonify({
        "status": "healthy",
        "service": "tag-generation"
    }), 200


@app.route('/generate-tags/supabase', methods=['POST'])
def generate_tags_supabase():
    """
    Generate and save tags for locations already in Supabase

    Request body:
    {
        "location_ids": [123, 456, 789]
    }

    Response:
    {
        "success": true,
        "results": [
            {
                "success": true,
                "location_id": 123,
                "matched_tags": 5,
                "tag_ids": ["uuid1", "uuid2", ...],
                "elapsed_seconds": 1.23
            },
            ...
        ]
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
        location_ids = data.get('location_ids')

        if not location_ids:
            return jsonify({
                "success": False,
                "error": "Missing required field: location_ids"
            }), 400

        if not isinstance(location_ids, list):
            return jsonify({
                "success": False,
                "error": "location_ids must be an array"
            }), 400

        if not all(isinstance(id, int) for id in location_ids):
            return jsonify({
                "success": False,
                "error": "All location_ids must be integers"
            }), 400

        logger.info(f"Processing tag generation for {len(location_ids)} locations")

        # Initialize TagMatcher and process
        matcher = TagMatcher(location_ids)
        results = matcher.run_for_supabase()

        # Check if all succeeded
        all_succeeded = all(r.get('success', False) for r in results)

        return jsonify({
            "success": all_succeeded,
            "results": results
        }), 200 if all_succeeded else 207  # 207 = Multi-Status

    except Exception as e:
        logger.error(f"Unexpected error in /generate-tags/supabase: {e}", exc_info=True)
        return jsonify({
            "success": False,
            "error": f"Internal server error: {str(e)}"
        }), 500


@app.route('/generate-tags/places', methods=['POST'])
def generate_tags_places():
    """
    Generate tags for a location from Google Places API (before DB insertion)

    Request body:
    {
        "location": {
            "name": "Restaurant Name",
            "vicinity": "123 Main St, City",
            "cuisine": "Italian",
            "rating": 4.5,
            "price_level": 2,
            ...
        }
    }

    Response:
    {
        "success": true,
        "tag_ids": ["uuid1", "uuid2", "uuid3", "uuid4", "uuid5"],
        "elapsed_seconds": 1.45
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
        location = data.get('location')

        if not location:
            return jsonify({
                "success": False,
                "error": "Missing required field: location"
            }), 400

        if not isinstance(location, dict):
            return jsonify({
                "success": False,
                "error": "location must be an object"
            }), 400

        # Validate location has at least a name
        if not location.get('name'):
            return jsonify({
                "success": False,
                "error": "location must have a 'name' field"
            }), 400

        logger.info(f"Generating tags for location: {location.get('name')}")

        # Initialize TagMatcher and process
        matcher = TagMatcher([])  # Empty list since we're not loading from DB
        result = matcher.run_for_placesAPI(location)

        if result.get('success'):
            return jsonify(result), 200
        else:
            return jsonify(result), 422  # Unprocessable Entity

    except Exception as e:
        logger.error(f"Unexpected error in /generate-tags/places: {e}", exc_info=True)
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
