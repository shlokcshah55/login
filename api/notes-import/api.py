"""
Flask API for Notes Import service.
Accepts uploaded note files or raw text, extracts locations, resolves them via Google Places,
and saves them to the current user's account.
"""
import logging
import os
import threading
import uuid

import httpx
from flask import Flask, jsonify, request

from main import NotesImportProcessor


logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

REQUIRED_ENV_VARS = [
    "OPENAI_API_KEY",
    "GOOGLE_PLACES_API_KEY",
    "SUPABASE_URL",
    "SUPABASE_SERVICE_KEY",
    "API_SECRET_KEY",
]
missing_vars = [var for var in REQUIRED_ENV_VARS if not os.getenv(var)]
if missing_vars:
    logger.error("Missing required environment variables: %s", ", ".join(missing_vars))
    raise ValueError(f"Missing required environment variables: {', '.join(missing_vars)}")

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
GOOGLE_PLACES_API_KEY = os.getenv("GOOGLE_PLACES_API_KEY")
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_KEY")
API_SECRET_KEY = os.getenv("API_SECRET_KEY")
PUSH_NOTIFICATION_URL = os.getenv(
    "PUSH_NOTIFICATION_URL",
    "https://europe-west1-pinit-494520.cloudfunctions.net/send-push-notifications",
)

processor = NotesImportProcessor(
    openai_api_key=OPENAI_API_KEY,
    gmaps_key=GOOGLE_PLACES_API_KEY,
    supabase_url=SUPABASE_URL,
    supabase_service_key=SUPABASE_SERVICE_KEY,
)


def _verify_supabase_token(token: str) -> str | None:
    """Validate a Supabase access token and return its user ID."""
    try:
        response = httpx.get(
            f"{SUPABASE_URL}/auth/v1/user",
            headers={
                "Authorization": f"Bearer {token}",
                "apikey": SUPABASE_SERVICE_KEY,
            },
            timeout=5.0,
        )
        if response.status_code == 200:
            return response.json().get("id")
    except Exception as exc:
        logger.warning("Token verification request failed: %s", exc)
    return None


def _extract_request_payload() -> tuple[str | None, str | None, bytes | None, str | None, str | None, str | None]:
    """
    Returns:
      (user_id, text, file_bytes, filename, source_name, content_type)
    """
    if request.is_json:
        data = request.get_json(silent=True) or {}
        return (
            data.get("user_id"),
            data.get("text"),
            None,
            None,
            data.get("source_name"),
            None,
        )

    uploaded_file = request.files.get("file")
    if not uploaded_file:
        return (
            request.form.get("user_id"),
            request.form.get("text"),
            None,
            None,
            request.form.get("source_name"),
            None,
        )

    return (
        request.form.get("user_id"),
        request.form.get("text"),
        uploaded_file.read(),
        uploaded_file.filename,
        request.form.get("source_name"),
        uploaded_file.content_type,
    )


def _get_user_fcm_token(user_id: str) -> str | None:
    response = (
        processor.supabase
        .table("users")
        .select("fcm_token")
        .eq("supabase_id", user_id)
        .maybe_single()
        .execute()
    )
    if not response or not getattr(response, "data", None):
        return None
    return response.data.get("fcm_token")


def _send_completion_notification(
    *,
    user_id: str,
    source_name: str,
    processed_count: int,
    saved_count: int,
) -> None:
    fcm_token = _get_user_fcm_token(user_id)
    if not fcm_token:
        logger.warning("User %s has no fcm_token; skipping completion push", user_id)
        return

    title = "Import complete"
    place_label = "place" if processed_count == 1 else "places"
    body = f"We processed {processed_count} {place_label} from your document."

    payload = {
        "fcm_token": fcm_token,
        "user_id": user_id,
        "type": "notes_import_complete",
        "title": title,
        "body": body,
        "metadata": {
            "processedCount": processed_count,
            "savedCount": saved_count,
            "sourceName": source_name,
        },
    }

    with httpx.Client(timeout=10.0) as client:
        response = client.post(
            PUSH_NOTIFICATION_URL,
            headers={
                "Authorization": f"Bearer {API_SECRET_KEY}",
                "Content-Type": "application/json",
            },
            json=payload,
        )
        response.raise_for_status()


def _process_import_async(
    *,
    user_id: str,
    note_text: str,
    source_name: str,
    request_id: str,
) -> None:
    try:
        logger.info("Starting async notes import %s for user %s", request_id, user_id)
        result = processor.process_note(
            user_id=user_id,
            note_text=note_text,
            source_name=source_name,
        )
        processed_count = int(result.get("matched_count") or result.get("extracted_count") or 0)
        saved_count = int(result.get("saved_count") or 0)
        _send_completion_notification(
            user_id=user_id,
            source_name=source_name,
            processed_count=processed_count,
            saved_count=saved_count,
        )
        logger.info(
            "Finished async notes import %s for user %s with %s processed places and %s saved places",
            request_id,
            user_id,
            processed_count,
            saved_count,
        )
    except Exception as exc:
        logger.error(
            "Async notes import %s failed for user %s: %s",
            request_id,
            user_id,
            exc,
            exc_info=True,
        )


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "healthy", "service": "notes-import"}), 200


@app.route("/import-notes", methods=["POST"])
def import_notes():
    """
    Import Apple Notes / Notion content for the authenticated user.

    Supported request formats:
    1. application/json
       {
         "user_id": "uuid-optional-if-token-present",
         "text": "raw note text",
         "source_name": "optional name"
       }

    2. multipart/form-data
       - file: uploaded note file
       - user_id: optional if token is present
       - text: optional raw text alternative to file
       - source_name: optional override
    """
    try:
        auth_header = request.headers.get("Authorization", "")
        if not auth_header.startswith("Bearer "):
            return jsonify({"success": False, "error": "Missing authorization token"}), 401

        token_user_id = _verify_supabase_token(auth_header[len("Bearer "):])
        if not token_user_id:
            return jsonify({"success": False, "error": "Invalid or expired token"}), 401

        user_id, text, file_bytes, filename, source_name, content_type = _extract_request_payload()
        effective_user_id = (user_id or token_user_id or "").strip()
        if not effective_user_id:
            return jsonify({"success": False, "error": "Missing user_id"}), 400

        if effective_user_id != token_user_id:
            return jsonify({"success": False, "error": "Forbidden"}), 403

        if not text and not file_bytes:
            return jsonify({"success": False, "error": "Provide either text or a file upload"}), 400

        note_text, source_name = processor.parse_note_input(
            text=text,
            file_bytes=file_bytes,
            filename=filename,
            source_name=source_name,
            content_type=content_type,
        )

        if not note_text.strip():
            return jsonify({"success": False, "error": "The provided note content was empty"}), 400

        request_id = str(uuid.uuid4())
        threading.Thread(
            target=_process_import_async,
            kwargs={
                "user_id": effective_user_id,
                "note_text": note_text,
                "source_name": source_name,
                "request_id": request_id,
            },
            daemon=True,
        ).start()

        return jsonify({
            "success": True,
            "queued": True,
            "request_id": request_id,
            "source_name": source_name,
            "message": "Import queued. We will notify you when processing is complete.",
        }), 200

    except ValueError as exc:
        logger.warning("Validation error in /import-notes: %s", exc)
        return jsonify({"success": False, "error": str(exc)}), 400
    except Exception as exc:
        logger.error("Unexpected error in /import-notes: %s", exc, exc_info=True)
        return jsonify({"success": False, "error": f"Internal server error: {exc}"}), 500


@app.errorhandler(404)
def not_found(_error):
    return jsonify({"success": False, "error": "Endpoint not found"}), 404


@app.errorhandler(500)
def internal_error(_error):
    return jsonify({"success": False, "error": "Internal server error"}), 500


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    app.run(host="0.0.0.0", port=port, debug=False)
