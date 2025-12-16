"""
AI Tag Matcher for Locations
Efficiently matches locations to relevant tags using OpenAI with in-memory caching
"""
import os
import sys
import json
import logging
from typing import List, Dict, Optional
from datetime import datetime
from dotenv import load_dotenv
from supabase import create_client, Client
from openai import OpenAI

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class TagMatcher:
    """
    Fast tag matcher using in-memory cache and OpenAI for intelligent matching
    """

    def __init__(self, location_ids):
        """Initialize the tag matcher with Supabase and OpenAI clients"""
        # Validate environment variables
        self.supabase_url = os.getenv('SUPABASE_URL')
        self.supabase_key = os.getenv('SUPABASE_KEY')
        self.openai_api_key = os.getenv('OPENAI_API_KEY')
        self.tags = self.load_tags()


        # Initialize clients
        self.supabase: Client = create_client(self.supabase_url, self.supabase_key)
        self.openai = OpenAI(api_key=self.openai_api_key)


        self.locations = [self.get_location(loc_id) for loc_id in location_ids]
        

    def load_tags(self) -> List[Dict]:
        try:
            logger.info("Loading tags from Supabase...")
            response = self.supabase.table('tags').select(
                'tag_id, text, prompt_description, tag_type'
            ).execute()

            self.tags_cache = response.data
            self.cache_timestamp = datetime.now()

            logger.info(f"Loaded {len(self.tags_cache)} tags from database")
            return self.tags_cache

        except Exception as e:
            logger.error(f"Error loading tags: {e}")
            raise

    def get_location(self, location_id: int) -> Dict:
        """
        Fetch location details from Supabase
        """
        try:
            response = self.supabase.table('locations').select('*').eq(
                'location_id', location_id
            ).single().execute()

            if not response.data:
                raise ValueError(f"Location with ID {location_id} not found")

            return response.data

        except Exception as e:
            logger.error(f"Error fetching location {location_id}: {e}")
            raise

    def create_matching_prompt(self, location: Dict, tags: List[Dict]) -> str:
        """
        Create an optimized prompt for AI tag matching
        """
        # Build location description
        location_parts = []
        if location.get('name'):
            location_parts.append(f"Name: {location['name']}")
        if location.get('vicinity'):
            location_parts.append(f"Location: {location['vicinity']}")
        if location.get('cuisine'):
            location_parts.append(f"Cuisine: {location['cuisine']}")
        if location.get('rating'):
            location_parts.append(f"Rating: {location['rating']}/5")
        if location.get('price_level'):
            price_symbols = '$' * location['price_level']
            location_parts.append(f"Price Level: {price_symbols}")

        location_desc = "\n".join(location_parts)

        # Build tags list with descriptions
        tags_list = []
        for tag in tags:
            tag_entry = f"- {tag['text']}"
            if tag.get('prompt_description'):
                tag_entry += f": {tag['prompt_description']}"
            tags_list.append(tag_entry)

        tags_desc = "\n".join(tags_list)

        prompt = f"""You are a location categorization expert. Analyze the following location and determine which tags are most relevant.

LOCATION DETAILS:
{location_desc}

AVAILABLE TAGS:
{tags_desc}

TASK: Return a JSON array of tag IDs (UUID strings) that best match this location. Only include tags that are highly relevant. Order them by relevance (most relevant first).

IMPORTANT:
- Only return tag IDs that are actually relevant to this specific location
- Consider the tag descriptions carefully
- Return maximum 5 of the most relevant tags
- Response must be valid JSON: ["tag-id-1", "tag-id-2", ...]

Response:"""

        return prompt

    def save_location_tags(self, location_id: int, tag_ids: List[str], score: float = 1.0):
        """
        Save matched tags to the location_tags table

        Args:
            location_id: The location ID
            tag_ids: List of tag IDs to associate
            score: Relevance score (default 1.0)
        """
        try:
            # First, delete existing tags for this location to avoid duplicates
            self.supabase.table('location_tags').delete().eq(
                'location_id', location_id
            ).execute()

            # Prepare batch insert
            inserts = [
                {
                    'location_id': location_id,
                    'tag_id': tag_id,
                    'score': score
                }
                for tag_id in tag_ids
            ]

            if not inserts:
                logger.warning(f"No tags to save for location {location_id}")
                return

            # Batch insert all tags
            response = self.supabase.table('location_tags').insert(inserts).execute()
            logger.info(f"Saved {len(inserts)} tags for location {location_id}")

        except Exception as e:
            logger.error(f"Error saving tags for location {location_id}: {e}")
            raise

    def process_location(self, location: Dict) -> Dict:
        try:
    
            # Create prompt
            prompt = self.create_matching_prompt(location, self.tags)

            # Call OpenAI API
            logger.info("Calling OpenAI API...")
            response = self.openai.chat.completions.create(
                model="gpt-4o-mini",  # Fast and cost-effective
                messages=[
                    {"role": "system", "content": "You are a precise location categorization system that returns only valid JSON arrays."},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.3,  # Lower temperature for more consistent results
                max_tokens=500
            )

            # Parse response
            content = response.choices[0].message.content.strip()
            logger.info(f"AI Response: {content}")

            # Extract JSON from response (handle markdown code blocks)
            if content.startswith("```"):
                # Remove markdown code block formatting
                content = content.split("```")[1]
                if content.startswith("json"):
                    content = content[4:]
                content = content.strip()

            matched_tag_ids = json.loads(content)

            if not isinstance(matched_tag_ids, list):
                raise ValueError("AI response is not a list")

            logger.info(f"Matched {len(matched_tag_ids)} tags")

            location_id = location['location_id']   
            # Save to database
            self.save_location_tags(location_id, matched_tag_ids)


            result = {
                'success': True,
                'location_id': location_id,
                'matched_tags': len(matched_tag_ids),
                'tag_ids': matched_tag_ids,
            }

            return result

        except Exception as e:
            logger.error(f"Failed to process location {location_id}: {e}")
            return {
                'success': False,
                'location_id': location_id,
                'error': str(e)
            }

    def run_for_supabase(self):
        results = []
        while len(self.locations) > 0:
            result = self.process_location(self.locations.pop())
            results.append(result)
        return results
 

    def run_for_placesAPI(self, location:Dict):
        # Create prompt
        prompt = self.create_matching_prompt(location, self.tags)

        # Call OpenAI API
        logger.info("Calling OpenAI API...")
        response = self.openai.chat.completions.create(
            model="gpt-4o-mini",  # Fast and cost-effective
            messages=[
                {"role": "system", "content": "You are a precise location categorization system that returns only valid JSON arrays."},
                {"role": "user", "content": prompt}
            ],
            temperature=0.3,  # Lower temperature for more consistent results
            max_tokens=500
        )

        # Parse response
        content = response.choices[0].message.content.strip()
        logger.info(f"AI Response: {content}")

        # Extract JSON from response (handle markdown code blocks)
        if content.startswith("```"):
            # Remove markdown code block formatting
            content = content.split("```")[1]
            if content.startswith("json"):
                content = content[4:]
            content = content.strip()

        matched_tag_ids = json.loads(content)
        return matched_tag_ids

    def add_location(self, location:Dict):
        self.locations.append(location)
def main():
    # Parse location IDs from arguments
    try:
        location_ids = [int(arg) for arg in sys.argv[1:]]
    except ValueError:
        print("Error: All arguments must be valid location IDs (integers)")
        sys.exit(1)

    try:
        # Initialize matcher
        matcher = TagMatcher()

        # Process location(s)
        if len(location_ids) == 1:
            result = matcher.process_location(location_ids[0])
            print("\n" + "="*50)
            print("RESULT:")
            print(json.dumps(result, indent=2))
        else:
            results = matcher.process_batch(location_ids)
            print("\n" + "="*50)
            print("RESULTS:")
            print(json.dumps(results, indent=2))

    except Exception as e:
        logger.error(f"Fatal error: {e}", exc_info=True)
        sys.exit(1)


if __name__ == '__main__':
    main()
