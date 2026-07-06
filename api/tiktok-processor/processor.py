"""
TikTok Processor - Extracts location from TikTok videos
Workflow: TikTok API → OpenAI LLM → Google Places API
"""
import json
import logging
import asyncio
from pathlib import Path
from typing import Dict, Optional, List
import httpx
from openai import OpenAI
from apify_client import ApifyClient

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)
SCRIPT_DIR = Path(__file__).resolve().parent


class TikTokProcessor:
    def __init__(self, openaiKey: str, gmaps_key: str, appify_client:str):
        self.gmaps_key = gmaps_key
        self.openai_client = OpenAI(api_key=openaiKey)
        self.appify_client = ApifyClient(appify_client)

    async def process_url(self, tiktok_url: str) -> Dict:
        try:
            is_instagram = "instagram.com" in tiktok_url

            # 1. Fetch video data (without comments first — faster)
            if is_instagram:
                video_data = await self._get_instagram_data_appify(tiktok_url)
            else:
                video_data = await self._get_tiktok_data_appify(tiktok_url, fetch_comments=False)

            # 2. Extract location only (Call 1)
            logger.info("Extracting location...")
            location_dicts = await asyncio.to_thread(self._extract_locations, video_data, False)
            logger.info(f"Location extraction result: {location_dicts}")

            # 3. Comment-based retry temporarily disabled — no comment scraping.
            if not location_dicts:
                return {
                    "success": False,
                    "error": "Could not extract location from video"
                }

            logger.info(f"✅ Location found! Count: {len(location_dicts)}")

            # 4. Extract insights PER PLACE — a video covering multiple venues has
            # distinct dishes/vibes for each, so each location gets its own scoped
            # extraction calls (factual + interpretive run in parallel per venue).
            logger.info("Extracting per-place insights in parallel...")

            async def _insights_for_location(loc: Dict):
                venue_name = loc.get("location_name") or ""
                factual, interpretive = await asyncio.gather(
                    asyncio.to_thread(self._extract_factual_insights, video_data, venue_name),
                    asyncio.to_thread(self._extract_interpretive_signals, video_data, venue_name),
                )
                loc.update({**factual, **interpretive})
                logger.info(f"Insights for {venue_name!r}: {factual} {interpretive}")

            await asyncio.gather(*(_insights_for_location(loc) for loc in location_dicts))

            logger.info("Completed Google Places search")
            return self._search_and_return_locations(location_dicts, video_data)

        except Exception as e:
            logger.error(f"Error processing TikTok URL: {e}", exc_info=True)
            return {
                "success": False,
                "error": str(e)
            }
        
    async def _get_tiktok_data_appify(self, tiktok_url: str, fetch_comments:bool=False) -> Dict:
        # 1. Prepare inputs
        run_input = {"postURLs": [tiktok_url]}

        # 2. Call Apify scrapers (blocking call - waits for completion)
        logger.info("Calling Apify metadata scraper...")
        run_meta = await asyncio.to_thread(
            self.appify_client.actor("clockworks/tiktok-scraper").call,
            run_input=run_input
        )
        logger.info("Metadata scraper completed")

        run_comments = None
        video_comments = []
        if fetch_comments:
            logger.info("Calling Apify comments scraper...")
            run_comments = await asyncio.to_thread(
                self.appify_client.actor("clockworks/tiktok-comments-scraper").call,
                run_input=run_input
            )
            if run_comments:
                video_comments = [
                c.get("text") for c in self.appify_client.dataset(run_comments["defaultDatasetId"]).iterate_items() 
            ]
            logger.info("Comments scraper completed")


        # 3. Fetch dataset items
        meta_items = list(self.appify_client.dataset(run_meta["defaultDatasetId"]).iterate_items())
        
        if not meta_items:
            return {}

        video_info = meta_items[0]
        logger.info(video_info)
        video_id = video_info.get("id")
        
  
        # 4. Extract Hashtags
        # TikTok hashtags are often nested in 'textExtra'
        logger.info(video_info.get("hashtags",[]))
        hashtags = [
            h.get("name")
            for h in video_info.get("hashtags", [])
        ]

        # 5. Extract creator handle
        author_info = video_info.get("authorMeta", {}) or video_info.get("author", {})
        creator_handle = author_info.get("name") or author_info.get("uniqueId")

        # 5b. Fetch subtitle transcript (TikTok's own machine captions) — the
        # spoken content often names restaurants the caption never mentions.
        subtitle_links = (video_info.get("videoMeta") or {}).get("subtitleLinks") or []
        transcript = await asyncio.to_thread(self._fetch_subtitle_transcript, subtitle_links)
        if transcript:
            logger.info(f"Subtitle transcript fetched: {len(transcript)} chars")

        # 6. Return the single consolidated object
        to_return =  {
            "id": video_id,
            "url": tiktok_url,
            "description": video_info.get("text", ""),
            "hashtags": hashtags,
            "comments": video_comments,
            "creator_handle": creator_handle,
            "transcript": transcript,
        }

        logger.info(to_return)

        return to_return
    

    async def _get_instagram_data_appify(self, instagram_url: str, fetch_comments: bool = False) -> Dict:
        # 1. Prepare inputs — apify/instagram-scraper uses directUrls for individual post/reel URLs
        run_input = {
            "directUrls": [instagram_url],
            "resultsType": "posts",
            "resultsLimit": 1,
        }
        if fetch_comments:
            run_input["includeComments"] = True

        # 2. Call Apify scraper (blocking call - waits for completion)
        logger.info("Calling Apify Instagram scraper...")
        run_meta = await asyncio.to_thread(
            self.appify_client.actor("apify/instagram-scraper").call,
            run_input=run_input
        )
        logger.info("Instagram scraper completed")

        # 3. Fetch dataset items
        meta_items = list(self.appify_client.dataset(run_meta["defaultDatasetId"]).iterate_items())

        if not meta_items:
            return {}

        post_info = meta_items[0]
        logger.info(post_info)

        # 4. Extract hashtags — Instagram returns them as a flat list of strings
        hashtags = post_info.get("hashtags", [])
        logger.info(hashtags)

        # 5. Extract comments — included inline when includeComments=True
        video_comments = []
        if fetch_comments:
            video_comments = [
                c.get("text") for c in post_info.get("latestComments", [])
                if c.get("text")
            ]

        # 6. Extract creator handle
        creator_handle = post_info.get("ownerUsername") or post_info.get("ownerFullName")

        # 7. Return the consolidated object matching the shape expected by the rest of the pipeline
        to_return = {
            "id": post_info.get("id"),
            "url": instagram_url,
            "description": post_info.get("caption", ""),
            "hashtags": hashtags,
            "comments": video_comments,
            "locationCreated": post_info.get("locationName"),
            "creator_handle": creator_handle,
        }

        logger.info(to_return)

        return to_return

    def _extract_locations(self, video_data: Dict, with_comments: bool) -> Optional[List[Dict]]:
        """
        Call 1: Extract venue name(s) only — no insight fields.
        Returns a list of dicts with location_name, search_query, confidence,
        source, reasoning.
        """
        try:
            video_desc = video_data.get("description", "")
            hashtags = video_data.get("hashtags", [])
            comments = video_data.get("comments", [])
            location_created = video_data.get("locationCreated")
            transcript = video_data.get("transcript", "")

            extra_bit  = "When using the comments field, be extra cautious and only return locations if there are multiple corroborating comments mentioning the same place. Comments are often speculative or questions, so require strong signals to trust them."


            prompt = f"""
# Role
You are a location extraction tool. Your only job is to identify specific restaurant or venue names from TikTok/Reel video metadata so they can be looked up in the Google Places API.

There may be more than one venue in the video — return all of them.
Be liberal: it is not the worst thing if a result is slightly incorrect.

# Available Data
- Video Description: "{video_desc}"
- Hashtags: {', '.join(hashtags) if hashtags else 'None'}
- Spoken Transcript (machine-generated subtitles): "{transcript if transcript else 'None'}"
- Top Comments: {json.dumps(comments) if comments else 'None'}
- Location Metadata: "{location_created if location_created else 'None'}"

# Source Priority
1. Location metadata — use if it names a specific venue (not just a city)
2. Video description — most common; look for restaurant/venue names, addresses, neighborhoods
   - High confidence: name + neighborhood (e.g. "Carbone in Greenwich Village")
   - Medium confidence: name only (e.g. "went to Carbone today")
3. Spoken transcript — creators often say venue names aloud that never appear in the caption
   (e.g. "first up is Dhamaka on the Lower East Side"). The transcript is machine-generated,
   so venue names may be misspelled or phonetically wrong — normalise obvious errors when
   the intended name is clear (e.g. "dama ka" → "Dhamaka")
4. Hashtags — venue-specific only (e.g. #nobudowntown); generic tags like #foodie are not enough
5. Comments — last resort only; require multiple corroborating comments naming the same place

{extra_bit if with_comments else ""}

# Search Query Format
[Venue Name] [Neighborhood/District] [City]
- Include neighborhood/district when mentioned
- Avoid generic category words like "restaurant" or "cafe"

# Output — JSON only

## Locations found
{{
  "locations": [
    {{
      "location_name": "Carbone",
      "search_query": "Carbone Greenwich Village NYC",
      "confidence": "high",
      "source": "description",
      "reasoning": "Name explicitly mentioned with neighborhood"
    }}
  ]
}}

## No locations found
{{
  "locations": []
}}
"""

            response = self.openai_client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[{"role": "user", "content": prompt}],
                response_format={"type": "json_object"}
            )
            result = self._safe_parse_json(response.choices[0].message.content)
            return result.get("locations") or []

        except Exception as e:
            logger.error(f"Error extracting locations: {e}")
            return None

    def _extract_factual_insights(self, video_data: Dict, venue_name: str = "") -> Dict:
        """
        Call 2a (parallel, per venue): Extract factual claims — key dishes and
        special offers — scoped to a single venue. Every item requires a verbatim
        evidence quote from the source text. If no quote can be found, the array
        stays empty.
        """
        try:
            video_desc = video_data.get("description", "")
            hashtags = video_data.get("hashtags", [])
            comments = video_data.get("comments", [])
            transcript = video_data.get("transcript", "")

            venue_scope = f"""
# Venue Scope — IMPORTANT
This video may mention multiple venues. You are extracting insights for ONE venue only: "{venue_name}".
Only include dishes and offers that are clearly attributable to "{venue_name}".
If a dish or offer belongs to a different venue mentioned in the video, or you cannot tell which venue it belongs to, DO NOT include it.
""" if venue_name else ""

            prompt = f"""
# Role
You are a factual claim extractor. Your job is to find specific dishes and special offers that are EXPLICITLY mentioned in TikTok/Reel video metadata.
{venue_scope}

# Source Data
- Video Description: "{video_desc}"
- Hashtags: {', '.join(hashtags) if hashtags else 'None'}
- Spoken Transcript (machine-generated subtitles): "{transcript if transcript else 'None'}"
- Comments: {json.dumps(comments) if comments else 'None'}

The spoken transcript counts as a valid evidence source — creators usually describe dishes
aloud rather than in the caption. Quote the transcript verbatim in the evidence field.
Note it is machine-generated, so dish names may be slightly garbled; normalise only when obvious.

For every item you extract, you MUST include an "evidence" field containing the exact verbatim text from the source data that supports it. If you cannot find a direct quote, do not include the item. Return an empty array rather than fabricating claims.

# What to Extract

## key_dishes
Specific menu items or dishes that the creator mentions or describes with a positive sentiment. Include name, description (creator's words and the verbatim evidence quote).

## special_offers
Deals, discounts, promo codes, or tips the creator explicitly shares (e.g. "mention this TikTok for 20% off", "happy hour 5-7pm"). Include the offer text, valid_until (null if unknown), code (null if none), and verbatim evidence quote.

Please note that comments are less reliable sources of information, so only include details from comments when they are making factual claims not questions or speculations.
# Output — JSON only

## Example: video with content worth extracting
{{
  "key_dishes": [
    {{"evidence": "the spicy rigatoni here is literally the best pasta in NYC, get it every time", "name": "Spicy Rigatoni", "description": "Creator's favourite, says it's the best pasta in NYC", "price": null}},
    {{"evidence": "meatballs are $18 and absolutely worth it", "name": "Meatballs", "description": "Worth it according to creator"}}
  ],
  "special_offers": [
    {{"evidence": "mention this video at the door and get a free dessert", "offer": "Mention this video at the door for a free dessert", "valid_until": null, "code": null}}
  ]
}}

## Example: video with nothing to extract
{{
  "key_dishes": [],
  "special_offers": []
}}
"""

            response = self.openai_client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[{"role": "user", "content": prompt}],
                response_format={"type": "json_object"}
            )
            result = self._safe_parse_json(response.choices[0].message.content)
            return {
                "key_dishes": result.get("key_dishes") or [],
                "special_offers": result.get("special_offers") or [],
            }

        except Exception as e:
            logger.error(f"Error extracting factual insights: {e}")
            return {"key_dishes": [], "special_offers": []}

    def _extract_interpretive_signals(self, video_data: Dict, venue_name: str = "") -> Dict:
        """
        Call 2b (parallel, per venue): Extract interpretive signals — vibe scores,
        sentiment, and a creator summary — scoped to a single venue. These are
        impression-based, not factual claims, so evidence quoting is not required —
        but only include vibes with clear support from the content.
        """
        try:
            video_desc = video_data.get("description", "")
            hashtags = video_data.get("hashtags", [])
            comments = video_data.get("comments", [])
            transcript = video_data.get("transcript", "")

            # Load the fixed vibe vocabulary from the checked-in table file.
            with open(SCRIPT_DIR / "vibe_table.txt", "r") as f:
                vibe_tags_list = f.read().strip()

            venue_scope = f"""
# Venue Scope — IMPORTANT
This video may mention multiple venues. You are analysing ONE venue only: "{venue_name}".
Only score vibes, sentiment, and notes based on content clearly about "{venue_name}".
Ignore content about other venues. If nothing in the video is specifically about this venue's atmosphere, return minimal output.
""" if venue_name else ""

            prompt = f"""
# Role
You are an atmosphere and sentiment analyser. Given TikTok/Reel video metadata about a venue, extract:
1. vibe_signals — scored impressions of the venue's atmosphere
2. sentiment — the creator's overall tone
3. creator_notes — a short summary of the creator's take
{venue_scope}

# Source Data
- Video Description: "{video_desc}"
- Hashtags: {', '.join(hashtags) if hashtags else 'None'}
- Spoken Transcript (machine-generated subtitles): "{transcript if transcript else 'None'}"
- Comments: {json.dumps(comments) if comments else 'None'}

The spoken transcript is usually the richest signal for atmosphere and the creator's genuine
opinion — weight it strongly when present.

# Instructions

## vibe_signals
Score relevant vibes from this fixed vocabulary ONLY:
{vibe_tags_list}

Score each 0.0–1.0. Only include vibes with clear evidence in the content — typically 2–5. Do NOT invent vibes.

## sentiment
The creator's overall tone: "positive", "negative", or "mixed".

## creator_notes
1–2 sentences capturing the creator's genuine opinion and key highlights. Write it like a friend's recommendation. If the content is too sparse to form an opinion, write a single brief sentence.

# Output — JSON only

## Example: expressive video
{{
  "vibe_signals": {{"romantic": 0.8, "elegant": 0.7, "late_night": 0.6}},
  "sentiment": "positive",
  "creator_notes": "A go-to date spot with impeccable pasta. The creator has been three times and can't stop raving about the atmosphere."
}}

## Example: sparse/minimal video
{{
  "vibe_signals": {{"casual": 0.6}},
  "sentiment": "positive",
  "creator_notes": "Creator recommends this spot for a casual meal."
}}
"""

            response = self.openai_client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[{"role": "user", "content": prompt}],
                response_format={"type": "json_object"}
            )
            result = self._safe_parse_json(response.choices[0].message.content)
            return {
                "vibe_signals": result.get("vibe_signals") or {},
                "sentiment": result.get("sentiment"),
                "creator_notes": result.get("creator_notes"),
            }

        except Exception as e:
            logger.error(f"Error extracting interpretive signals: {e}")
            return {"vibe_signals": {}, "sentiment": None, "creator_notes": None}

    def _search_and_return_locations(self, location_dicts: List[Dict], video_data: Dict) -> Dict:
        """
        Search Google Places for extracted locations and return formatted results
        including rich insight data (dishes, vibes, offers, notes).

        Args:
            location_dicts: List of enriched location dicts from LLM (each has
                           search_query + key_dishes + vibe_signals + etc.)
            video_data: Video metadata dict

        Returns:
            Dict with success status and locations/error
        """
        locations = []
        for loc_dict in location_dicts:
            query = loc_dict.get("search_query", "")
            if not query:
                continue

            place_result = self._search_google_place(query)

            if place_result:
                locations.append({
                    "place": {
                        "place_id": place_result.get("place_id"),
                        "name": place_result.get("name"),
                        "address": place_result.get("formatted_address"),
                        "location": place_result.get("geometry", {}).get("location"),
                        "types": place_result.get("types", []),
                        "rating": place_result.get("rating"),
                    },
                    "video_data": {
                        "id": video_data.get("id"),
                        "description": video_data.get("description", ""),
                        "creator_handle": video_data.get("creator_handle"),
                        "hashtags": video_data.get("hashtags", []),
                        "comments": video_data.get("comments", []),
                    },
                    # Rich insights extracted from the video by the LLM
                    "key_dishes": loc_dict.get("key_dishes", []),
                    "special_offers": loc_dict.get("special_offers", []),
                    "creator_notes": loc_dict.get("creator_notes"),
                    "vibe_signals": loc_dict.get("vibe_signals", {}),
                    "sentiment": loc_dict.get("sentiment"),
                })
            else:
                logger.warning(f"No place found for query: {query}")

        if locations:
            return {"success": True, "locations": locations}
        else:
            return {
                "success": False,
                "error": "Could not find matching places on Google Maps for any extracted location"
            }


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
                logger.warning(f"No results found for query: {query}")
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
            logger.info(f"Found place: {normalized_result.get('name')}")
            return normalized_result

        except Exception as e:
            logger.error(f"Error searching Google Places: {e}")
            return None

    def _fetch_subtitle_transcript(self, subtitle_links: List[Dict], max_chars: int = 4000) -> str:
        """
        Download and parse TikTok's machine-generated subtitles (WebVTT) into a
        plain-text transcript. Prefers English. Held in memory only — the raw
        VTT is never stored; only extraction results are persisted.
        """
        if not subtitle_links:
            return ""

        # Prefer English subtitle tracks, fall back to the first available
        preferred = sorted(
            subtitle_links,
            key=lambda s: 0 if str(s.get("language", "")).lower().startswith("eng") else 1,
        )
        link = preferred[0].get("downloadLink") or preferred[0].get("tiktokLink")
        if not link:
            return ""

        try:
            with httpx.Client(timeout=10.0) as client:
                response = client.get(link)
                response.raise_for_status()
                return self._parse_vtt(response.text, max_chars)
        except Exception as e:
            logger.warning(f"Failed to fetch subtitle transcript: {e}")
            return ""

    @staticmethod
    def _parse_vtt(vtt_text: str, max_chars: int = 4000) -> str:
        """Strip WebVTT headers/timestamps and collapse duplicate cues to plain text."""
        lines = []
        prev = None
        for raw_line in vtt_text.splitlines():
            line = raw_line.strip()
            if (not line
                    or line.startswith(("WEBVTT", "NOTE", "STYLE"))
                    or "-->" in line
                    or line.isdigit()):
                continue
            if line != prev:
                lines.append(line)
                prev = line
        return " ".join(lines)[:max_chars]

    def _safe_parse_json(self, text: str) -> Dict:
        """Parse JSON from OpenAI response, handling markdown code blocks"""
        try:
            # Remove markdown code blocks and whitespace
            cleaned = text.strip().strip('`').replace('json\n', '').replace('json', '').strip()
            return json.loads(cleaned)
        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse JSON from OpenAI response: {text}")
            return {}
