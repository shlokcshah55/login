"""
TikTok Processor - Extracts location from TikTok videos
Workflow: TikTok API → OpenAI LLM → Google Places API
"""
import json
import logging
import asyncio
from typing import Dict, Optional, List
import httpx
from openai import OpenAI
from apify_client import ApifyClient

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class TikTokProcessor:
    def __init__(self, openaiKey: str, gmaps_key: str, appify_client:str):
        self.gmaps_key = gmaps_key
        self.openai_client = OpenAI(api_key=openaiKey)
        self.appify_client = ApifyClient(appify_client)

    async def process_url(self, tiktok_url: str) -> Dict:
        try:
            # First check if its instagram or tiktok
            if "instagram.com" in tiktok_url:
                video_data = await self._get_instagram_data_appify(tiktok_url)

            else:
                video_data = await self._get_tiktok_data_appify(tiktok_url, fetch_comments=False)
                logger.info("Extracted location information", video_data)

            # Extracting location without comments — now returns full
            # location dicts with rich insights (dishes, vibes, etc.)
            logger.info("Sending to OpenAI")
            location_dicts = self._extract_location_with_llm(video_data)
            logger.info(f"OpenAI extracted locations: {location_dicts}")

            # If location found, proceed immediately
            if location_dicts:
                logger.info(f"✅ Location found without comments! Count: {len(location_dicts)}")
                location = self._search_and_return_locations(location_dicts, video_data)
                logger.info("Completed Google Places search")
                return location

           # No location found, retry with comments
            if "instagram.com" in tiktok_url:
                video_data_with_comments = await self._get_instagram_data_appify(tiktok_url, fetch_comments=True)
            else:
                video_data_with_comments = await self._get_tiktok_data_appify(tiktok_url, fetch_comments=True)
            location_dicts = self._extract_location_with_llm(video_data_with_comments)
            logger.info(f"OpenAI extracted locations with comments: {location_dicts}")

            if not location_dicts:
                return {
                    "success": False,
                    "error": "Could not extract location from video even with comments"
                }

            logger.info(f"✅ Location found with comments! Count: {len(location_dicts)}")
            return self._search_and_return_locations(location_dicts, video_data_with_comments)

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

        # 6. Return the single consolidated object
        to_return =  {
            "id": video_id,
            "url": tiktok_url,
            "description": video_info.get("text", ""),
            "hashtags": hashtags,
            "comments": video_comments,
            "creator_handle": creator_handle,
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

    def _extract_location_with_llm(self, video_data: Dict) -> Optional[List[Dict]]:
        """
        Use OpenAI to extract location information AND rich insights from
        comprehensive video data including description, hashtags, and comments.

        Returns a list of location dicts, each containing:
          - location_name, search_query, confidence, source, reasoning
          - key_dishes, special_offers, creator_notes, vibe_signals, sentiment
        """
        try:
            video_desc = video_data.get("description", "")
            hashtags = video_data.get("hashtags", [])
            comments = video_data.get("comments", [])
            location_created = video_data.get("locationCreated")

            # The 22 vibe tags the app uses (must match VIBE_TAGS_ORDERED)
            vibe_tags_list = (
                "cafe, casual, cozy, coffee_shop, bar, elegant, fine_dining, "
                "food_truck, hole_in_the_wall, late_night, live_music, modern, "
                "fast_food, romantic, sports_bar, takeout_friendly, pub, "
                "grocery_store, brunch, outdoor_dining, wavy, bossman"
            )

            # Build comprehensive prompt with all available data
            prompt = f"""

# Role and Objective
You are a specialized location extraction AND insight analysis tool. Your job is to analyze TikTok/Reel video metadata and:
1. Extract specific restaurant/venue names that can be queried in the Google Places API
2. Extract key dishes, special offers, vibes, and the creator's take on the place

There may be more than one restaurant within the tiktok so be prepared to return more than one result.
Be liberal with trying to extract the locations, it is not the worst thing if they are incorrect.

# Available Data
- Video Description: "{video_desc}"
- Hashtags: {', '.join(hashtags) if hashtags else 'None'}
- Top Comments: {json.dumps(comments) if comments else 'None'}
- Video Created Location Metadata: "{location_created if location_created else 'None'}"


# Extraction Priority (for location identification)
You should check the metadata in the following order:

1. Location metadata (confidence: "high"): 
- If the location is provided you should use this as the primary source
- Validate this is a specific venue and not a generic city

2. Video Description (confidence: "high" or "medium"): 
- Most common source of location information
- Look for: restaurant names, addresses, cross-streets, neighborhoods
- High confidence: Name + neighborhood/area (e.g., "Carbone in Greenwich Village")
- Medium confidence: Name only (e.g., "Went to Carbone today")

3. Hashtags (confidence: "medium")
- Look for venue-specific hashtags (e.g., #nobudowntown, #joespizzanyc)
- Generic hashtags alone are insufficient (#foodie, #restaurant)

4. Top Comments (confidence: "low" - use as LAST RESORT)
- Only if NO location found in metadata, description, or hashtags
- Require MULTIPLE corroborating comments with the same location
- Ignore: single-word answers, jokes, vague responses, conflicting information
- Prioritize: comments from video creator, detailed responses with context

# Rich Insight Extraction (for each location found)
For EACH location you identify, also extract:

## key_dishes
Specific menu items or dishes the creator mentions or shows. Include:
- The dish name
- Any description the creator gives (e.g., "best I've ever had", "hidden gem on the menu")
- Price if mentioned
Return as a list of objects. If no dishes mentioned, return an empty list.

## special_offers
Any deals, discounts, promotions, or tips the creator shares. Examples:
- "Mention this TikTok for 20% off"
- "Happy hour 5-7pm half price cocktails"
- "Use code FOODIE for free delivery"
- "Ask for the secret menu item"
Include any dates, codes, or conditions. Return as a list of objects with offer, valid_until (null if unknown), and code (null if none). If no offers, return an empty list.

## creator_notes
A concise 1-2 sentence summary of the creator's overall take on the place. Capture their genuine opinion and key highlights. This should feel like a friend telling you about the spot.

## vibe_signals
Based on the video content, score any relevant vibes from this fixed vocabulary:
{vibe_tags_list}

Only include vibes that the video content clearly suggests. Score each 0.0-1.0 where 1.0 means the video strongly conveys this vibe. Usually 2-5 vibes are relevant. Do NOT include vibes with no evidence.

## sentiment
The creator's overall sentiment: "positive", "negative", or "mixed".

## Search Query Optimization for Google Places API
Format Pattern:
[Restaurant Name] [Neighborhood/District] [City]

- Include neighborhood/district when mentioned (e.g., "SoHo", "Downtown", "Shibuya")
- Include city and country
- For chains: include neighborhood, cross-streets, or landmark
- Avoid generic terms like "restaurant", "cafe" (Google infers this)

Return Valid JSON:

### Locations Found
{{
  "locations": [
    {{
      "location_name": "Carbone",
      "search_query": "Carbone Greenwich Village NYC",
      "confidence": "high",
      "source": "description",
      "reasoning": "Name explicitly mentioned with neighborhood",
      "key_dishes": [
        {{"name": "Spicy Rigatoni", "description": "Creator said 'best pasta in NYC'", "price": "$32"}},
        {{"name": "Meatballs", "description": "Shown close-up, creator's top pick", "price": null}}
      ],
      "special_offers": [
        {{"offer": "Mention this TikTok for free dessert", "valid_until": null, "code": null}}
      ],
      "creator_notes": "Late-night gem with incredible pasta. Creator went three times in one week and says it's their go-to date spot.",
      "vibe_signals": {{"romantic": 0.7, "late_night": 0.9, "elegant": 0.6, "cozy": 0.5}},
      "sentiment": "positive"
    }}
  ]
}}

### No locations found
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

            if "locations" in result and result["locations"]:
                # Return the full location dicts (not just search queries)
                return result["locations"]

            return []

        except Exception as e:
            logger.error(f"Error extracting location with OpenAI: {e}")
            return None

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

    def _safe_parse_json(self, text: str) -> Dict:
        """Parse JSON from OpenAI response, handling markdown code blocks"""
        try:
            # Remove markdown code blocks and whitespace
            cleaned = text.strip().strip('`').replace('json\n', '').replace('json', '').strip()
            return json.loads(cleaned)
        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse JSON from OpenAI response: {text}")
            return {}
