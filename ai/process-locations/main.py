import logging
import os
import sys

import requests
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

RECOMMENDATIONS_API_URL = "https://pinit-recommendations-api-1070859807237.europe-west2.run.app/locations/add"
GOOGLE_PLACES_URL = "https://places.googleapis.com/v1/places:searchText"


class LocationProcessor:
    def __init__(self):
        self.gmaps_key = os.getenv("GOOGLE_PLACES_API_KEY")
        if not self.gmaps_key:
            raise ValueError("GOOGLE_PLACES_API_KEY environment variable is not set")

    def get_place_id(self, name: str) -> str | None:
        """Look up a place by name using Google Places API v1 and return its place_id."""
        headers = {
            "Content-Type": "application/json",
            "X-Goog-Api-Key": self.gmaps_key,
            "X-Goog-FieldMask": "places.id,places.displayName",
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
            place_id = places[0].get("id")
            display_name = places[0].get("displayName", {}).get("text", "")
            logger.info("Resolved %r -> %s (place_id: %s)", name, display_name, place_id)
            return place_id
        except Exception as exc:
            logger.error("Google Places lookup failed for %r: %s", name, exc)
            return None

    def add_location(self, place_id: str) -> None:
        """POST the place_id to the recommendations API."""
        payload = {
            "google_place_id": place_id,
            "classify_photo": True,
        }
        try:
            response = requests.post(RECOMMENDATIONS_API_URL, json=payload, timeout=30)
            logger.info("API response [%s]: %s", response.status_code, response.text)
        except Exception as exc:
            logger.error("Failed to add location %s: %s", place_id, exc)

    def process(self, names: list[str]) -> None:
        for name in names:
            logger.info("Processing: %s", name)
            place_id = self.get_place_id(name)
            if place_id:
                self.add_location(place_id)
            else:
                logger.warning("Skipping %r — could not resolve place_id", name)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python main.py \"Location Name 1\" \"Location Name 2\" ...")
        sys.exit(1)

    names = sys.argv[1:]
    processor = LocationProcessor()
    processor.process(names)
