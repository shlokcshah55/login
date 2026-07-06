"""
Push notification helpers for the social-free-processor.

Every processed share produces one notification pointing at the post's
review screen in the app (type: social_post_review). Copy varies by outcome:
  places auto-saved      → "Saved! We saved N places — tap to review"
  found but unconfident   → "Not sure — take a look"
  nothing found          → "We saved the post — add the place yourself"
  failed                 → "We couldn't read that post — add the place yourself"
"""
import logging

import httpx
from supabase import Client

logger = logging.getLogger(__name__)


def _fetch_fcm_token(supabase: Client, user_id: str) -> str | None:
    try:
        response = (
            supabase.table("users")
            .select("fcm_token")
            .eq("supabase_id", user_id)
            .maybe_single()
            .execute()
        )
        if response and response.data:
            return response.data.get("fcm_token")
    except Exception as exc:
        logger.warning("Failed to fetch FCM token for user %s: %s", user_id, exc)
    return None


def _send(
    *,
    push_url: str,
    secret: str,
    fcm_token: str,
    user_id: str,
    notif_type: str,
    title: str,
    body: str,
    metadata: dict,
):
    if not secret:
        logger.info("SEND_PUSH_NOTIF_SECRET not configured — skipping %s notification", notif_type)
        return
    try:
        with httpx.Client(timeout=10.0) as client:
            resp = client.post(
                push_url,
                headers={
                    "Authorization": f"Bearer {secret}",
                    "Content-Type": "application/json",
                },
                json={
                    "fcm_token": fcm_token,
                    "user_id": user_id,
                    "type": notif_type,
                    "title": title,
                    "body": body,
                    "metadata": metadata,
                },
            )
            resp.raise_for_status()
    except Exception as exc:
        logger.error("Push notification failed (%s): %s", notif_type, exc)


def notify_review_ready(
    supabase: Client,
    *,
    push_url: str,
    secret: str,
    user_id: str,
    social_post_id: str,
    platform: str,
    place_count: int,
    saved_count: int = 0,
    first_place_name: str | None = None,
    failed: bool = False,
):
    fcm_token = _fetch_fcm_token(supabase, user_id)
    if not fcm_token:
        return

    post_word = "Reel" if platform == "instagram" else "TikTok"
    if failed:
        title = "We couldn't read that post"
        body = f"Your {post_word} is saved — add the place yourself when you know it."
    elif place_count == 0:
        title = "Post saved"
        body = f"We couldn't spot a place in that {post_word} — add it yourself when you know it."
    elif saved_count == 0:
        title = "Take a look"
        body = f"Found {place_count} place{'s' if place_count != 1 else ''} in your {post_word}, but we're not sure which — tap to confirm."
    elif saved_count == 1:
        title = "Saved!"
        body = f"We saved {first_place_name or 'a place'} from your {post_word} — tap to review."
    else:
        title = "Saved!"
        body = f"We saved {saved_count} places from your {post_word} — tap to review."

    _send(
        push_url=push_url, secret=secret,
        fcm_token=fcm_token, user_id=user_id,
        notif_type="social_post_review",
        title=title,
        body=body,
        metadata={
            "socialPostId": social_post_id,
            "platform": platform,
            "placeCount": place_count,
            "savedCount": saved_count,
            "failed": failed,
        },
    )
