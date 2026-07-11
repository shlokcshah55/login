"""
Cloud Tasks enqueue + auth for the social-free-processor.

Why this exists: Cloud Run only guarantees CPU during an HTTP request. The
old pattern (return 202, process in a background daemon thread) loses work —
the instance is CPU-throttled or evicted the moment the response is sent, so
the extraction pipeline never finishes.

Instead, /process-share enqueues a Cloud Task. The queue dispatches it back
to us as a *real* HTTP request to /tasks/process-share, which runs the
pipeline synchronously with full CPU, retries, and backoff.

Local dev: if TASKS_QUEUE is unset there is no queue to talk to, so we fall
back to running the work inline in a daemon thread. That keeps `python
main.py` usable offline; it is NOT how production behaves.
"""
import json
import logging
import os
import threading
from typing import Callable

logger = logging.getLogger(__name__)

# ── Config (all optional; absence disables Cloud Tasks → local fallback) ──────

GCP_PROJECT           = os.environ.get("GCP_PROJECT", "")
TASKS_LOCATION        = os.environ.get("TASKS_LOCATION", "")
TASKS_QUEUE           = os.environ.get("TASKS_QUEUE", "")
TASKS_SERVICE_ACCOUNT = os.environ.get("TASKS_SERVICE_ACCOUNT", "")
WORKER_URL            = os.environ.get("WORKER_URL", "")

# True when every piece needed to enqueue a real Cloud Task is configured.
CLOUD_TASKS_ENABLED = bool(
    GCP_PROJECT and TASKS_LOCATION and TASKS_QUEUE and WORKER_URL and TASKS_SERVICE_ACCOUNT
)


def enqueue_share(url: str, user_id: str, *, local_worker: Callable[[str, str], None]) -> str:
    """
    Schedule processing of one shared URL.

    In production (CLOUD_TASKS_ENABLED) this creates a Cloud Task that calls
    WORKER_URL with an OIDC token. Offline it runs `local_worker(url, user_id)`
    in a daemon thread. Returns a short mode tag for logging ("cloud_task" /
    "local_thread").
    """
    if not CLOUD_TASKS_ENABLED:
        logger.info("Cloud Tasks not configured — processing %s inline (local fallback)", url)
        threading.Thread(target=local_worker, args=(url, user_id), daemon=True).start()
        return "local_thread"

    # Imported lazily so the local/offline path needs no google-cloud-tasks dep.
    from google.cloud import tasks_v2

    client = tasks_v2.CloudTasksClient()
    parent = client.queue_path(GCP_PROJECT, TASKS_LOCATION, TASKS_QUEUE)
    payload = json.dumps({"url": url, "userId": user_id}).encode()

    task = {
        "http_request": {
            "http_method": tasks_v2.HttpMethod.POST,
            "url": WORKER_URL,
            "headers": {"Content-Type": "application/json"},
            "body": payload,
            "oidc_token": {
                "service_account_email": TASKS_SERVICE_ACCOUNT,
                # audience must match what the worker verifies the token against
                "audience": WORKER_URL,
            },
        }
    }

    created = client.create_task(request={"parent": parent, "task": task})
    logger.info("Enqueued Cloud Task %s for %s", created.name, url)
    return "cloud_task"


def verify_oidc_token(auth_header: str | None) -> bool:
    """
    Verify the Google OIDC token Cloud Tasks attaches to a worker request.

    Checks the signature, issuer, and that the audience matches WORKER_URL.
    Returns False on any problem so callers can reject with 403.
    """
    if not auth_header or not auth_header.startswith("Bearer "):
        return False
    token = auth_header.split(" ", 1)[1].strip()

    # Imported lazily so the local fallback path needs no google-auth dep.
    from google.auth.transport import requests as ga_requests
    from google.oauth2 import id_token

    try:
        claims = id_token.verify_oauth2_token(
            token, ga_requests.Request(), audience=WORKER_URL
        )
    except Exception as exc:
        logger.warning("OIDC verification failed: %s", exc)
        return False

    issuer = claims.get("iss")
    if issuer not in ("https://accounts.google.com", "accounts.google.com"):
        logger.warning("OIDC token has unexpected issuer: %s", issuer)
        return False

    # If a service account is configured, ensure the token was minted by it.
    email = claims.get("email")
    if TASKS_SERVICE_ACCOUNT and email != TASKS_SERVICE_ACCOUNT:
        logger.warning("OIDC token from unexpected principal: %s", email)
        return False

    return True
