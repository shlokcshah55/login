"""Helpers for redirecting specific social URLs to eat-list saves."""

import logging
from urllib.parse import urlparse, urlunparse
from uuid import UUID

logger = logging.getLogger(__name__)


def normalize_social_url(url: str | None) -> str | None:
    candidate = (url or "").strip().strip('"').strip("'")
    if not candidate:
        return None
    if not candidate.startswith(("http://", "https://")):
        candidate = f"https://{candidate}"

    parsed = urlparse(candidate)
    if not parsed.netloc:
        return None

    path = parsed.path.rstrip("/")
    return urlunparse((
        parsed.scheme.lower(),
        parsed.netloc.lower(),
        path,
        "",
        "",
        "",
    )).lower()


def find_social_post_action(supabase_client, url: str | None) -> dict | None:
    normalized = normalize_social_url(url)
    if not normalized or not supabase_client:
        return None

    try:
        response = (
            supabase_client.table("social_post_actions")
            .select("url,normalized_url,platform,location_ids,eat_list_collection_id")
            .eq("normalized_url", normalized)
            .maybe_single()
            .execute()
        )
        row = getattr(response, "data", None)
    except Exception as exc:
        logger.error("Failed to look up social post action: %s", exc, exc_info=True)
        return None

    if not row:
        return None

    platform = _normalize_platform(row.get("platform"))
    if not platform:
        logger.warning("Skipping social post action with invalid platform: %r", row)
        return None

    location_ids = _normalize_location_ids(row.get("location_ids"))
    collection_id = _normalize_uuid(str(row.get("eat_list_collection_id") or ""))
    if not location_ids and not collection_id:
        logger.warning("Skipping social post action with no locations or eat-list: %r", row)
        return None

    return {
        "platform": platform,
        "location_ids": location_ids,
        "eat_list_collection_id": collection_id,
    }


def save_location_for_user(
    supabase_client,
    *,
    user_id: str,
    location_id: int,
    platform: str,
    source_url: str,
) -> dict:
    normalized_platform = _normalize_platform(platform)
    if not normalized_platform:
        return {"success": False, "error": "Invalid platform"}
    if not user_id:
        return {"success": False, "error": "Missing user id"}
    if not supabase_client:
        return {"success": False, "error": "Supabase client not initialized"}

    try:
        normalized_location_id = int(location_id)
    except (TypeError, ValueError):
        return {"success": False, "error": "Invalid location id"}

    try:
        result = supabase_client.rpc("save_location_with_tags", {
            "p_user_id": user_id,
            "p_location_id": normalized_location_id,
            "p_saved_method": normalized_platform,
            "p_acked": True,
            "p_source_video_url": source_url,
        }).execute()
        response = getattr(result, "data", None)
    except Exception as exc:
        logger.error("Failed to save social post location: %s", exc, exc_info=True)
        return {"success": False, "error": str(exc)}

    if response and response.get("success"):
        message = response.get("message", "")
        return {
            "success": True,
            "location_id": normalized_location_id,
            "name": None,
            "already_saved": "already saved" in message.lower(),
        }

    return {
        "success": False,
        "location_id": normalized_location_id,
        "error": response.get("error", "Unknown error") if response else "No response",
    }


def save_collection_for_user(supabase_client, user_id: str, collection_id: str) -> dict:
    normalized_collection_id = _normalize_uuid(collection_id)
    if not normalized_collection_id:
        return {"success": False, "error": "Invalid collection id"}
    if not user_id:
        return {"success": False, "error": "Missing user id"}
    if not supabase_client:
        return {"success": False, "error": "Supabase client not initialized"}

    try:
        collection_response = (
            supabase_client.table("collections")
            .select("collection_id,name,created_by,is_public")
            .eq("collection_id", normalized_collection_id)
            .maybe_single()
            .execute()
        )
        collection = getattr(collection_response, "data", None)
        if not collection:
            return {"success": False, "error": "Collection not found"}

        if collection.get("created_by") == user_id:
            return {
                "success": True,
                "collection_id": normalized_collection_id,
                "name": collection.get("name"),
                "already_owned": True,
            }

        if collection.get("is_public") is not True:
            return {"success": False, "error": "Collection is private"}

        (
            supabase_client.table("collection_saves")
            .upsert(
                {
                    "user_id": user_id,
                    "collection_id": normalized_collection_id,
                },
                on_conflict="user_id,collection_id",
            )
            .execute()
        )
        return {
            "success": True,
            "collection_id": normalized_collection_id,
            "name": collection.get("name"),
            "already_owned": False,
        }
    except Exception as exc:
        logger.error("Failed to save collection redirect: %s", exc, exc_info=True)
        return {"success": False, "error": str(exc)}


def apply_social_post_action(
    supabase_client,
    *,
    user_id: str,
    source_url: str,
    action: dict,
) -> dict:
    platform = action.get("platform")
    saved_locations = []
    errors = []

    for location_id in action.get("location_ids", []):
        result = save_location_for_user(
            supabase_client,
            user_id=user_id,
            location_id=location_id,
            platform=platform,
            source_url=source_url,
        )
        if result.get("success"):
            saved_locations.append(result)
        else:
            errors.append(result.get("error", "Unknown location error"))

    collection = None
    collection_id = action.get("eat_list_collection_id")
    if collection_id:
        collection = save_collection_for_user(
            supabase_client,
            user_id=user_id,
            collection_id=collection_id,
        )
        if not collection.get("success"):
            errors.append(collection.get("error", "Unknown collection error"))

    return {
        "success": bool(saved_locations or (collection and collection.get("success"))),
        "saved_locations": saved_locations,
        "collection": collection,
        "errors": errors,
    }


def _normalize_uuid(value: str) -> str | None:
    try:
        return str(UUID(value.strip()))
    except (TypeError, ValueError):
        return None


def _normalize_platform(value: str | None) -> str | None:
    normalized = (value or "").strip().lower()
    if normalized in {"tiktok", "instagram"}:
        return normalized
    return None


def _normalize_location_ids(value) -> list[int]:
    if not isinstance(value, list):
        return []

    location_ids: list[int] = []
    seen: set[int] = set()
    for item in value:
        try:
            location_id = int(item)
        except (TypeError, ValueError):
            continue
        if location_id <= 0 or location_id in seen:
            continue
        seen.add(location_id)
        location_ids.append(location_id)
    return location_ids
