"""
Stage 4 / Stage 7: Google Places resolution.

For each candidate, performs a Places text search and returns up to
`results_per_candidate` matches. Deduplicates across candidates so
the same place_id doesn't appear twice in the output.
"""
import logging

import httpx

from models import Candidate, ResolvedPlace

logger = logging.getLogger(__name__)

_PLACES_URL = "https://places.googleapis.com/v1/places:searchText"
_FIELD_MASK = (
    "places.id,"
    "places.displayName,"
    "places.formattedAddress,"
    "places.location,"
    "places.types,"
    "places.rating"
)


def resolve_candidates(
    candidates: list[Candidate],
    gmaps_key: str,
    results_per_candidate: int = 3,
) -> list[tuple[Candidate, list[ResolvedPlace]]]:
    """
    For each candidate, search Google Places and return matching places.

    Returns: list of (candidate, [places]) pairs.
    Places are globally deduplicated across candidates.
    """
    seen_place_ids: set[str] = set()
    results: list[tuple[Candidate, list[ResolvedPlace]]] = []

    for candidate in candidates:
        if not candidate.search_query.strip():
            continue
        places = _search_places(candidate.search_query, gmaps_key, n=results_per_candidate)
        unique_places = []
        for place in places:
            if place.place_id and place.place_id not in seen_place_ids:
                seen_place_ids.add(place.place_id)
                unique_places.append(place)
        if unique_places:
            results.append((candidate, unique_places))

    return results


def _search_places(query: str, gmaps_key: str, n: int = 3) -> list[ResolvedPlace]:
    try:
        headers = {
            "Content-Type": "application/json",
            "X-Goog-Api-Key": gmaps_key,
            "X-Goog-FieldMask": _FIELD_MASK,
        }
        payload = {"textQuery": query, "pageSize": n}
        with httpx.Client(timeout=10.0) as client:
            resp = client.post(_PLACES_URL, headers=headers, json=payload)
            resp.raise_for_status()
            data = resp.json()

        places: list[ResolvedPlace] = []
        for p in data.get("places", []):
            loc = p.get("location", {})
            places.append(ResolvedPlace(
                place_id=p.get("id", ""),
                name=p.get("displayName", {}).get("text", ""),
                address=p.get("formattedAddress", ""),
                lat=loc.get("latitude"),
                lng=loc.get("longitude"),
                types=p.get("types", []),
                rating=p.get("rating"),
            ))
        return places

    except Exception as exc:
        logger.warning("Places search failed for %r: %s", query, exc)
        return []
