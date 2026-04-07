"""
Flask API for Collections Generator Service
"""
import asyncio
import os
import logging
import requests
from flask import Flask, request, jsonify
from main import CollectionGenerator

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

REQUIRED_ENV_VARS = ['SUPABASE_URL', 'SUPABASE_KEY', 'XAI_API_KEY']
missing_vars = [var for var in REQUIRED_ENV_VARS if not os.getenv(var)]
if missing_vars:
    logger.error(f"Missing required environment variables: {', '.join(missing_vars)}")
    raise ValueError(f"Missing required environment variables: {', '.join(missing_vars)}")

logger.info("Collections Generator API initialized successfully")

SUPABASE_URL = os.getenv('SUPABASE_URL')
SUPABASE_KEY = os.getenv('SUPABASE_KEY')


def _verify_supabase_token(token: str) -> str | None:
    """
    Validate a Supabase access token and return the user_id it belongs to,
    or None if the token is invalid/expired.
    """
    try:
        resp = requests.get(
            f"{SUPABASE_URL}/auth/v1/user",
            headers={
                "Authorization": f"Bearer {token}",
                "apikey": SUPABASE_KEY,
            },
            timeout=5,
        )
        if resp.status_code == 200:
            return resp.json().get("id")
    except Exception as e:
        logger.warning(f"Token verification request failed: {e}")
    return None


@app.route('/health', methods=['GET'])
def health():
    return jsonify({
        "status": "healthy",
        "service": "collections-generator"
    }), 200


@app.route('/generate-collections', methods=['POST'])
def generate_collections():
    """
    Generate AI collections from a user's saved locations.

    Request body:
    {
        "user_id": "uuid-string"
    }

    Response:
    {
        "success": true,
        "collections_created": 3,
        "collections": [
            {"name": "Date Night Spots", "collection_id": "uuid", "location_count": 4},
            ...
        ]
    }
    """
    try:
        auth_header = request.headers.get("Authorization", "")
        if not auth_header.startswith("Bearer "):
            return jsonify({"success": False, "error": "Missing authorization token"}), 401

        token_user_id = _verify_supabase_token(auth_header[len("Bearer "):])
        if not token_user_id:
            return jsonify({"success": False, "error": "Invalid or expired token"}), 401

        data = request.get_json()

        if not data:
            return jsonify({
                "success": False,
                "error": "Request body must be JSON"
            }), 400

        user_id = data.get('user_id')

        if not user_id or not isinstance(user_id, str) or not user_id.strip():
            return jsonify({
                "success": False,
                "error": "Missing or invalid field: user_id"
            }), 400

        user_id = user_id.strip()

        if user_id != token_user_id:
            return jsonify({"success": False, "error": "Forbidden"}), 403

        logger.info(f"Generating collections for user {user_id}")

        generator = CollectionGenerator(user_id)
        result = asyncio.run(generator.run())

        return jsonify(result), 200

    except ValueError as e:
        logger.warning(f"Validation error: {e}")
        return jsonify({
            "success": False,
            "error": str(e)
        }), 422

    except Exception as e:
        logger.error(f"Unexpected error in /generate-collections: {e}", exc_info=True)
        return jsonify({
            "success": False,
            "error": f"Internal server error: {str(e)}"
        }), 500


@app.route('/auto-update-collections', methods=['POST'])
def auto_update_collections():
    """
    Re-generate / refresh AI collections using the auto-update prompt.
    Same auth + request shape as /generate-collections.
    """
    try:
        auth_header = request.headers.get("Authorization", "")
        if not auth_header.startswith("Bearer "):
            return jsonify({"success": False, "error": "Missing authorization token"}), 401

        token_user_id = _verify_supabase_token(auth_header[len("Bearer "):])
        if not token_user_id:
            return jsonify({"success": False, "error": "Invalid or expired token"}), 401

        data = request.get_json()
        if not data:
            return jsonify({"success": False, "error": "Request body must be JSON"}), 400

        user_id = data.get('user_id')
        if not user_id or not isinstance(user_id, str) or not user_id.strip():
            return jsonify({"success": False, "error": "Missing or invalid field: user_id"}), 400

        user_id = user_id.strip()
        if user_id != token_user_id:
            return jsonify({"success": False, "error": "Forbidden"}), 403

        logger.info(f"Auto-updating collections for user {user_id}")

        generator = CollectionGenerator(user_id)
        result = generator.run_auto_update()

        return jsonify(result), 200

    except ValueError as e:
        logger.warning(f"Validation error in /auto-update-collections: {e}")
        return jsonify({"success": False, "error": str(e)}), 422

    except Exception as e:
        logger.error(f"Unexpected error in /auto-update-collections: {e}", exc_info=True)
        return jsonify({"success": False, "error": f"Internal server error: {str(e)}"}), 500


@app.errorhandler(404)
def not_found(e):
    return jsonify({"success": False, "error": "Endpoint not found"}), 404


@app.errorhandler(500)
def internal_error(e):
    return jsonify({"success": False, "error": "Internal server error"}), 500


if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port, debug=False)
