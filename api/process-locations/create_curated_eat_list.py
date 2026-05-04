import argparse
import logging
import os
from pathlib import Path
import re
from typing import Iterable

from dotenv import load_dotenv
from supabase import create_client, Client

from main import LocationProcessor

def _load_env() -> None:
    base = Path(__file__).resolve()
    candidates = [
        base.parent / ".env",
        base.parent / ".env.local",
        base.parents[2] / ".env",
    ]
    for p in candidates:
        if p.exists():
            load_dotenv(dotenv_path=p, override=False)


_load_env()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)

PINIT_USER_ID = "2f26688a-0e38-4a7a-9876-68bea3e57edd"


def _require_env(name: str) -> str:
    val = os.getenv(name)
    if not val:
        raise ValueError(f"{name} environment variable is not set")
    return val


def _supabase_client() -> Client:
    url = _require_env("SUPABASE_URL")
    key = _require_env("SUPABASE_SERVICE_KEY")
    return create_client(url, key)


def _slugify(text: str) -> str:
    s = text.strip().lower()
    s = re.sub(r"[^\w\s-]", "", s)
    s = re.sub(r"[\s_-]+", "-", s)
    return s.strip("-")


def _read_places(path: str) -> list[str]:
    with open(path, "r", encoding="utf-8") as f:
        lines = []
        for raw in f.readlines():
            s = raw.strip()
            if not s or s.startswith("#"):
                continue
            lines.append(s)
        return lines


def ensure_curated_owner(supabase: Client) -> None:
    supabase.table("users").upsert(
        {
            "supabase_id": PINIT_USER_ID,
            "email": "curated@pinit.app",
            "name": "Pinit",
            "username": "pinit",
            "wizard_completed": True,
        }
    ).execute()


def create_collection(
    supabase: Client,
    *,
    name: str,
    description: str,
    city: str,
    emoji: str | None,
    collection_id: str | None,
) -> str:
    payload: dict = {
        "name": name,
        "description": description,
        "emoji": emoji,
        "created_by": PINIT_USER_ID,
        "is_curated": True,
        "is_public": True,
        "curated_city": city,
    }
    if collection_id:
        payload["collection_id"] = collection_id

    res = supabase.table("collections").upsert(payload).execute()

    # Prefer the returned id if present; otherwise rely on the provided id.
    data = getattr(res, "data", None) or res.data  # type: ignore[attr-defined]
    if data and isinstance(data, list) and data[0].get("collection_id"):
        return data[0]["collection_id"]
    if collection_id:
        return collection_id

    # Fall back: try to fetch by name + owner + curated_city.
    row = (
        supabase.table("collections")
        .select("collection_id")
        .eq("created_by", PINIT_USER_ID)
        .eq("name", name)
        .eq("curated_city", city)
        .limit(1)
        .execute()
    )
    row_data = getattr(row, "data", None) or row.data  # type: ignore[attr-defined]
    if row_data:
        return row_data[0]["collection_id"]

    raise RuntimeError("Failed to resolve collection_id after upsert")


def link_locations(
    supabase: Client, *, collection_id: str, location_ids: Iterable[int]
) -> None:
    rows = [
        {
            "collection_id": collection_id,
            "location_id": int(location_id),
            "added_by": PINIT_USER_ID,
        }
        for location_id in location_ids
    ]
    if not rows:
        return
    try:
        supabase.table("collection_locations").insert(rows).execute()
    except Exception as exc:
        # If some rows already exist, insert may fail depending on PostgREST
        # behavior. Re-try row-by-row to be idempotent.
        logger.info("Bulk insert failed (%s). Falling back to row-by-row.", exc)
        for r in rows:
            try:
                supabase.table("collection_locations").insert(r).execute()
            except Exception as inner:
                logger.info("Skipping link (likely exists): %s", inner)


def main() -> int:
    ap = argparse.ArgumentParser(
        description=(
            "Create a curated eat-list: ingest places, create the collection, "
            "and link all locations."
        )
    )
    ap.add_argument("--name", required=True, help="Collection name")
    ap.add_argument("--description", required=True, help="Collection description")
    ap.add_argument("--city", required=True, help="Curated city (e.g. London)")
    ap.add_argument("--emoji", default=None, help="Optional emoji for the list")
    ap.add_argument(
        "--collection-id",
        default=None,
        help="Optional stable UUID to assign to the collection",
    )
    ap.add_argument(
        "--places-file",
        default=None,
        help="Path to a newline-delimited list of place names",
    )
    ap.add_argument(
        "--place",
        action="append",
        default=None,
        help="A single place name (repeatable).",
    )
    args = ap.parse_args()

    places: list[str] = []
    if args.places_file:
        places.extend(_read_places(args.places_file))
    if args.place:
        places.extend([p.strip() for p in args.place if p.strip()])
    # De-dupe while preserving order.
    seen = set()
    places = [p for p in places if not (p in seen or seen.add(p))]
    if not places:
        logger.error("No places provided. Use --places-file and/or --place.")
        return 2

    supabase = _supabase_client()
    ensure_curated_owner(supabase)

    processor = LocationProcessor()
    processor.supabase = supabase

    logger.info("Processing %d places...", len(places))
    location_ids: list[int] = []
    for name in places:
        result = processor.get_place_info(name)
        if not result:
            logger.warning("Skipping %r — could not resolve place_id", name)
            continue
        place_id, rating, user_ratings_total, lat, lng = result
        location_id = processor.add_location(place_id, rating, user_ratings_total, lat, lng)
        if location_id:
            location_ids.append(location_id)
        else:
            logger.warning("Ingest failed for %r (place_id=%s)", name, place_id)

    if not location_ids:
        logger.error("No locations were ingested; refusing to create an empty list.")
        return 3

    collection_id = create_collection(
        supabase,
        name=args.name,
        description=args.description,
        city=args.city,
        emoji=args.emoji,
        collection_id=args.collection_id,
    )

    logger.info("Collection ready: %s", collection_id)
    link_locations(supabase, collection_id=collection_id, location_ids=location_ids)
    logger.info("Linked %d locations.", len(location_ids))
    logger.info("Done.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
