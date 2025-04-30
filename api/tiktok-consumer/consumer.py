"""
TikTok Processing Consumer API for Cloud Run
This service consumes Pub/Sub messages and forwards them to another API endpoint.
"""
import base64
import json
import logging
import os
import requests
import uuid
from flask import Flask, request, jsonify
from dotenv import load_dotenv

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
    logging.basicConfig(level=logging.INFO,
                        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')

# Target API endpoint configuration
target_api = "https://process-tiktok-link-711637650309.europe-west1.run.app/v1/process-tiktok"

@app.route("/", methods=["POST"])
def consume_pubsub_message():
    """
    Consume a Pub/Sub message and forward it to the target API.

    The Pub/Sub message will contain the TikTok URL and user ID.
    """
    try:
        envelope = request.get_json()

        if not envelope:
            logging.error("No Pub/Sub message received")
            return jsonify({"error": "No Pub/Sub message received"}), 400

        if not isinstance(envelope, dict) or "message" not in envelope:
            logging.error("Invalid Pub/Sub message format")
            return jsonify({"error": "Invalid Pub/Sub message format"}), 400

        # Extract the message data
        pubsub_message = envelope["message"]

        if not pubsub_message.get("data"):
            logging.error("Empty Pub/Sub message data")
            return jsonify({"error": "Empty Pub/Sub message data"}), 400

        # Decode the Pub/Sub message data
        try:
            message_data = base64.b64decode(pubsub_message["data"]).decode("utf-8")
            data = json.loads(message_data)
        except Exception as e:
            logging.exception(f"Error decoding message data: {e}")
            return jsonify({"error": "Error decoding message data"}), 400

        # Verify required fields
        if not data.get("url") or not data.get("userId"):
            logging.error("Missing required fields in message data")
            return jsonify({"error": "Missing required fields in message data"}), 400

        # Prepare the payload for the target API
        payload = {
            "url": data["url"],
            "userId": data["userId"],
        }
        logging.info(f"Forwarding message to target API: {payload}")

        # Include optional documentId if present
        if "documentId" in data:
            payload["documentId"] = data["documentId"]

        # Forward the data to the target API
        try:
            response = requests.post(
                target_api,
                json=payload,
                timeout=30  # 30-second timeout
            )
            logging.info(f"Response from target API: {response.status_code} - {response.text}")
            # Check if the request was successful
            response.raise_for_status()

            # Log the successful response
            logging.info(f"Successfully forwarded message to target API. Response: {response.status_code}")
            return jsonify({"status": "success", "target_response_code": response.status_code}), 200

        except requests.exceptions.RequestException as e:
            error_id = str(uuid.uuid4())
            logging.exception(f"Error forwarding to target API (ID: {error_id}): {e}")
            return jsonify({
                "error": "Failed to forward message to target API",
                "error_id": error_id,
                "message": str(e)
            }), 500

    except Exception as e:
        error_id = str(uuid.uuid4())
        logging.exception(f"Unexpected error (ID: {error_id}): {e}")
        return jsonify({
            "error": "Unexpected error",
            "error_id": error_id,
            "message": str(e)
        }), 500


if __name__ == "__main__":
    # For local development, use Flask's built-in server
    port = int(os.environ.get("PORT", 8081))
    debug = os.environ.get("DEBUG", "False").lower() == "true"
    app.run(host="0.0.0.0", port=port, debug=debug)