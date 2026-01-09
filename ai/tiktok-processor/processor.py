"""
TikTok Processor - Extracts location from TikTok videos
Workflow: TikTok API → OpenAI LLM → Google Places API
"""
import json
import logging
import asyncio
from typing import Dict, Optional, List
import googlemaps
from openai import OpenAI
from apify_client import ApifyClient

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class TikTokProcessor:
    def __init__(self, openaiKey: str, gmaps_key: str, appify_client:str):
        self.gmaps = googlemaps.Client(key=gmaps_key)
        self.openai_client = OpenAI(api_key=openaiKey)
        self.appify_client = ApifyClient(appify_client)

    async def process_url(self, tiktok_url: str) -> Dict:
        try:
            video_data = await self._get_tiktok_data_appify(tiktok_url, fetch_comments=False)
            logger.info("Extracted locaiton information", video_data)

            # Extracting location without comments
            logger.info("Sending to OpenAI")
            location_queries = self._extract_location_with_llm(video_data)
            logger.info(f"OpenAI extracted location queries: {location_queries}")

            # If location found, proceed immediately
            if location_queries:
                logger.info(f"✅ Location found without comments! Queries: {location_queries}")
                location = self._search_and_return_locations(location_queries, video_data)
                logger.info("Completed Google Places search")
                return location

           # No location found, retry with comments
            video_data_with_comments = await self._get_tiktok_data_appify(tiktok_url, fetch_comments=True)
            location_queries = self._extract_location_with_llm(video_data_with_comments)
            logger.info(f"OpenAI extracted location queries with comments: {location_queries}")

            if not location_queries:
                return {
                    "success": False,
                    "error": "Could not extract location from video even with comments"
                }

            logger.info(f"✅ Location found with comments! Queries: {location_queries}")
            return self._search_and_return_locations(location_queries, video_data_with_comments)

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

        # 5. Return the single consolidated object
        to_return =  {
            "id": video_id,
            "url": tiktok_url,
            "description": video_info.get("text", ""),
            "hashtags": hashtags,
            "comments": video_comments,
        }

        logger.info(to_return)

        return to_return

    def _extract_location_with_llm(self, video_data: Dict) -> Optional[str]:
        """
        Use OpenAI to extract location information from comprehensive video data
        including description, hashtags, and comments
        """
        try:
            video_desc = video_data.get("description", "")
            hashtags = video_data.get("hashtags", [])
            comments = video_data.get("comments", [])
            location_created = video_data.get("locationCreated")

            # Build comprehensive prompt with all available data
            prompt = f"""

# Role and Objective
You are a specialized location extraction tool. Your job is to analyze TikTok video metadata and extract specific restaurant/venue names that can be successfully queried in the Google Places API. You must extract precise, verifiable locations - NOT generic areas, cities, or vague references.

There may be more than one restaurant within the tiktok so be prepared to return more than one result.

Be liberal with trying to extract the locations, it is not the worst thing if they are incorrect.

# Available Data
- Video Description: "{video_desc}"
- Hashtags: {', '.join(hashtags) if hashtags else 'None'}
- Top Comments: {json.dumps(comments) if comments else 'None'}
- Video Created Location Metadata: "{location_created if location_created else 'None'}"


# Extraction Priority
You should check the metadata in the following order

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
 
 # Output Format
 You should be outputting the:
 - location_name : The venue/restaurant name that is found
 - search_query : an optimised query to ask the Google places API to extract the exact location
 - confidence : enum of "high", "medium", "low" to understand how confident we are of this location:
 - source : which metadata this was looked at and extracted from

## Search Query Optimization for Google Places API
Format Pattern:
[Restaurant Name] [Neighborhood/District] [City]

- Include neighborhood/district when mentioned (e.g., "SoHo", "Downtown", "Shibuya")
- Include city and country
- For chains: include neighborhood, cross-streets, or landmark
- Avoid generic terms like "restaurant", "cafe" (Google infers this)

 Return Valid JSON in the cases of:

 ### Locations Found
{{
  "locations": [
    {{
      "location_name": "First restaurant",
      "search_query": "First restaurant search query",
      "confidence": "high",
      "source": "description",
      "reasoning": "..."
    }},
    {{
      "location_name": "Second restaurant",
      "search_query": "Second restaurant search query",
      "confidence": "medium",
      "source": "hashtags",
      "reasoning": "..."
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

            search_queries = []
            if "locations" in result and result["locations"]:
                for loc in result["locations"]:
                    search_queries.append(loc.get("search_query"))

            # Handle single location format: {"search_query": "..."}
            return search_queries

        except Exception as e:
            logger.error(f"Error extracting location with OpenAI: {e}")
            return None

    def _search_and_return_locations(self, location_queries: List[str], video_data: Dict) -> Dict:
        """
        Search Google Places for location queries and return formatted results

        Args:
            location_queries: List of location search queries
            video_data: Video metadata dict

        Returns:
            Dict with success status and locations/error
        """
        locations = []
        for query in location_queries:
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
                        "description": video_data.get("desc"),
                        "author": video_data.get("author", {}).get("uniqueId"),
                        "hashtags": video_data.get("hashtags", []),
                        "comments": video_data.get("comments", []),
                    }
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
        """Search for a place using Google Places API"""
        try:
            # Use Places Text Search
            result = self.gmaps.places(query=query)

            if result.get("results"):
                # Return the top result
                top_result = result["results"][0]
                logger.info(f"Found place: {top_result.get('name')}")
                return top_result
            else:
                logger.warning(f"No results found for query: {query}")
                return None

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