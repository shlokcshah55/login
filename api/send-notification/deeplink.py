from __future__ import annotations

from dataclasses import dataclass
from typing import Any


DEEP_LINK_KEYS: tuple[str, ...] = ("deepLink", "deep_link", "deeplink")


TYPE_ALIASES: dict[str, str] = {
    # Historical / alternate type names.
    "location_saved": "video_processed",
    # Common typo observed in the wild.
    "proximity_locaiton": "proximity_location",
}


KNOWN_TYPES: frozenset[str] = frozenset(
    {
        # Current app-supported notification types.
        "video_processed",
        "processing_error",
        "follow_request",
        "follow_accepted",
        "friend_visited_location",
        "proximity_location",
        "new_message",
        "user_added_to_bubble",
        "notes_import_complete",
        "blast",
    }
)


@dataclass(frozen=True)
class DeepLinkResolutionError(Exception):
    message: str

    def __str__(self) -> str:  # pragma: no cover
        return self.message


def normalize_notification_type(value: Any) -> str:
    raw = "" if value is None else str(value)
    canonical = raw.strip().lower()
    if not canonical:
        return ""
    return TYPE_ALIASES.get(canonical, canonical)


def find_existing_deep_link(metadata: Any) -> str | None:
    if not isinstance(metadata, dict):
        return None
    for key in DEEP_LINK_KEYS:
        candidate = metadata.get(key)
        if candidate is None:
            continue
        candidate_str = str(candidate).strip()
        if candidate_str:
            return candidate_str
    return None


def resolve_deep_link(notif_type: str, metadata: dict[str, Any]) -> str | None:
    """
    Resolve an in-app deep link from a notification type + metadata.

    Returns:
        A deep-link string like "pinit://user/<id>", or None when no navigation
        should occur for the given type.

    Raises:
        DeepLinkResolutionError when the type is mapped but required IDs are
        missing in metadata.
    """
    t = normalize_notification_type(notif_type)

    if t in ("follow_request", "follow_accepted"):
        user_id = _first_non_empty(metadata, ("userId",))
        if not user_id:
            raise DeepLinkResolutionError(
                f"Missing required metadata field: userId for type {t}"
            )
        return f"pinit://user/{user_id}"

    if t == "proximity_location":
        location_id = _first_non_empty(metadata, ("locationId",))
        if not location_id:
            raise DeepLinkResolutionError(
                "Missing required metadata field: locationId for type proximity_location"
            )
        return f"pinit://location/{location_id}"

    if t in ("user_added_to_bubble", "new_message"):
        bubble_id = _first_non_empty(metadata, ("bubbleId",))
        if not bubble_id:
            raise DeepLinkResolutionError(
                f"Missing required metadata field: bubbleId for type {t}"
            )
        return f"pinit://bubble/{bubble_id}"

    if t == "video_processed":
        location_id = _first_non_empty(metadata, ("locationId",))
        if not location_id:
            raise DeepLinkResolutionError(
                "Missing required metadata field: locationId for type video_processed"
            )
        return f"pinit://location/{location_id}"

    return None


def _first_non_empty(metadata: dict[str, Any], keys: tuple[str, ...]) -> str | None:
    for key in keys:
        value = metadata.get(key)
        if value is None:
            continue
        value_str = str(value).strip()
        if value_str:
            return value_str
    return None
