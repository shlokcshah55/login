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
from TikTokApi import TikTokApi

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class TikTokProcessor:
    def __init__(self, openaiKey: str, gmaps_key: str, ):
        self.gmaps = googlemaps.Client(key=gmaps_key)
        self.tiktok_api = TikTokApi(
            logging_level=logging.INFO
        )
        self.openai_client = OpenAI(api_key=openaiKey)

    async def process_url(self, tiktok_url: str) -> Dict:
        try:
            logger.info("Attempting location extraction without comments")
            video_data = await self._get_tiktok_data(tiktok_url, fetch_comments=False)
            logger.info("Extracted locaiton information")

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
            video_data_with_comments = await self._get_tiktok_data(tiktok_url, fetch_comments=True)
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

    # Extract comprehensive video data from TikTok URL including with exponential backoff retries:
    async def _get_tiktok_data(self, url: str, fetch_comments: bool = False) -> Dict:
        max_retries = 3
        base_delay = 2 

        for attempt in range(max_retries):
            try:
                logger.info(f"Attempt {attempt + 1}/{max_retries} to fetch TikTok data")

                async with self.tiktok_api:
                    # Create sessions with proper timeout configuration
                    await self.tiktok_api.create_sessions(
                        num_sessions=1,
                        headless=True,
                        sleep_after=3,
                        timeout=90000,  # 90 seconds timeout for page navigation
                        context_options={
                            "viewport": {"width": 1920, "height": 1080},
                        },
                        # Block unnecessary resources for faster loading
                        suppress_resource_load_types=["image", "stylesheet", "font", "media"],
                        override_browser_args=[
                            # Container compatibility
                            "--no-sandbox",
                            "--disable-setuid-sandbox",
                            "--disable-dev-shm-usage",

                            # Anti-detection
                            "--disable-blink-features=AutomationControlled",

                            # Performance optimizations
                            "--disable-gpu",
                            "--disable-software-rasterizer",
                            "--disable-extensions",
                            "--disable-plugins",
                            "--disable-background-networking",
                            "--disable-background-timer-throttling",
                            "--disable-backgrounding-occluded-windows",
                            "--disable-renderer-backgrounding",
                            "--disable-sync",
                            "--disable-translate",
                            "--disable-features=TranslateUI",
                            "--disable-features=BlinkGenPropertyTrees",
                            "--disable-ipc-flooding-protection",
                            "--disable-default-apps",
                            "--no-default-browser-check",
                            "--no-first-run",
                            "--mute-audio",

                            # Network optimizations
                            "--disable-features=IsolateOrigins,site-per-process",
                            "--disable-features=NetworkService",

                            # Memory optimizations
                            "--single-process",  # Use with caution - can be unstable but faster
                            "--disable-dev-tools",
                        ]
                    )

                    # Get video from URL
                    video = self.tiktok_api.video(url=url)
                    video_info = await video.info()

                    # Extract hashtags from the video data
                    hashtags = []
                    if "challenges" in video_info:
                        hashtags = [
                            challenge.get("title", "")
                            for challenge in video_info.get("challenges", [])
                        ]

                    # Alternative: Extract hashtags from video object if available
                    if hasattr(video, 'hashtags') and video.hashtags:
                        hashtags = [hashtag.name for hashtag in video.hashtags if hasattr(hashtag, 'name')]

                    # Get top comments
                    comments = []
                    if fetch_comments:
                        logger.info("Fetching comments for enhanced location extraction...")
                        comments = await self._get_top_comments(video, count=15)
                    else:
                        logger.info("Skipping comments - trying description/hashtags only")

                    logger.info("Successfully fetched TikTok data")
                    return {
                        "id": video_info.get("id"),
                        "desc": video_info.get("desc", ""),
                        "hashtags": hashtags,
                        "comments": comments,
                    }

            except Exception as e:
                error_msg = str(e)
                logger.error(f"Attempt {attempt + 1}/{max_retries} failed: {error_msg}")

                # Check if it's a timeout error
                is_timeout = "Timeout" in error_msg or "timeout" in error_msg.lower()

                # If this is the last attempt, raise the error
                if attempt == max_retries - 1:
                    if is_timeout:
                        raise Exception(f"Failed to fetch TikTok video data after {max_retries} attempts: Request timed out. This may be due to network issues or TikTok blocking the server's IP address.")
                    else:
                        raise Exception(f"Failed to fetch TikTok video data after {max_retries} attempts: {error_msg}")

                # Calculate exponential backoff delay
                delay = base_delay * (2 ** attempt)
                logger.info(f"Retrying in {delay} seconds...")
                await asyncio.sleep(delay)

    async def _get_top_comments(self, video, count: int = 15) -> List[Dict]:
        comments = []
        try:
            comment_count = 0
            async for comment in video.comments(count=count):
                if comment_count >= count:
                    break
                    
                comments.append({
                    "text": comment.text,
                    "author": comment.author.username if hasattr(comment.author, 'username') else "unknown",
                    "likes": comment.likes_count,
                })
                comment_count += 1
                
        except Exception as e:
            logger.warning(f"Error fetching comments: {e}")
            # Return empty list if comments fail - not critical for location extraction
            
        return comments

    def _extract_location_with_llm(self, video_data: Dict) -> Optional[str]:
        """
        Use OpenAI to extract location information from comprehensive video data
        including description, hashtags, and comments
        """
        try:
            video_desc = video_data.get("desc", "")
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