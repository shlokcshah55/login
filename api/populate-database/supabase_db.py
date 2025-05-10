"""
Database operations for the TikTok processing API using Supabase.
This module handles all interactions with the Supabase database.
"""
import os
import uuid
import logging
import json
from typing import Dict, Any, Optional, List
from datetime import datetime
from dotenv import load_dotenv

# Import Supabase client
from supabase import create_client, Client

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Column name constants matching the Flutter constants
class SupabaseColumns:
    # Table names (matching constants.dart)
    TABLE_LOCATIONS = 'locations'
    TABLE_VIDEOS = 'videos'
    TABLE_USER_LOCATION_ACTIONS = 'user_location_actions'
    TABLE_LOCATION_POPULARITY_APP = 'location_popularity_app'
    TABLE_INCOMING_TIKTOK_LINKS = 'incoming_tiktok_links'
    
    # Column names - locations
    LOCATION_ID = 'location_id'
    NAME = 'name'
    VICINITY = 'vicinity'
    LAT = 'lat'
    LNG = 'lng'
    CREATED_AT = 'created_at'
    GOOGLE_PLACE_ID = 'google_place_id'
  
    PHONE_NUMBER = 'phone_number'
    CUISINE = 'cuisine'
    RATING = 'rating'
    USER_RATINGS_TOTAL = 'user_ratings_total'
    PRICE_LEVEL = 'price_level'
    PHOTO_REFERENCE = 'photo_reference'
    
    # Column names - videos
    VIDEO_ID = 'video_id'
    USER_ID = 'user_id'
    PLATFORM = 'platform'
    URL = 'url'
    EXTRACTED_LOCATION_ID = 'extracted_location_id'
    POSTED_AT = 'posted_at'
    METADATA = 'metadata'
    
    # Column names - user_location_actions
    ACTION_ID = 'action_id'
    ACTION = 'action'
    SOURCE_VIDEO_ID = 'source_video_id'
    SAVED_METHOD = 'saved_method'
    
    # Column names - location_popularity_app
    SAVES_COUNT = 'saves_count'
    LIKES_COUNT = 'likes_count'
    UPDATED_AT = 'updated_at'
    # Action types
    ACTION_SAVE = 'save'
    ACTION_LIKE = 'like'
    ACTION_SHARE = 'shared_video'
    
    # Saved method types
    SAVED_METHOD_TIKTOK = 'tiktok'
    SAVED_METHOD_IN_APP = 'in-app'

class SupabaseClient:
    """Supabase database client for TikTok processing operations."""
    
    def __init__(self):
        """Initialize the Supabase client."""
        try:
            # Get credentials from environment variables
            supabase_url = os.environ.get("SUPABASE_URL")
            supabase_key = os.environ.get("SUPABASE_ANON_KEY")
            
            if not supabase_url or not supabase_key:
                raise ValueError("Supabase URL or key not found in environment variables")
            
            # Initialize Supabase client
            self.client = create_client(supabase_url, supabase_key)
            logger.info("Supabase client initialized successfully")
        except Exception as e:
            logger.error(f"Failed to initialize Supabase client: {e}")
            self.client = None
            raise
    
    def is_connected(self) -> bool:
        """Check if the Supabase client is properly connected."""
        return self.client is not None
    

    # --- Location-related methods ---
    def store_location(self, place_data: Dict[str, Any], tiktok_id: Optional[str] = None, user_id: Optional[str] = None) -> Optional[int]:
        """
        Store or update location data in the locations table.
        
        Args:
            place_data: The location data from Google Places API
            tiktok_id: Optional TikTok video ID to associate with this location
            user_id: Optional user ID to update saved_posts for
            
        Returns:
            The location ID or None if operation failed
        """
        try:
            if not self.is_connected():
                logger.error("Cannot store location: Supabase client not initialized")
                return None
                
            google_place_id = place_data.get("place_id")

            current_timestamp = datetime.utcnow().isoformat()
            
            # First try to look up the location by name and vicinity (as place_id might not be available)
            location_name = place_data.get(SupabaseColumns.NAME)
            location_vicinity = place_data.get(SupabaseColumns.VICINITY)
            
            existing_location = None
            logger.info(f"mummmt google_place_id: {google_place_id}")
            
            if google_place_id:
                # Try to find by place_id first
                existing_location = self.get_location_by_place_id(google_place_id)
            
            if not existing_location and location_name and location_vicinity:
                # Try to find by name and vicinity
                logger.info(f"trying somet  google_place_id: {google_place_id}")

                result = self.client.table(SupabaseColumns.TABLE_LOCATIONS).select("*").eq(SupabaseColumns.NAME, location_name).eq(SupabaseColumns.VICINITY, location_vicinity).limit(1).execute()
                
                if hasattr(result, 'data') and result.data:
                    existing_location = result.data[0]
            
            if existing_location:
                logger.info(f"Updating existing location: {existing_location}")
                # Update existing location
                location_id = existing_location.get(SupabaseColumns.LOCATION_ID)
                
                # Prepare update data
                update_data = {
                    
                }
                
                # Update location data
                for key, value in place_data.items():
                    if key not in [SupabaseColumns.LOCATION_ID, SupabaseColumns.CREATED_AT] and value is not None:
                        update_data[key] = value
                
                # Update the location
                result = self.client.table(SupabaseColumns.TABLE_LOCATIONS).update(update_data).eq(SupabaseColumns.LOCATION_ID, location_id).execute()
                
                # If tiktok_id is provided and user_id is provided, create a user_location_action
                if tiktok_id and user_id:
                    self.add_location_to_user_saved_posts(user_id, location_id, tiktok_id)

                self.increment_location_popularity(location_id, SupabaseColumns.ACTION_SAVE)
                
                return location_id
                
            else:
                logger.info('got here ')
                # Create new location
                # Prepare location data
                location_id = self.getNextLocationId()

                new_data = {
                    SupabaseColumns.LOCATION_ID: location_id,
                    SupabaseColumns.GOOGLE_PLACE_ID: google_place_id,
                    SupabaseColumns.NAME: place_data.get(SupabaseColumns.NAME, "Unknown"),
                    SupabaseColumns.VICINITY: place_data.get(SupabaseColumns.VICINITY, "Unknown"),
                    SupabaseColumns.LAT: place_data.get(SupabaseColumns.LAT, 0),
                    SupabaseColumns.LNG: place_data.get(SupabaseColumns.LNG, 0),
                    SupabaseColumns.CREATED_AT: current_timestamp,
                }
                
                # Add optional fields
                new_data[SupabaseColumns.LOCATION_ID] = location_id
                
                for key, value in place_data.items():
                    if key not in [SupabaseColumns.NAME, SupabaseColumns.VICINITY, SupabaseColumns.LAT, 
                                   SupabaseColumns.LNG, SupabaseColumns.CREATED_AT,
                                   SupabaseColumns.LOCATION_ID] and value is not None:
                        new_data[key] = value
                
                # Create the location
                result = self.client.table(SupabaseColumns.TABLE_LOCATIONS).insert(new_data).execute()
                
                if not (hasattr(result, 'data') and result.data):
                    logger.error(f"Failed to create location")
                    return None
                
                location_id = result.data[0].get(SupabaseColumns.LOCATION_ID)
                
                # Initialize location popularity
                self._initialize_location_popularity(location_id)
                
                # If tiktok_id is provided and user_id is provided, create a user_location_action
                if tiktok_id and user_id:
                    self.add_location_to_user_saved_posts(user_id, location_id, tiktok_id)
                
                return location_id
                
        except Exception as e:
            logger.error(f"Error storing location data: {e}")
            return None
    
    def store_video(self, url):
        """
        Store a TikTok video URL in the database.
        
        Args:
            url: The TikTok video URL
            
        Returns:
            The video ID or None if operation failed
        """
        try:
            if not self.is_connected():
                logger.error("Cannot store video: Supabase client not initialized")
                return None
                
            # Prepare video data
            video_data = {
                SupabaseColumns.VIDEO_ID: self.getNextVideoId(),
                SupabaseColumns.URL: url,
                SupabaseColumns.CREATED_AT: datetime.utcnow().isoformat(),
                SupabaseColumns.PLATFORM: "tiktok",

            }
            
            # Insert the video
            result = self.client.table(SupabaseColumns.TABLE_VIDEOS).insert(video_data).execute()
            
            if hasattr(result, 'data') and result.data:
                return result.data[0].get(SupabaseColumns.VIDEO_ID)
            
            return None
            
        except Exception as e:
            logger.error(f"Error storing video data: {e}")
            return None
    
    def getNextVideoId(self) -> int:
        """
        Get the highest video_id from the videos table.
        
        Returns:
            The highest video_id, or 0 if no videos exist
        """
        try:
            if not self.is_connected():
                logger.error("Cannot get latest video ID: Supabase client not initialized")
                return 1
                
            # Query the videos table to get the max video_id
            result = self.client.table(SupabaseColumns.TABLE_VIDEOS).select(SupabaseColumns.VIDEO_ID).order(SupabaseColumns.VIDEO_ID, desc=True).limit(1).execute()
            
            if hasattr(result, 'data') and result.data:
                return result.data[0].get(SupabaseColumns.VIDEO_ID, 0) + 1
            
            return 1
            
        except Exception as e:
            logger.error(f"Error getting latest video ID: {e}")
            return 0
   
    def getNextLocationId(self) -> int:
        """
        Get the highest location_id from the locations table.
        
        Returns:
            The highest location_id, or 0 if no locations exist
        """
        try:
            if not self.is_connected():
                logger.error("Cannot get latest location ID: Supabase client not initialized")
                return 1
            
            # Query the locations table to get the max location_id
            result = self.client.table(SupabaseColumns.TABLE_LOCATIONS).select(SupabaseColumns.LOCATION_ID).order(SupabaseColumns.LOCATION_ID, desc=True).limit(1).execute()
            
            if hasattr(result, 'data') and result.data:
                return result.data[0].get(SupabaseColumns.LOCATION_ID, 0) + 1
            
            return 1
            
        except Exception as e:
            logger.error(f"Error getting latest location ID: {e}")
            return 1
   
    def get_location_by_place_id(self, place_id: str) -> Optional[Dict[str, Any]]:
        """
        Retrieve a location document by its Google Place ID.
        
        Args:
            place_id: The Google Place ID
            
        Returns:
            The location document data or None if not found
        """
        try:
            if not self.is_connected():
                logger.error("Cannot get location: Supabase client not initialized")
                return None
                
            # Query the locations table by place_id
            result = self.client.table(SupabaseColumns.TABLE_LOCATIONS).select("*").eq(SupabaseColumns.GOOGLE_PLACE_ID, place_id).limit(1).execute()
            
            if hasattr(result, 'data') and result.data:
                return result.data[0]
            
            return None
            
        except Exception as e:
            logger.error(f"Error retrieving location with place_id {place_id}: {e}")
            return None
    
    def _initialize_location_popularity(self, location_id: int) -> bool:
        """Initialize popularity metrics for a location."""
        try:
            if not self.is_connected():
                logger.error("Cannot initialize location popularity: Supabase client not initialized")
                return False
            
            # Create entry in location_popularity_app table
            new_data = {
                SupabaseColumns.LOCATION_ID: location_id,
                SupabaseColumns.SAVES_COUNT: 1,
                SupabaseColumns.LIKES_COUNT: 0,
                SupabaseColumns.UPDATED_AT: datetime.utcnow().isoformat()
            }
            
            result = self.client.table(SupabaseColumns.TABLE_LOCATION_POPULARITY_APP).insert(new_data).execute()
            
            return hasattr(result, 'data') and result.data
            
        except Exception as e:
            logger.error(f"Error initializing location popularity for {location_id}: {e}")
            return False
    
    def add_location_to_user_saved_posts(self, user_id: str, location_id: int, tiktok_id: str) -> bool:
        """
        Add a location to a user's saved posts by creating a user_location_action record.
        
        Args:
            user_id: The user's ID
            location_id: The location's ID
            tiktok_id: The TikTok video ID
            
        Returns:
            True if successful, False otherwise
        """
        try:
            
            if not self.is_connected():
                logger.error("Cannot update user: Supabase client not initialized")
                return False
            
            # Create a user_location_action record
            action_data = {
                SupabaseColumns.ACTION_ID: self.get_next_user_location_action_id(),
                SupabaseColumns.USER_ID: user_id,
                SupabaseColumns.LOCATION_ID: location_id,
                SupabaseColumns.ACTION: SupabaseColumns.ACTION_SAVE,
                SupabaseColumns.SOURCE_VIDEO_ID: tiktok_id,
                SupabaseColumns.SAVED_METHOD: SupabaseColumns.SAVED_METHOD_TIKTOK,
                SupabaseColumns.CREATED_AT: datetime.utcnow().isoformat()
            }
            
            # Insert the action
            result = self.client.table(SupabaseColumns.TABLE_USER_LOCATION_ACTIONS).insert(action_data).execute()
            
            if hasattr(result, 'data') and result.data:
                logger.info(f"Added location {location_id} to user {user_id}'s saved posts")
                
                # Increment location popularity
                self.increment_location_popularity(location_id, SupabaseColumns.ACTION_SAVE)
                
                return True
            else:
                logger.error(f"Failed to create user_location_action for user {user_id}, location {location_id}")
                return False
            
        except Exception as e:
            logger.error(f"Error adding location to user's saved posts: {e}")
            return False
    
    def get_next_user_location_action_id(self) -> int:
        """
        Get the next available action ID for user_location_actions.
        
        Returns:
            The next action ID or 0 if not found
        """
        try:
            if not self.is_connected():
                logger.error("Cannot get next action ID: Supabase client not initialized")
                return 0
            
            # Query the user_location_actions table to get the max action_id
            result = self.client.table(SupabaseColumns.TABLE_USER_LOCATION_ACTIONS).select(SupabaseColumns.ACTION_ID).order(SupabaseColumns.ACTION_ID, desc=True).limit(1).execute()
            
            if hasattr(result, 'data') and result.data:
                return result.data[0].get(SupabaseColumns.ACTION_ID, 0) + 1
            
            return 0
            
        except Exception as e:
            logger.error(f"Error getting next action ID: {e}")
            return 0
        
    def increment_location_popularity(self, location_id: int, action_type: str) -> bool:
        """
        Increment the popularity counter for a location.
        
        Args:
            location_id: The location ID
            action_type: The type of action ('save' or 'like')
            
        Returns:
            True if successful, False otherwise
        """
        try:
            if not self.is_connected():
                logger.error("Cannot update location popularity: Supabase client not initialized")
                return False
            
            # Check if the location exists in location_popularity_app
            result = self.client.table(SupabaseColumns.TABLE_LOCATION_POPULARITY_APP).select("*").eq(SupabaseColumns.LOCATION_ID, location_id).execute()
            
            current_timestamp = datetime.utcnow().isoformat()
            
            if hasattr(result, 'data') and result.data:
                # Update existing record
                column_name = SupabaseColumns.SAVES_COUNT if action_type == SupabaseColumns.ACTION_SAVE else SupabaseColumns.LIKES_COUNT
                current_count = result.data[0].get(column_name, 0)
                
                update_data = {
                    column_name: current_count + 1,
                    SupabaseColumns.UPDATED_AT: current_timestamp
                }
                
                update_result = self.client.table(SupabaseColumns.TABLE_LOCATION_POPULARITY_APP).update(update_data).eq(SupabaseColumns.LOCATION_ID, location_id).execute()
                
                return hasattr(update_result, 'data') and update_result.data
                
            else:
                # Create new record
                new_data = {
                    SupabaseColumns.LOCATION_ID: location_id,
                    SupabaseColumns.SAVES_COUNT: 1 if action_type == SupabaseColumns.ACTION_SAVE else 0,
                    SupabaseColumns.LIKES_COUNT: 1 if action_type == SupabaseColumns.ACTION_LIKE else 0,
                    SupabaseColumns.UPDATED_AT: current_timestamp
                }
                
                insert_result = self.client.table(SupabaseColumns.TABLE_LOCATION_POPULARITY_APP).insert(new_data).execute()
                
                return hasattr(insert_result, 'data') and insert_result.data
            
        except Exception as e:
            logger.error(f"Error incrementing location popularity for {location_id}: {e}")
            return False
    
    def retrieve_users(self) -> List[Dict[str, Any]]:
        """
        Retrieve all users from the users table.

        Returns:
            List of user documents
        """
        try:
            if not self.is_connected():
                logger.error("Cannot retrieve users: Supabase client not initialized")
                return []
            
            result = self.client.table('users').select("*").execute()
            
            if hasattr(result, 'data'):
                logger.info(f"Retrieved {len(result.data)} users")
                return result.data
            else:
                logger.error("No data returned from user query")
                return []
            
        except Exception as e:
            logger.error(f"Error retrieving users: {e}")
            return []

# Create a singleton instance
_supabase_client = None

def get_supabase_client() -> Optional[SupabaseClient]:
    """
    Get or create the Supabase client instance.

    Returns:
        SupabaseClient instance or None if initialization failed
    """
    global _supabase_client

    if _supabase_client is None:
        try:
            _supabase_client = SupabaseClient()
        except Exception as e:
            logger.error(f"Failed to create Supabase client: {e}")
            return None

    return _supabase_client

def getLatestPlaceId() -> int:
    """
    Get the highest location_id from the locations table.

    Returns:
        The highest location_id, or 0 if no locations exist
    """
    client = get_supabase_client()
    if client:
        return client.getLatestPlaceId()
    return 0