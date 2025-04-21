"""
TikTok Processing API for Cloud Run
This service processes TikTok links and publishes them to a Pub/Sub topic.
"""
import os
import json
import logging
import uuid
from flask import Flask, request, jsonify
from flask_cors import CORS
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from dotenv import load_dotenv
from google.cloud import pubsub_v1

# Load environment variables
load_dotenv()

# Initialize Flask app
app = Flask(__name__)

# Enable CORS for all routes
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
    logging.basicConfig(level=logging.INFO,
                        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')

# Pub/Sub configuration
PROJECT_ID = "pinit-10b36"
TOPIC_ID = "process-tiktok"
publisher = pubsub_v1.PublisherClient()
topic_path = publisher.topic_path(PROJECT_ID, TOPIC_ID)

@app.errorhandler(429)
def handle_rate_limit_error(error):
    """Handle rate limit exceeded errors"""
    return jsonify({
        "error": "Rate limit exceeded",
        "message": str(error.description)
    }), 429

@app.errorhandler(500)
def handle_server_error(error):
    """Handle internal server errors"""
    error_id = str(uuid.uuid4())
    logging.exception(f"Internal server error (ID: {error_id}): {error}")
    return jsonify({
        "error": "Internal server error",
        "error_id": error_id,
        "message": "An unexpected error occurred. Please try again later."
    }), 500

@app.route(f"/v1/publish", methods=["POST"])
@limiter.limit("20 per minute")
def process_tiktok_link():
    """
    Process a single TikTok link and publish it to a Pub/Sub topic.

    Request JSON format:
    {
        "url": "https://www.tiktok.com/...",
        "userId": "user123"
    }
    """
    try:
        # Validate request body
        data = request.json
        if not data or not data.get("url") or not data.get("userId"):
            return jsonify({"error": "Missing required fields: url and userId"}), 400

        tiktok_url = data.get("url")
        user_id = data.get("userId")

        # Create the message payload
        message_payload = {
            "url": tiktok_url,
            "userId": user_id
        }

        # Publish the message to Pub/Sub
        future = publisher.publish(topic_path, json.dumps(message_payload).encode("utf-8"))
        message_id = future.result()

        logging.info(f"Published message to Pub/Sub with ID: {message_id}")
        return jsonify({"message_id": message_id}), 200

    except Exception as e:
        error_id = str(uuid.uuid4())
        logging.exception(f"Error processing TikTok link (ID: {error_id}): {e}")
        return jsonify({
            "error": "Failed to process TikTok link",
            "error_id": error_id,
            "message": "An unexpected error occurred while processing the TikTok link"
        }), 500

    @app.route("/", defaults={"path": ""})
    @app.route("/<path:path>")
    def catch_all(path):
        return jsonify({"message": "You hit an undefined path", "path": path}), 404

if __name__ == "__main__":
    # For local development, use Flask's built-in server
    port = int(os.environ.get("PORT", 8080))
    debug = os.environ.get("DEBUG", "False").lower() == "true"
    app.run(host="0.0.0.0", port=port, debug=debug)