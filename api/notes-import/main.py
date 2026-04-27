"""
Notes Import Processor
Workflow: Uploaded notes text/file -> OpenAI extraction -> Google Places -> Supabase save
"""
import json
import logging
import os
import re
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import httpx
from bs4 import BeautifulSoup
from openai import OpenAI
from striprtf.striprtf import rtf_to_text
from supabase import Client, create_client


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

DEFAULT_LOCATION_ADD_API_URL = (
    "https://pinit-recommendations-api-jkqbw4i75a-nw.a.run.app/locations/add"
)

# DEFAULT_LOCATION_ADD_API_URL = 'http://localhost:8080/locations/add'

class NotesImportProcessor:
    """Extract and save locations from user-uploaded notes."""

    def __init__(self, openai_api_key: str, gmaps_key: str, supabase_url: str, supabase_service_key: str):
        self.gmaps_key = gmaps_key
        self.openai_client = OpenAI(api_key=openai_api_key)
        self.supabase: Client = create_client(supabase_url, supabase_service_key)
        self.location_add_api_url = os.getenv("LOCATION_ADD_API_URL", DEFAULT_LOCATION_ADD_API_URL)
        self.model = os.getenv("OPENAI_MODEL", "gpt-4o-mini")

    def parse_note_input(
        self,
        text: Optional[str] = None,
        file_bytes: Optional[bytes] = None,
        filename: Optional[str] = None,
        source_name: Optional[str] = None,
        content_type: Optional[str] = None,
    ) -> Tuple[str, str]:
        """
        Normalize either raw text or a supported uploaded file to plain text.
        Returns (normalized_text, source_name).
        """
        resolved_source_name = source_name or filename

        if text and text.strip():
            return text.strip(), resolved_source_name or "pasted-note"

        if not file_bytes:
            raise ValueError("Provide either note text or an uploaded file")

        source_name = resolved_source_name or "uploaded-note"
        suffix = Path(source_name).suffix.lower()

        if suffix in {".txt", ".md", ".markdown", ".csv"} or content_type == "text/plain":
            return file_bytes.decode("utf-8", errors="ignore").strip(), source_name

        if suffix in {".html", ".htm"} or content_type == "text/html":
            html = file_bytes.decode("utf-8", errors="ignore")
            soup = BeautifulSoup(html, "html.parser")
            return soup.get_text("\n", strip=True), source_name

        if suffix == ".json" or content_type == "application/json":
            decoded = file_bytes.decode("utf-8", errors="ignore")
            parsed = json.loads(decoded)
            return self._flatten_json_to_text(parsed).strip(), source_name

        if suffix == ".rtf" or content_type == "application/rtf":
            decoded = file_bytes.decode("utf-8", errors="ignore")
            return rtf_to_text(decoded).strip(), source_name

        raise ValueError(
            "Unsupported file type. Use txt, md, html, json, or rtf, or send raw text."
        )

    def process_note(
        self,
        user_id: str,
        note_text: str,
        source_name: str,
    ) -> Dict:
        trimmed_text, truncated = self._trim_input(note_text)
        extracted_locations = self._extract_locations_with_llm(trimmed_text, source_name)

        if not extracted_locations:
            return {
                "success": False,
                "error": "No candidate locations found in note",
                "source_name": source_name,
                "truncated_input": truncated,
                "extracted_count": 0,
            }

        matched_locations = []
        unmatched_locations = []

        for candidate in extracted_locations:
            search_query = candidate.get("search_query")
            if not search_query:
                continue

            place_result = self._search_google_place(search_query)
            if not place_result:
                unmatched_locations.append({
                    "location_name": candidate.get("location_name"),
                    "search_query": search_query,
                    "confidence": candidate.get("confidence"),
                    "source_excerpt": candidate.get("source_excerpt"),
                })
                continue

            matched_locations.append({
                "candidate": candidate,
                "place": place_result,
            })

        if not matched_locations:
            return {
                "success": False,
                "error": "No extracted locations could be matched in Google Places",
                "source_name": source_name,
                "truncated_input": truncated,
                "extracted_count": len(extracted_locations),
                "matched_count": 0,
                "unmatched_locations": unmatched_locations,
            }

        saved_locations: List[Dict] = []
        skipped_locations: List[Dict] = []

        for match in matched_locations:
            candidate = match["candidate"]
            place = match["place"]
            save_result = self._save_place_for_user(user_id=user_id, place_data=place)

            if not save_result:
                skipped_locations.append({
                    "location_name": candidate.get("location_name"),
                    "search_query": candidate.get("search_query"),
                    "place_id": place.get("place_id"),
                    "reason": "save_failed",
                })
                continue

            if save_result.get("already_saved"):
                skipped_locations.append({
                    "location_name": candidate.get("location_name"),
                    "search_query": candidate.get("search_query"),
                    "place_id": place.get("place_id"),
                    "location_id": save_result.get("location_id"),
                    "reason": "already_saved",
                })
                continue

            saved_locations.append({
                "location_id": save_result.get("location_id"),
                "place_id": place.get("place_id"),
                "name": place.get("name"),
                "address": place.get("formatted_address"),
                "search_query": candidate.get("search_query"),
                "confidence": candidate.get("confidence"),
            })

        return {
            "success": True,
            "source_name": source_name,
            "truncated_input": truncated,
            "extracted_count": len(extracted_locations),
            "matched_count": len(matched_locations),
            "saved_count": len(saved_locations),
            "already_saved_count": len([item for item in skipped_locations if item["reason"] == "already_saved"]),
            "save_failed_count": len([item for item in skipped_locations if item["reason"] == "save_failed"]),
            "saved_locations": saved_locations,
            "skipped_locations": skipped_locations,
            "unmatched_locations": unmatched_locations,
        }

    def _extract_locations_with_llm(self, note_text: str, source_name: str) -> List[Dict]:
        """Extract likely venue/location candidates from arbitrary note content."""
        prompt = f"""
# Role and Objective
You extract specific real-world places from user notes. The notes may come from Apple Notes or Notion and can include lists, headings, bullets, pasted recommendations, itineraries, and free-form text.

Your task is to identify every plausible venue or place that a user would want to save as a location.

# Extraction Rules
- Prefer restaurants, cafes, bars, bakeries, clubs, museums, galleries, shops, markets, landmarks, parks, hotels, and other Google-searchable places.
- Include places even if confidence is medium, as long as the place seems plausibly real and useful.
- Do not invent places.
- Do not return generic concepts like "best pizza", "downtown", "west village", or "Shoreditch" unless the text clearly refers to a specific Google-searchable place.
- Deduplicate repeated places.
- If a city or neighborhood helps disambiguate a place, include it in the search query.
- If the note contains grouped city sections, use that city context in the search query.

# Source
Source name: "{source_name}"

# Note text
\"\"\"
{note_text}
\"\"\"

# Output
Return valid JSON only, in this shape:
{{
  "locations": [
    {{
      "location_name": "place name from the note",
      "search_query": "optimized Google Places text query",
      "confidence": "high|medium|low",
      "source_excerpt": "short excerpt from the note proving this extraction"
    }}
  ]
}}
"""

        response = self.openai_client.chat.completions.create(
            model=self.model,
            messages=[{"role": "user", "content": prompt}],
            response_format={"type": "json_object"},
        )

        parsed = self._safe_parse_json(response.choices[0].message.content)
        raw_locations = parsed.get("locations", [])
        if not isinstance(raw_locations, list):
            return []

        deduped: List[Dict] = []
        seen_queries = set()

        for item in raw_locations:
            if not isinstance(item, dict):
                continue
            search_query = (item.get("search_query") or "").strip()
            location_name = (item.get("location_name") or "").strip()
            if not search_query or not location_name:
                continue

            normalized_key = re.sub(r"\s+", " ", search_query.lower())
            if normalized_key in seen_queries:
                continue
            seen_queries.add(normalized_key)

            deduped.append({
                "location_name": location_name,
                "search_query": search_query,
                "confidence": item.get("confidence", "medium"),
                "source_excerpt": (item.get("source_excerpt") or "")[:200],
            })

        logger.info("Extracted %s unique location candidates from note", len(deduped))
        return deduped

    def _search_google_place(self, query: str) -> Optional[Dict]:
        """Search for a place using Places API (New) text search."""
        try:
            url = "https://places.googleapis.com/v1/places:searchText"
            headers = {
                "Content-Type": "application/json",
                "X-Goog-Api-Key": self.gmaps_key,
                "X-Goog-FieldMask": (
                    "places.id,"
                    "places.displayName,"
                    "places.formattedAddress,"
                    "places.location,"
                    "places.types,"
                    "places.rating"
                ),
            }
            payload = {
                "textQuery": query,
                "pageSize": 1,
            }

            with httpx.Client(timeout=10.0) as client:
                response = client.post(url, headers=headers, json=payload)
                response.raise_for_status()
                result = response.json()

            places = result.get("places", [])
            if not places:
                logger.warning("No Google Places results found for query: %s", query)
                return None

            top_result = places[0]
            normalized_result = {
                "place_id": top_result.get("id"),
                "name": top_result.get("displayName", {}).get("text"),
                "formatted_address": top_result.get("formattedAddress"),
                "geometry": {
                    "location": top_result.get("location"),
                },
                "types": top_result.get("types", []),
                "rating": top_result.get("rating"),
            }
            logger.info("Found Google Place match for query %r: %s", query, normalized_result.get("name"))
            return normalized_result

        except Exception as exc:
            logger.error("Error searching Google Places for %r: %s", query, exc)
            return None

    def _save_place_for_user(self, user_id: str, place_data: Dict) -> Optional[Dict]:
        """Persist a resolved Google Place using the same location-add and RPC path as TikTok."""
        try:
            place_id = place_data["place_id"]

            existing = self.supabase.table("locations").select("location_id").eq("google_place_id", place_id).execute()
            if existing and getattr(existing, "data", None):
                location_id = existing.data[0]["location_id"]
                logger.info("Location already exists for place_id %s as location_id %s", place_id, location_id)
            else:
                payload = {
                    "google_place_id": place_id,
                    "classify_photo": True,
                }

                with httpx.Client(timeout=30.0) as client:
                    response = client.post(self.location_add_api_url, json=payload)
                    response.raise_for_status()
                    api_result = response.json()

                location_id = api_result.get("location_id")
                if not location_id:
                    logger.error("Location add API response missing location_id: %s", api_result)
                    return None

                logger.info("Created new location %s for place_id %s", location_id, place_id)

            result = self.supabase.rpc(
                "save_location_with_tags",
                {
                    "p_user_id": user_id,
                    "p_location_id": location_id,
                    "p_saved_method": "in-app",
                    "p_acked": True,
                    "p_source_video_url": None,
                },
            ).execute()

            response = result.data
            if response and response.get("success"):
                logger.info("Saved location %s for user %s", location_id, user_id)
                return {
                    "location_id": location_id,
                    "already_saved": response.get("action_created") is False,
                }

            error = response.get("error", "Unknown error") if response else "No response"
            if "already saved" in error.lower():
                return {
                    "location_id": location_id,
                    "already_saved": True,
                }

            logger.error("Failed to save location %s for user %s: %s", location_id, user_id, error)
            return None

        except Exception as exc:
            logger.error("Error saving place for user %s: %s", user_id, exc, exc_info=True)
            return None

    def _trim_input(self, text: str, max_chars: int = 40000) -> Tuple[str, bool]:
        cleaned = text.strip()
        if len(cleaned) <= max_chars:
            return cleaned, False
        return cleaned[:max_chars], True

    def _flatten_json_to_text(self, value: object) -> str:
        if isinstance(value, dict):
            return "\n".join(self._flatten_json_to_text(v) for v in value.values())
        if isinstance(value, list):
            return "\n".join(self._flatten_json_to_text(item) for item in value)
        if value is None:
            return ""
        return str(value)

    def _safe_parse_json(self, text: str) -> Dict:
        try:
            cleaned = text.strip()
            if cleaned.startswith("```"):
                cleaned = cleaned.strip("`")
                cleaned = cleaned.replace("json\n", "", 1).strip()
            return json.loads(cleaned)
        except json.JSONDecodeError:
            logger.error("Failed to parse JSON from OpenAI response: %s", text)
            return {}
