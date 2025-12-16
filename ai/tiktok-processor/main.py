"""
Flask API for TikTok processing service
Exposes a single /process endpoint for Cloud Run deployment
"""
import os
import logging
import asyncio
from flask import Flask, request, jsonify
from processor import TikTokProcessor

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

# Validate environment variables
if not OPENAI_API_KEY or not GOOGLE_PLACES_API_KEY:
    logger.error("Missing required environment variables: OPENAI_API_KEY or GOOGLE_PLACES_API_KEY")
    raise ValueError("Missing required API keys in environment variables")

# Initialize processor (singleton)
processor = TikTokProcessor(
    openaiKey=OPENAI_API_KEY,
    gmaps_key=GOOGLE_PLACES_API_KEY
)

logger.info("TikTok Processor API initialized successfully")


@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint for Cloud Run"""
    return jsonify({"status": "healthy", "service": "tiktok-processor"}), 200


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
