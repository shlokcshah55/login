import logging
import math
import os
from pathlib import Path
import sys

import requests
from dotenv import load_dotenv
from supabase import create_client, Client
from postgrest.exceptions import APIError

def _load_env() -> None:
    # Prefer an explicit .env path to avoid python-dotenv stack introspection
    # issues when running under different entrypoints.
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
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

RECOMMENDATIONS_API_URL = "https://pinit-recommendations-api-jkqbw4i75a-nw.a.run.app/locations/add"
GOOGLE_PLACES_URL = "https://places.googleapis.com/v1/places:searchText"


class LocationProcessor:
    def __init__(self):
        self.gmaps_key = os.getenv("GOOGLE_PLACES_API_KEY")
        if not self.gmaps_key:
            raise ValueError("GOOGLE_PLACES_API_KEY environment variable is not set")

        supabase_url = os.getenv("SUPABASE_URL")
        supabase_key = os.getenv("SUPABASE_SERVICE_KEY")
        if not supabase_url or not supabase_key:
            raise ValueError("SUPABASE_URL and SUPABASE_SERVICE_KEY environment variables must be set")
        self.supabase: Client = create_client(supabase_url, supabase_key)

    def get_place_info(self, name: str) -> tuple[str, float, int, float | None, float | None] | None:
        """Look up a place by name and return (place_id, rating, user_ratings_total, lat, lng)."""
        headers = {
            "Content-Type": "application/json",
            "X-Goog-Api-Key": self.gmaps_key,
            "X-Goog-FieldMask": "places.id,places.displayName,places.rating,places.userRatingCount,places.location",
        }
        payload = {
            "textQuery": name,
            "pageSize": 1,
        }

        try:
            response = requests.post(GOOGLE_PLACES_URL, headers=headers, json=payload, timeout=10)
            response.raise_for_status()
            places = response.json().get("places", [])
            if not places:
                logger.warning("No Google Places result found for: %s", name)
                return None
            place = places[0]
            place_id = place.get("id")
            display_name = place.get("displayName", {}).get("text", "")
            rating = place.get("rating", 3.8)
            user_ratings_total = place.get("userRatingCount", 0)
            location = place.get("location", {})
            lat = location.get("latitude")
            lng = location.get("longitude")
            logger.info(
                "Resolved %r -> %s (place_id: %s, rating: %s, reviews: %s, lat: %s, lng: %s)",
                name, display_name, place_id, rating, user_ratings_total, lat, lng,
            )
            return place_id, rating, user_ratings_total, lat, lng
        except Exception as exc:
            logger.error("Google Places lookup failed for %r: %s", name, exc)
            return None

    def _calculate_google_baseline_score(self, rating: float, user_ratings_total: int) -> float:
        rating = rating or 3.8
        n = user_ratings_total or 0

        bayesian_rating = (rating * n + 3.8 * 50) / (n + 50)

        review_trust = (
            min(0.95 * math.pow(math.log(1 + n) / math.log(501), 0.6), 1.0)
            if n > 0 else 0.0
        )

        return (bayesian_rating / 5.0) * min(review_trust, 0.85 + 0.15 * (bayesian_rating / 5.0))

    def add_location(
        self,
        place_id: str,
        rating: float,
        user_ratings_total: int,
        lat: float | None,
        lng: float | None,
    ) -> int | None:
        """POST the place_id to the recommendations API, then seed location_popularity_app."""
        def lookup_location_id() -> int | None:
            # Fast-path: if the location already exists, use it.
            try:
                res = (
                    self.supabase.table("locations")
                    .select("location_id")
                    .eq("google_place_id", place_id)
                    .limit(1)
                    .execute()
                )
                if res.data and len(res.data) > 0 and res.data[0].get("location_id") is not None:
                    return int(res.data[0]["location_id"])
            except Exception:
                # Lookup is a best-effort fallback; don't fail the whole pipeline.
                return None
            return None

        payload = {
            "google_place_id": place_id,
            "classify_photo": True,
            "generate_image": True,
            "source": "tiktok",
            # "process_synchronously": True,
        }
        try:
            response = requests.post(RECOMMENDATIONS_API_URL, json=payload, timeout=180)
            logger.info("API response [%s]: %s", response.status_code, response.text)
            response.raise_for_status()

            data = response.json()
            location_id = data.get("location_id") or data.get("id")
            if not location_id:
                logger.warning("No location_id in API response for place_id %s — skipping popularity insert", place_id)
                return lookup_location_id()

            google_baseline_score = self._calculate_google_baseline_score(rating, user_ratings_total)
            # New locations have no video insights yet
            video_insight_score = 0.0

            try:
                self.supabase.table("location_popularity_app").insert(
                    {
                        "location_id": location_id,
                        "saves_count": 0,
                        "dislikes_count": 0,
                        "been_to_count": 0,
                        "quality_score": 0,
                        "share_count": 0,
                        "app_engagement_score": 0,
                        "google_baseline_score": google_baseline_score,
                        "video_insight_score": video_insight_score,
                        "quality_score": 0.1,
                    }
                ).execute()
                logger.info(
                    "Seeded location_popularity_app for location_id=%s "
                    "(google_baseline=%.4f, video_insight=%.4f)",
                    location_id,
                    google_baseline_score,
                    video_insight_score,
                )
            except Exception as exc:
                # Some versions of supabase/postgrest will raise APIError, others may bubble
                # a dict-like payload. We only care that duplicates are non-fatal.
                code = None
                payload = None
                if isinstance(exc, APIError) and exc.args:
                    payload = exc.args[0]
                elif isinstance(exc, dict):
                    payload = exc
                elif getattr(exc, "args", None):
                    payload = exc.args[0] if exc.args else None

                if isinstance(payload, dict):
                    code = payload.get("code")

                if code == "23505":
                    logger.info(
                        "location_popularity_app already exists for location_id=%s; continuing",
                        location_id,
                    )
                else:
                    logger.warning(
                        "Failed to seed location_popularity_app for location_id=%s (%s). Continuing anyway.",
                        location_id,
                        exc,
                    )
            return int(location_id)
        except Exception as exc:
            logger.error("Failed to add location %s: %s", place_id, exc)
            # Fallback: if the recommendations API or popularity insert failed,
            # try to use an existing location row by google_place_id.
            return lookup_location_id()

    def process(self, names: list[str]) -> None:
        for name in names:
            logger.info("Processing: %s", name)
            result = self.get_place_info(name)
            if result:
                place_id, rating, user_ratings_total, lat, lng = result
                self.add_location(place_id, rating, user_ratings_total, lat, lng)
            else:
                logger.warning("Skipping %r — could not resolve place_id", name)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python main.py \"Location Name 1\" \"Location Name 2\" ...")
        sys.exit(1)

    names = sys.argv[1:]
    processor = LocationProcessor()
    processor.process(names)
