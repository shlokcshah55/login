"""
AI Collections Generator
Generates themed collections from a user's saved locations using xAI (Grok)
"""
import asyncio
import os
import json
import logging
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Optional, Set
from dotenv import load_dotenv
from supabase import create_client, Client
from openai import AsyncOpenAI

load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

COLLECTION_METADATA = {
    "date_night":        "Date Night 🌹",
    "brunch":            "Brunch O'Clock 🍳",
    "on_the_run":        "On The Run 🏃",
    "midnight_munchies": "Midnight Munchies 🌙",
    "grab_a_coffee":     "Grab A Coffee ☕",
    "drinks_up":         "Drinks Up 🍻",
    "outside_outside":   "Outside Outside ☀️",
}


class CollectionGenerator:
    """
    Generates themed collections from a user's saved locations using xAI Grok.
    """

    def __init__(self, user_id: str):
        self.supabase_url = os.getenv('SUPABASE_URL')
        self.supabase_key = os.getenv('SUPABASE_SERVICE_KEY')
        self.xai_api_key = os.getenv('XAI_API_KEY')
        self.user_id = user_id

        self.supabase: Client = create_client(self.supabase_url, self.supabase_key)
        self.client = AsyncOpenAI(
            api_key=self.xai_api_key,
            base_url="https://api.x.ai/v1"
        )
        self.model = "grok-4-fast-non-reasoning"

    def get_generated_collections_timestamp(self) -> Optional[str]:
        """
        Returns the generated_collections timestamp for the user, or None if never generated.
        """
        response = self.supabase.table('users') \
            .select('generated_collections') \
            .eq('supabase_id', self.user_id) \
            .single() \
            .execute()

        return response.data.get('generated_collections') if response.data else None

    def fetch_saved_locations(self, since: Optional[str] = None) -> List[Dict]:
        """
        Fetch saved location details for the user.
        If since is provided, only returns locations saved after that timestamp.
        """
        logger.info(f"Fetching saved locations for user {self.user_id}" +
                    (f" since {since}" if since else " (all time)"))

        query = self.supabase.table('user_location_actions') \
            .select('location_id') \
            .eq('user_id', self.user_id) \
            .in_('action', ['save', 'bubble_save'])

        if since:
            query = query.gt('created_at', since)
        
        

        actions_response = query.execute()
        logger.info(f"Fetched {(actions_response.data or [])} location actions")

        if not actions_response.data:
            raise ValueError('Not enough saved locations to generate collections (minimum 2 required)')

        location_ids = [row['location_id'] for row in actions_response.data]

        if len(location_ids) < 2:
            raise ValueError('Not enough saved locations to generate collections (minimum 2 required)')

        logger.info(f"Found {len(location_ids)} saved location IDs, fetching details...")

        locations_response = self.supabase.table('locations') \
            .select('*') \
            .in_('location_id', location_ids) \
            .execute()

        locations = locations_response.data or []
        logger.info(f"Fetched details for {len(locations)} locations")
        return locations

    def get_existing_collections(self) -> Dict[str, str]:
        """
        Returns a mapping of collection label → collection_id for the user's existing collections.
        """
        response = self.supabase.rpc('get_user_collections', {
            'p_user_id': self.user_id
        }).execute()

        return {row['name']: row['collection_id'] for row in (response.data or [])}

    def build_system_prompt_for_location(self, location: Dict) -> str:
        """
        Load prompt.txt and inject a single location's data as JSON.
        """
        prompt_path = Path(__file__).parent / 'prompt.txt'
        template = prompt_path.read_text()
        location_json = json.dumps(location, indent=2, default=str)
        print('LOCATION JSON FOR PROMPT:')
        print(location_json)
        return template.replace('{{RESTAURANT_JSON}}', location_json)

    async def call_grok_for_location(
        self,
        location: Dict,
        semaphore: asyncio.Semaphore
    ) -> List[str]:
        """
        Call Grok for a single location. Returns list of collection IDs it fits.
        """
        async with semaphore:
            system_prompt = self.build_system_prompt_for_location(location)
            print
            response = await self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {
                        "role": "user",
                        "content": (
                            "Which of the defined collections above does this restaurant belong to? "
                            "Evaluate it against all 7 collections using the STRONG FIT criteria. "
                            "Return only a valid JSON array of collection ID strings. "
                            'Example: ["date_night", "grab_a_coffee"]. '
                            "Return [] if it fits none. No markdown, no explanation."
                        )
                    }
                ],
                temperature=0.3,
                max_tokens=100
            )
            content = response.choices[0].message.content.strip()
            logger.info(f"Grok response for location {location.get('location_id')}: {content}")

            # Strip markdown fences if present
            if content.startswith("```"):
                content = content.split("```")[1]
                if content.startswith("json"):
                    content = content[4:]
                content = content.strip()

            result = json.loads(content)
            if not isinstance(result, list):
                return []
            # Filter to known collection IDs only
            return [cid for cid in result if cid in COLLECTION_METADATA]

    def _aggregate_results(
        self,
        locations: List[Dict],
        per_location_results: List,
        valid_ids: Set[int]
    ) -> Dict[str, List[int]]:
        """Aggregate per-location Grok results into {collection_id: [location_ids]}."""
        aggregated: Dict[str, List[int]] = {}
        for location, result in zip(locations, per_location_results):
            if isinstance(result, Exception):
                logger.warning(f"Grok call failed for location {location['location_id']}: {result}")
                continue
            loc_id = location['location_id']
            if loc_id not in valid_ids:
                continue
            for cid in result:
                aggregated.setdefault(cid, []).append(loc_id)
        logger.info(f"Aggregated into {len(aggregated)} collections before filtering")
        return aggregated

    def create_new_collections(self, aggregated: Dict[str, List[int]]) -> List[Dict]:
        """
        Create fresh collections for each entry with 2+ locations.
        Used on first generation (generated_collections IS NULL).
        """
        results = []

        for collection_id, location_ids in aggregated.items():
            if len(location_ids) < 2:
                logger.info(f"Collection '{collection_id}' has only {len(location_ids)} location(s), skipping")
                continue

            label = COLLECTION_METADATA[collection_id]
            logger.info(f"Creating collection '{label}' with {len(location_ids)} locations")

            try:
                response = self.supabase.rpc('create_collection_with_locations', {
                    'p_user_id': self.user_id,
                    'p_name': label,
                    'p_location_ids': location_ids,
                    'p_description': None,
                    'p_emoji': None,
                    'p_cover_color': None,
                    'p_is_public': True
                }).execute()

                rpc_result = response.data
                if isinstance(rpc_result, dict) and rpc_result.get('success'):
                    results.append({
                        'name': label,
                        'collection_id': rpc_result.get('collection_id'),
                        'location_count': rpc_result.get('location_count', len(location_ids))
                    })
                    logger.info(f"Created collection '{label}' successfully")
                else:
                    error = rpc_result.get('error') if isinstance(rpc_result, dict) else str(rpc_result)
                    logger.error(f"RPC failed for collection '{label}': {error}")

            except Exception as e:
                logger.error(f"Failed to create collection '{label}': {e}")

        return results

    def add_to_existing_collections(
        self,
        aggregated: Dict[str, List[int]],
        existing: Dict[str, str]
    ) -> List[Dict]:
        """
        Add new locations to existing collections, or create a new collection if one
        doesn't exist yet for that label. No 2+ minimum — new locations are added as found.
        Used on re-generation (generated_collections IS NOT NULL).
        """
        results = []

        for collection_id, location_ids in aggregated.items():
            label = COLLECTION_METADATA[collection_id]

            if label in existing:
                # Add each new location to the existing collection
                coll_uuid = existing[label]
                added = 0
                for loc_id in location_ids:
                    try:
                        response = self.supabase.rpc('add_location_to_collection', {
                            'p_collection_id': coll_uuid,
                            'p_location_id': loc_id
                        }).execute()
                        rpc_result = response.data
                        if isinstance(rpc_result, dict) and rpc_result.get('success'):
                            added += 1
                        else:
                            error = rpc_result.get('error') if isinstance(rpc_result, dict) else str(rpc_result)
                            logger.warning(f"add_location_to_collection failed for '{label}' loc {loc_id}: {error}")
                    except Exception as e:
                        logger.error(f"Failed to add location {loc_id} to '{label}': {e}")

                if added:
                    logger.info(f"Added {added} locations to existing collection '{label}'")
                    results.append({
                        'name': label,
                        'collection_id': coll_uuid,
                        'location_count': added
                    })
            else:
                # Collection doesn't exist yet — create it
                logger.info(f"Collection '{label}' not found, creating with {len(location_ids)} locations")
                try:
                    response = self.supabase.rpc('create_collection_with_locations', {
                        'p_user_id': self.user_id,
                        'p_name': label,
                        'p_location_ids': location_ids,
                        'p_description': None,
                        'p_emoji': None,
                        'p_cover_color': None,
                        'p_is_public': True
                    }).execute()

                    rpc_result = response.data
                    if isinstance(rpc_result, dict) and rpc_result.get('success'):
                        results.append({
                            'name': label,
                            'collection_id': rpc_result.get('collection_id'),
                            'location_count': rpc_result.get('location_count', len(location_ids))
                        })
                        logger.info(f"Created new collection '{label}' successfully")
                    else:
                        error = rpc_result.get('error') if isinstance(rpc_result, dict) else str(rpc_result)
                        logger.error(f"RPC failed creating new collection '{label}': {error}")
                except Exception as e:
                    logger.error(f"Failed to create collection '{label}': {e}")

        return results

    def mark_generated_collections(self) -> None:
        """Update the generated_collections timestamp on the user record to now."""
        now = datetime.now(timezone.utc).isoformat()
        self.supabase.table('users') \
            .update({'generated_collections': now}) \
            .eq('supabase_id', self.user_id) \
            .execute()
        logger.info(f"Updated generated_collections timestamp to {now}")

    def build_auto_update_prompt(self, locations: List[Dict]) -> str:
        """
        Prompt used for the auto-update flow (re-generating / refreshing collections).
        TODO: fill in the prompt once the copy is ready.
        """
        restaurants_json = json.dumps(locations, indent=2, default=str)
        template = ""  # TODO: add prompt here
        return template.replace('{{RESTAURANTS_JSON}}', restaurants_json)

    async def run(self) -> Dict:
        """
        Orchestrates the full generation pipeline.

        First run (generated_collections IS NULL):
          - Processes all saved locations, creates new collections.

        Re-run (generated_collections IS NOT NULL):
          - Processes only locations saved since last run, adds to existing collections.
        """
        last_generated = self.get_generated_collections_timestamp()
        is_first_run = last_generated is None

        locations = self.fetch_saved_locations(since=last_generated if not is_first_run else None)
        valid_ids: Set[int] = {loc['location_id'] for loc in locations}

        logger.info(f"Firing {len(locations)} parallel Grok calls (semaphore=10)...")
        semaphore = asyncio.Semaphore(10)
        tasks = [self.call_grok_for_location(loc, semaphore) for loc in locations]
        per_location_results = await asyncio.gather(*tasks, return_exceptions=True)

        aggregated = self._aggregate_results(locations, per_location_results, valid_ids)

        if is_first_run:
            created = self.create_new_collections(aggregated)
        else:
            existing = self.get_existing_collections()
            created = self.add_to_existing_collections(aggregated, existing)

        self.mark_generated_collections()

        return {
            'success': True,
            'collections_created': len(created),
            'collections': created
        }

    def run_auto_update(self) -> Dict:
        """
        Orchestrates the auto-update pipeline using the auto-update prompt.
        TODO: implement once auto-update prompt is ready.
        """
        return {
            'success': True,
            'collections_created': 0,
            'collections': []
        }
