"""
Supabase DB operations for the social-free-processor.

A shared social URL becomes:
  social_posts              one global row per canonical URL
  social_post_places        global place candidates extracted from the post
  social_post_reviews       per-user review state (the app's review inbox)

Per-place save/discard/correct actions are written by the app directly
(social_post_place_reviews + save_location_with_tags); this service only
creates posts, candidates, and review rows.

Never stores: raw OCR text, raw captions, raw comments, video files,
              screenshot images, or audio.
"""
import logging

import httpx
from supabase import Client

logger = logging.getLogger(__name__)


# ── Social posts ─────────────────────────────────────────────────────────────

def get_post_by_url(supabase: Client, canonical_url: str) -> dict | None:
    """Return the social_posts row for a canonical URL, or None."""
    try:
        result = (
            supabase.table("social_posts")
            .select("*")
            .eq("canonical_url", canonical_url)
            .maybe_single()
            .execute()
        )
        return result.data if result else None
    except Exception as exc:
        logger.warning("Failed to look up social post for %s: %s", canonical_url, exc)
        return None


def create_post(supabase: Client, *, canonical_url: str, platform: str) -> tuple[dict | None, bool]:
    """
    Create the global post record (status=processing). Returns (row, created).
    On a unique-URL conflict the existing row is returned with created=False,
    so two users sharing simultaneously race safely to a single processor.
    """
    try:
        result = supabase.table("social_posts").insert({
            "canonical_url": canonical_url,
            "platform": platform,
        }).execute()
        if result.data:
            return result.data[0], True
    except Exception:
        pass  # unique violation — someone else created it first
    return get_post_by_url(supabase, canonical_url), False


def update_post(supabase: Client, post_id: str, fields: dict):
    """Update post-level metadata / status after processing."""
    try:
        supabase.table("social_posts").update(fields).eq("id", post_id).execute()
    except Exception as exc:
        logger.error("Failed to update social post %s: %s", post_id, exc, exc_info=True)


def mark_post_processing(supabase: Client, post_id: str):
    update_post(supabase, post_id, {"status": "processing", "error": None})


# ── Post places ──────────────────────────────────────────────────────────────

def insert_post_place(
    supabase: Client,
    *,
    post_id: str,
    name: str,
    google_place_id: str | None = None,
    location_id: int | None = None,
    address: str | None = None,
    candidate_name: str | None = None,
    candidate_area: str | None = None,
    confidence_score: float | None = None,
    confidence_tier: str | None = None,
    extracted_context: dict | None = None,
) -> str | None:
    """Insert one global place candidate for a post. Returns the row id."""
    try:
        result = supabase.table("social_post_places").insert({
            "social_post_id": post_id,
            "name": name,
            "google_place_id": google_place_id,
            "location_id": location_id,
            "address": address,
            "candidate_name": candidate_name,
            "candidate_area": candidate_area,
            "confidence_score": confidence_score,
            "confidence_tier": confidence_tier,
            "extracted_context": extracted_context or {},
        }).execute()
        if result.data:
            return result.data[0].get("id")
    except Exception as exc:
        # Duplicate (post, google_place_id) races are expected and harmless.
        logger.warning("Failed to insert post place %r for %s: %s", name, post_id, exc)
    return None


def get_post_places(supabase: Client, post_id: str) -> list[dict]:
    try:
        result = (
            supabase.table("social_post_places")
            .select("id,name,google_place_id,location_id,confidence_tier")
            .eq("social_post_id", post_id)
            .execute()
        )
        return result.data or []
    except Exception as exc:
        logger.warning("Failed to fetch places for post %s: %s", post_id, exc)
        return []


def get_location_summaries(supabase: Client, location_ids: list[int]) -> list[dict]:
    """Name/address lookups for curated-redirect location ids."""
    if not location_ids:
        return []
    try:
        result = (
            supabase.table("locations")
            .select("location_id,name,vicinity,google_place_id")
            .in_("location_id", location_ids)
            .execute()
        )
        return result.data or []
    except Exception as exc:
        logger.warning("Failed to fetch locations %s: %s", location_ids, exc)
        return []


# ── Reviews ──────────────────────────────────────────────────────────────────

def ensure_review(supabase: Client, *, user_id: str, post_id: str, shared_url: str) -> str | None:
    """
    Create (or re-open) this user's review item for a post. Re-sharing an
    already-reviewed post brings it back to the top of the review inbox.
    """
    try:
        result = supabase.table("social_post_reviews").upsert(
            {
                "user_id": user_id,
                "social_post_id": post_id,
                "shared_url": shared_url,
                "status": "pending",
                "snoozed_at": None,
                "reviewed_at": None,
            },
            on_conflict="user_id,social_post_id",
        ).execute()
        if result.data:
            return result.data[0].get("id")
    except Exception as exc:
        logger.error("Failed to ensure review for user %s post %s: %s", user_id, post_id, exc, exc_info=True)
    return None


def get_pending_reviewers(supabase: Client, post_id: str) -> list[dict]:
    """Users whose review of this post is still pending, with their shared_url
    (for auto-save attribution and notifications)."""
    try:
        result = (
            supabase.table("social_post_reviews")
            .select("user_id, shared_url")
            .eq("social_post_id", post_id)
            .eq("status", "pending")
            .execute()
        )
        return [row for row in (result.data or []) if row.get("user_id")]
    except Exception as exc:
        logger.warning("Failed to fetch pending reviewers for post %s: %s", post_id, exc)
        return []


def record_place_review(
    supabase: Client,
    *,
    user_id: str,
    place_id: str,
    action: str,
    location_id: int | None = None,
):
    """Upsert a user's action on a place candidate (auto-save, manual, etc.)."""
    try:
        supabase.table("social_post_place_reviews").upsert(
            {
                "user_id": user_id,
                "social_post_place_id": place_id,
                "action": action,
                "location_id": location_id,
            },
            on_conflict="user_id,social_post_place_id",
        ).execute()
    except Exception as exc:
        logger.warning(
            "Failed to record place review (%s) for place %s: %s", action, place_id, exc
        )


def touch_reviews_for_post(supabase: Client, post_id: str):
    """
    Bump updated_at on every review row for a post so the app's realtime
    subscription (on social_post_reviews only) sees processing completion.
    """
    try:
        supabase.table("social_post_reviews").update(
            {"status": "pending"}
        ).eq("social_post_id", post_id).eq("status", "pending").execute()
    except Exception as exc:
        logger.warning("Failed to touch reviews for post %s: %s", post_id, exc)


# ── Locations catalog ────────────────────────────────────────────────────────

def add_location(
    *,
    locations_add_url: str,
    place_id: str,
    source_url: str,
    platform: str,
    insights: dict | None = None,
    creator_handle: str | None = None,
) -> int | None:
    """
    Register a Google place in the locations catalog (and its video_insights)
    via /locations/add. No user action is recorded — saving to a user's Eat
    List happens in the app when they accept the place in the review UI.
    """
    add_payload: dict = {
        "google_place_id": place_id,
        "source": platform,
        "classify_photo": True,
    }
    if insights:
        add_payload["video_insights"] = {
            "source_video_url": source_url,
            "key_dishes": insights.get("key_dishes") or [],
            "special_offers": insights.get("special_offers") or [],
            "creator_notes": insights.get("creator_notes"),
            "vibe_signals": insights.get("vibe_signals") or {},
            "sentiment": insights.get("sentiment"),
            "creator_handle": creator_handle,
            "extraction_model": "gpt-4o-mini",
        }

    try:
        with httpx.Client(timeout=30.0) as client:
            resp = client.post(locations_add_url, json=add_payload)
            resp.raise_for_status()
        location_id = resp.json().get("location_id")
        if location_id:
            return int(location_id)
        logger.error("locations/add returned no location_id: %s", resp.json())
    except Exception as exc:
        logger.error("locations/add call failed for place_id=%s: %s", place_id, exc)
    return None
