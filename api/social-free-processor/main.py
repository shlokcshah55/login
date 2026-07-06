"""
Flask API for the social-free-processor.

Endpoints:
  POST /process-share — user shares a TikTok/Reel URL → 202, async processing
  GET  /health        — health check

Processing flow:
  1. Return 202 immediately (never block the share extension)
  2. Background thread canonicalises the URL and dedupes against social_posts
  3. New posts run the extraction pipeline once, globally; results land in
     social_posts + social_post_places
  4. Every sharer gets a social_post_reviews row — the app's review inbox.
     High/medium-confidence places are saved to their Eat List by default
     (a share pays off even if the user never opens the app), and a push
     notification tells them what was saved. Low-confidence/failed posts stay
     unsaved and reviewable so the user can resolve them manually.
"""
import logging
import os
import threading
from datetime import datetime, timezone
from urllib.parse import urlparse, urlunparse

from dotenv import load_dotenv
from flask import Flask, jsonify, request
from openai import OpenAI
from supabase import create_client, Client

import notifications as notif
import supabase_store as store
from insights_extractor import extract_all_insights
from models import PipelineResult
from pipeline import process_url
from social_collection_redirects import (
    find_social_post_action,
    save_collection_for_user,
    save_location_for_user,
)
from stages.url_metadata import resolve_canonical_url

load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(name)s %(levelname)s %(message)s",
)
logger = logging.getLogger(__name__)

# ── Environment ──────────────────────────────────────────────────────────────

OPENAI_API_KEY         = os.environ["OPENAI_API_KEY"]
GOOGLE_PLACES_API_KEY  = os.environ["GOOGLE_PLACES_API_KEY"]
SUPABASE_URL           = os.environ["SUPABASE_URL"]
SUPABASE_SERVICE_KEY   = os.environ["SUPABASE_SERVICE_KEY"]
SEND_PUSH_NOTIF_SECRET = os.environ.get("SEND_PUSH_NOTIF_SECRET", "")
PORT                   = int(os.environ.get("PORT", 8080))

_DEFAULT_PUSH_URL = (
    "https://europe-west1-pinit-494520.cloudfunctions.net/send-push-notifications"
)
_DEFAULT_LOCATIONS_ADD_URL = (
    "https://pinit-recommendations-api-jkqbw4i75a-nw.a.run.app/locations/add"
)

# Insight extraction costs LLM calls per place; a listicle post rarely has
# more than this many genuinely distinct venues.
MAX_PLACES_PER_POST = 8


def _clean_url(value: str | None, default: str) -> str:
    candidate = (value or "").strip().strip('"').strip("'")
    if not candidate:
        return default
    if not candidate.startswith(("http://", "https://")):
        candidate = f"https://{candidate}"
    parsed = urlparse(candidate)
    if not parsed.scheme or not parsed.netloc:
        logger.warning("Invalid URL %r — using default", value)
        return default
    return candidate


PUSH_NOTIFICATION_URL = _clean_url(os.environ.get("PUSH_NOTIFICATION_URL"), _DEFAULT_PUSH_URL)
LOCATIONS_ADD_URL     = _clean_url(os.environ.get("LOCATIONS_ADD_URL"), _DEFAULT_LOCATIONS_ADD_URL)

# ── Singletons ───────────────────────────────────────────────────────────────

openai_client = OpenAI(api_key=OPENAI_API_KEY)
supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)

app = Flask(__name__)

# ── Helpers ──────────────────────────────────────────────────────────────────

def canonicalize_social_url(url: str) -> str:
    """
    Canonical form used for global post dedup: redirects already resolved,
    query/fragment stripped, scheme/host lowercased. The path keeps its case —
    Instagram shortcodes are case-sensitive and the canonical URL doubles as
    the "open original post" link.
    """
    parsed = urlparse(url)
    path = parsed.path.rstrip("/")
    return urlunparse((
        parsed.scheme.lower() or "https",
        parsed.netloc.lower(),
        path,
        "", "", "",
    ))


def _push_kwargs(user_id: str) -> dict:
    return {
        "supabase": supabase,
        "push_url": PUSH_NOTIFICATION_URL,
        "secret": SEND_PUSH_NOTIF_SECRET,
        "user_id": user_id,
    }


def _auto_save_places(post_id: str, user_id: str, platform: str, source_url: str) -> int:
    """
    Save every high/medium-confidence place from this post to the user's Eat
    List by default — a share should pay off even if the user never opens the
    app to review it. Low-confidence candidates are left for the user to
    resolve from the review screen. Returns the number saved.
    """
    saved = 0
    for place in store.get_post_places(supabase, post_id):
        location_id = place.get("location_id")
        if not location_id or place.get("confidence_tier") not in ("high", "medium"):
            continue
        result = save_location_for_user(
            supabase, user_id=user_id, location_id=location_id,
            platform=platform, source_url=source_url,
        )
        if not result.get("success"):
            logger.warning(
                "Auto-save failed for user %s place %s: %s",
                user_id, place["id"], result.get("error"),
            )
            continue
        store.record_place_review(
            supabase, user_id=user_id, place_id=place["id"],
            action="saved", location_id=location_id,
        )
        saved += 1
    return saved


def _notify_reviewers(post_id: str, platform: str, *, failed: bool = False):
    """Auto-save each pending reviewer's places, then send the review push."""
    places = [] if failed else store.get_post_places(supabase, post_id)
    for reviewer in store.get_pending_reviewers(supabase, post_id):
        reviewer_id = reviewer["user_id"]
        saved_count = 0
        if not failed:
            saved_count = _auto_save_places(
                post_id, reviewer_id, platform, reviewer.get("shared_url") or "",
            )
        notif.notify_review_ready(
            **_push_kwargs(reviewer_id),
            social_post_id=post_id,
            platform=platform,
            place_count=len(places),
            saved_count=saved_count,
            first_place_name=places[0]["name"] if places else None,
            failed=failed,
        )


# ── Background worker ────────────────────────────────────────────────────────

def _background_process(url: str, user_id: str):
    """
    Canonicalise, dedupe, and (if this share owns the post) run the pipeline.
    Every path ends with a review row for the sharer — including failures.
    """
    post_id: str | None = None
    platform = "instagram" if "instagram" in url.lower() else "tiktok"

    try:
        canonical = canonicalize_social_url(resolve_canonical_url(url))
        platform = "instagram" if "instagram" in canonical.lower() else "tiktok"

        post, created = store.create_post(
            supabase, canonical_url=canonical, platform=platform
        )
        if not post:
            raise RuntimeError(f"Could not create social post for {canonical}")
        post_id = post["id"]

        store.ensure_review(supabase, user_id=user_id, post_id=post_id, shared_url=url)

        if not created:
            status = post.get("status")
            if status == "processed":
                # Reuse the existing extraction — no reprocessing. This
                # sharer still gets their own auto-save + notification.
                _notify_reviewers(post_id, platform)
                return
            if status == "processing":
                # Another worker owns this post; it will notify all pending
                # reviewers (including this user) when it finishes.
                return
            # status == 'failed' → retry the pipeline for this new share
            store.mark_post_processing(supabase, post_id)

        # ── This worker owns processing from here ────────────────────────────

        # Curated redirect (social_post_actions): pre-resolved mapping becomes
        # high-confidence review candidates, auto-saved like any other match.
        action = find_social_post_action(supabase, url) or find_social_post_action(supabase, canonical)
        if action:
            logger.info("Curated redirect found for %s", canonical)
            existing = {p.get("location_id") for p in store.get_post_places(supabase, post_id)}
            for loc in store.get_location_summaries(supabase, action["location_ids"]):
                if loc["location_id"] in existing:
                    continue
                store.insert_post_place(
                    supabase,
                    post_id=post_id,
                    name=loc.get("name") or "Saved place",
                    google_place_id=loc.get("google_place_id"),
                    location_id=loc["location_id"],
                    address=loc.get("vicinity"),
                    confidence_score=1.0,
                    confidence_tier="high",
                    extracted_context={"source": "curated"},
                )
            if action.get("eat_list_collection_id"):
                save_collection_for_user(
                    supabase, user_id=user_id,
                    collection_id=action["eat_list_collection_id"],
                )
            store.update_post(supabase, post_id, {
                "status": "processed",
                "processed_at": datetime.now(timezone.utc).isoformat(),
            })
            store.touch_reviews_for_post(supabase, post_id)
            _notify_reviewers(post_id, platform)
            return

        # Full extraction pipeline
        result: PipelineResult = process_url(canonical, openai_client, GOOGLE_PLACES_API_KEY)
        logger.info("Pipeline result for %s: status=%s", canonical, result.status)
        meta = result.meta

        if result.status == "failed":
            store.update_post(supabase, post_id, {
                "status": "failed",
                "error": result.error or "pipeline failed",
                "creator_handle": meta.creator_handle if meta else None,
                "title": meta.title if meta else None,
            })
            store.touch_reviews_for_post(supabase, post_id)
            _notify_reviewers(post_id, platform, failed=True)
            return

        # Post-level vibes/sentiment (unscoped — the overall feel of the post)
        post_insights = extract_all_insights(openai_client, meta) if meta else {}

        matches = result.candidate_matches[:MAX_PLACES_PER_POST]
        for match in matches:
            tier = match.score.tier
            insights = None
            location_id = None
            if tier in ("high", "medium"):
                # Venue-scoped insights + catalog registration so the app can
                # save instantly. Low-tier candidates stay lightweight; the
                # app resolves them via /locations/add only if the user saves.
                if meta:
                    insights = extract_all_insights(
                        openai_client, meta, place_name=match.place.name
                    )
                location_id = store.add_location(
                    locations_add_url=LOCATIONS_ADD_URL,
                    place_id=match.place.place_id,
                    source_url=canonical,
                    platform=platform,
                    insights=insights,
                    creator_handle=meta.creator_handle if meta else None,
                )
            context = {
                "source": match.candidate.source,
                "reasoning": match.candidate.reasoning,
            }
            if insights:
                context.update(insights)
            store.insert_post_place(
                supabase,
                post_id=post_id,
                name=match.place.name,
                google_place_id=match.place.place_id,
                location_id=location_id,
                address=match.place.address,
                candidate_name=match.candidate.name,
                candidate_area=match.candidate.area,
                confidence_score=match.score.overall,
                confidence_tier=tier,
                extracted_context=context,
            )

        store.update_post(supabase, post_id, {
            "status": "processed",
            "creator_handle": meta.creator_handle if meta else None,
            "title": meta.title if meta else None,
            "vibes": post_insights.get("vibe_signals") or {},
            "sentiment": post_insights.get("sentiment"),
            "evidence_flags": result.evidence_flags.to_dict(),
            "processed_at": datetime.now(timezone.utc).isoformat(),
        })
        store.touch_reviews_for_post(supabase, post_id)
        _notify_reviewers(post_id, platform)

    except Exception as exc:
        logger.error("Background processing error for %s: %s", url, exc, exc_info=True)
        if post_id:
            store.update_post(supabase, post_id, {"status": "failed", "error": str(exc)})
            store.touch_reviews_for_post(supabase, post_id)
            _notify_reviewers(post_id, platform, failed=True)


# ── API endpoints ────────────────────────────────────────────────────────────

@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "healthy", "service": "social-free-processor"}), 200


@app.route("/process-share", methods=["POST"])
def process_share():
    """
    Accept a TikTok/Reel URL from the user's share extension.
    Returns 202 immediately; processing happens asynchronously.

    Body: {"url": "...", "userId": "..."}
    """
    data = request.get_json(silent=True)
    if not data:
        return jsonify({"success": False, "error": "JSON body required"}), 400

    url = (data.get("url") or "").strip()
    user_id = (data.get("userId") or "").strip()

    if not url or not user_id:
        return jsonify({"success": False, "error": "url and userId are required"}), 400

    if not url.startswith(("http://", "https://")):
        return jsonify({"success": False, "error": "url must be an absolute HTTP/HTTPS URL"}), 400

    logger.info("Share received: user=%s url=%s", user_id, url)

    thread = threading.Thread(target=_background_process, args=(url, user_id), daemon=True)
    thread.start()

    return jsonify({"success": True, "message": "Saving this post…"}), 202


@app.errorhandler(404)
def not_found(e):
    return jsonify({"success": False, "error": "Endpoint not found"}), 404


@app.errorhandler(500)
def internal_error(e):
    return jsonify({"success": False, "error": "Internal server error"}), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=PORT, debug=False)
