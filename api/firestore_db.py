"""
Database operations for the TikTok processing API using Google Cloud Firestore.
This module handles all interactions with the Firestore database.
"""
import os
import logging
from typing import Dict, Any, Optional, List
from datetime import datetime
from dotenv import load_dotenv

# Import the Google Cloud Firestore client library
from google.cloud import firestore
from google.cloud.firestore_v1.base_query import FieldFilter

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(level=logging.DEBUG)
logging.getLogger("google.cloud.firestore").setLevel(logging.DEBUG)
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class FirestoreClient:
    """Firestore database client for TikTok processing operations."""
    
    def __init__(self):
        """Initialize the Firestore client."""
        try:
            # Check if we should use the emulator
            if os.environ.get("USE_FIREBASE_EMULATOR", "false").lower() == "true":
                logger.info("Using Firestore emulator")
                # The FIRESTORE_EMULATOR_HOST environment variable will be used automatically
            os.environ.pop("FIRESTORE_EMULATOR_HOST", None)
            # Initialize Firestore client
            self.db = firestore.Client()
            logger.info("Firestore client initialized successfully")
        except Exception as e:
            logger.error(f"Failed to initialize Firestore client: {e}")
            self.db = None
            raise
    
    def is_connected(self) -> bool:
        """Check if the Firestore client is properly connected."""
        return self.db is not None
    
    def update_tiktok_status(self, doc_id: str, status: str, 
                             error: Optional[str] = None,
                             additional_data: Optional[Dict[str, Any]] = None) -> bool:
        """
        Update the status of a TikTok link document.
        
        Args:
            doc_id: The document ID to update
            status: The new status ('processing', 'completed', 'failed')
            error: Optional error message if status is 'failed'
            additional_data: Optional additional data to update
            
        Returns:
            bool: True if update was successful, False otherwise
        """
        try:
            if not self.is_connected():
                logger.error("Cannot update document: Firestore client not initialized")
                return False
                
            # Get a reference to the document
            doc_ref = self.db.collection("incoming_tiktok_links").document(doc_id)
            
            # Prepare the update data
            update_data = {
                "status": status,
                "processedAt": firestore.SERVER_TIMESTAMP
            }
            
            # Add error message if provided
            if error and status == "failed":
                update_data["error"] = error
            
            # Add any additional data
            if additional_data:
                update_data.update(additional_data)
            
            # Update the document
            doc_ref.update(update_data)
            logger.info(f"Updated document {doc_id} with status: {status}")
            return True
            
        except Exception as e:
            logger.error(f"Error updating TikTok document {doc_id}: {e}")
            return False
    
    def get_pending_tiktok_links(self, limit: int = 10, user_id: Optional[str] = None) -> List[Dict[str, Any]]:
        """
        Get a list of pending TikTok links.
        
        Args:
            limit: Maximum number of documents to retrieve
            user_id: Optional user ID to filter by
            
        Returns:
            List of document data with their IDs
        """
        try:
            if not self.is_connected():
                logger.error("Cannot query documents: Firestore client not initialized")
                return []
                
            # Create a query for pending links
            query = self.db.collection("incoming_tiktok_links").where(
                filter=FieldFilter("status", "==", "pending")
            ).limit(limit)
            
            # Add user filter if provided
            if user_id:
                query = query.where(filter=FieldFilter("userId", "==", user_id))
            
            # Execute the query
            results = []
            for doc in query.stream():
                doc_data = doc.to_dict()
                doc_data["id"] = doc.id  # Add the document ID to the data
                results.append(doc_data)
            
            logger.info(f"Retrieved {len(results)} pending TikTok links")
            return results
            
        except Exception as e:
            logger.error(f"Error querying pending TikTok links: {e}")
            return []
    
    def store_processed_tiktok(self, video_info: Dict[str, Any], url: str, 
                               locations: List[Dict[str, str]], user_id: Optional[str] = None) -> Dict[str, Any]:
        """
        Store processed TikTok data in the Posts collection.
        
        Args:
            video_info: The processed TikTok video information
            url: The original TikTok URL
            locations: List of extracted locations
            user_id: Optional user ID
            
        Returns:
            Dict with status information about the operation
        """
        try:
            if not self.is_connected():
                logger.error("Cannot store data: Firestore client not initialized")
                return {
                    "error": "Database connection not available",
                    "video_info": video_info,
                    "locations": locations
                }
            
            # Extract video ID
            video_id = video_info.get("id")
            if not video_id:
                logger.warning(f"No video ID found for URL: {url}")
                return {
                    "error": "No video ID found in TikTok data",
                    "video_info": video_info,
                    "locations": locations
                }
            
            # Get reference to the Posts collection
            posts_collection = self.db.collection("Posts")
            post_doc_ref = posts_collection.document(str(video_id))
            
            # Check if the document already exists
            post_doc = post_doc_ref.get()
            
            if post_doc.exists:
                # Update existing document
                logger.info(f"Updating existing post for video ID: {video_id}")
                
                # Use a transaction to update the document
                @firestore.transactional
                def update_post(transaction, doc_ref):
                    # Get the current document
                    snapshot = doc_ref.get(transaction=transaction)
                    
                    # Update fields
                    current_save_count = snapshot.get("save_count") or 0
                    
                    # Prepare update data
                    update_data = {
                        "save_count": current_save_count + 1,
                        "last_processed_timestamp": firestore.SERVER_TIMESTAMP
                    }
                    
                    # Update the document
                    transaction.update(doc_ref, update_data)
                    return {"exists": True, "docId": doc_ref.id}
                
                # Execute the transaction
                transaction = self.db.transaction()
                result = update_post(transaction, post_doc_ref)
                
            else:
                # Create new document
                logger.info(f"Creating new post for video ID: {video_id}")
                
                # Prepare document data
                new_data = {
                    "id": video_id,
                    "url": url,
                    "locations": locations,
                    "save_count": 1,
                    "first_processed_timestamp": firestore.SERVER_TIMESTAMP,
                    "metadata": video_info
                }
                
                # Add user ID if provided
                if user_id:
                    new_data["userId"] = user_id
                
                # Create the document
                post_doc_ref.set(new_data)
                result = {"exists": False, "docId": post_doc_ref.id}
            
            return {
                "status": "success",
                "message": "TikTok data processed successfully",
                "video_id": video_id,
                "post_doc_id": post_doc_ref.id,
                "locations": locations,
                "new_post": not result.get("exists", True)
            }
            
        except Exception as e:
            logger.exception(f"Error storing processed TikTok data: {e}")
            return {
                "error": f"Error storing TikTok data: {str(e)}",
                "video_info": video_info,
                "locations": locations
            }
    
    # --- New Location-related methods ---
    
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
                logger.error("Cannot get location: Firestore client not initialized")
                return None
                
            # Query the Locations collection by place_id
            locations_ref = self.db.collection("Locations")
            query = locations_ref.where(filter=FieldFilter("place_id", "==", place_id)).limit(1)
            
            docs = list(query.stream())
            if docs:
                loc_data = docs[0].to_dict()
                loc_data["id"] = docs[0].id  # Add the Firestore document ID
                return loc_data
            
            return None
            
        except Exception as e:
            logger.error(f"Error retrieving location with place_id {place_id}: {e}")
            return None

    def store_location(self, place_data: Dict[str, Any], tiktok_id: Optional[str] = None, user_id: Optional[str] = None) -> Optional[str]:
        """
        Store or update location data in the Locations collection.
        
        Args:
            place_data: The location data from Google Places API
            tiktok_id: Optional TikTok video ID to associate with this location
            user_id: Optional user ID to update saved_posts for
            
        Returns:
            The Firestore document ID or None if operation failed
        """
        try:
            if not self.is_connected():
                logger.error("Cannot store location: Firestore client not initialized")
                return None
                
            # Check if the place_id is provided
            place_id = place_data.get("place_id")
            if not place_id:
                logger.error("Cannot store location: No place_id provided")
                return None
                
            # Add timestamp fields
            place_data["updated_at"] = firestore.SERVER_TIMESTAMP
            
            # Check if the location already exists
            existing_location = self.get_location_by_place_id(place_id)
            
            if existing_location:
                # Update existing document
                location_id = existing_location["id"]
                locations_ref = self.db.collection("Locations").document(location_id)
                
                # If tiktok_id is provided, update associated_post_ids
                if tiktok_id:
                    # Check if associated_post_ids exists
                    if "associated_post_ids" in existing_location:
                        # Only add if not already in the array
                        if tiktok_id not in existing_location["associated_post_ids"]:
                            locations_ref.update({
                                "associated_post_ids": firestore.ArrayUnion([tiktok_id])
                            })
                            logger.info(f"Added tiktok_id {tiktok_id} to location {place_id}")
                    else:
                        # Create the array with the first tiktok_id
                        locations_ref.update({
                            "associated_post_ids": [tiktok_id]
                        })
                        logger.info(f"Created associated_post_ids with tiktok_id {tiktok_id} for location {place_id}")
                
                # Update the rest of the document
                locations_ref.update(place_data)
                logger.info(f"Updated location with place_id {place_id}, doc_id: {location_id}")
                
                # If user_id is provided, update the user's saved_posts
                if user_id and tiktok_id:
                    self.add_location_to_user_saved_posts(user_id, location_id, tiktok_id)
                
                return location_id
            else:
                # Create new document with place_id as document ID
                # Add creation timestamp
                place_data["created_at"] = firestore.SERVER_TIMESTAMP
                
                # If tiktok_id is provided, add it to associated_post_ids
                if tiktok_id:
                    place_data["associated_post_ids"] = [tiktok_id]
                
                # Store in Firestore
                locations_ref = self.db.collection("Locations").document(place_id)
                locations_ref.set(place_data)
                logger.info(f"Created new location with place_id {place_id}")
                
                # If user_id is provided, update the user's saved_posts
                if user_id and tiktok_id:
                    self.add_location_to_user_saved_posts(user_id, place_id, tiktok_id)
                
                return place_id
                
        except Exception as e:
            logger.error(f"Error storing location data: {e}")
            return None
    
    def add_location_to_user_saved_posts(self, user_id: str, location_id: str, tiktok_id: str) -> bool:
        """
        Add a location to a user's saved_posts and saved_locations fields.
        
        Args:
            user_id: The user's ID
            location_id: The location's document ID
            tiktok_id: The TikTok video ID
            
        Returns:
            True if successful, False otherwise
        """
        try:
            if not self.is_connected():
                logger.error("Cannot update user: Firestore client not initialized")
                return False
            
            # Get reference to user document
            user_ref = self.db.collection("Users").document(user_id)
            
            # Check if user exists
            user_doc = user_ref.get()
            if not user_doc.exists:
                logger.warning(f"User {user_id} does not exist")
                return False
            
            # Current timestamp (will be replaced with server timestamp)
            timestamp = firestore.SERVER_TIMESTAMP
            
            # Update data for both fields
            update_data = {
                # Update the saved_posts field
                # Format: { location_id: { timestamp: server_timestamp, tiktok_id: tiktok_id } }
                f"saved_posts.{location_id}": {
                    "timestamp": timestamp,
                    "tiktok_id": tiktok_id
                },
                
                # Update the saved_locations field 
                # Format: { location_id: timestamp }
                f"saved_locations.{location_id}": timestamp
            }
            
            user_ref.update(update_data)
            logger.info(f"Added location {location_id} to user {user_id}'s saved_posts and saved_locations")
            return True
            
        except Exception as e:
            logger.error(f"Error adding location to user's saved fields: {e}")
            return False
    
    def link_post_to_location(self, post_id: str, place_id: str) -> bool:
        """
        Create or update a link between a post and a location.
        
        Args:
            post_id: The post document ID
            place_id: The location's Google Place ID
            
        Returns:
            True if successful, False otherwise
        """
        try:
            if not self.is_connected() or not post_id or not place_id:
                return False
                
            # Get the post document
            post_ref = self.db.collection("Posts").document(post_id)
            post_doc = post_ref.get()
            
            if not post_doc.exists:
                logger.warning(f"Cannot link location: Post {post_id} does not exist")
                return False
                
            # Update the post with the place_id
            update_data = {
                "place_ids": firestore.ArrayUnion([place_id]),
                "updated_at": firestore.SERVER_TIMESTAMP
            }
            
            post_ref.update(update_data)
            logger.info(f"Linked post {post_id} to location {place_id}")
            return True
            
        except Exception as e:
            logger.error(f"Error linking post {post_id} to location {place_id}: {e}")
            return False
    
    def retrieve_users(self) -> List[Dict[str, Any]]:
        """
        Retrieve all users from the Users collection.
        
        Returns:
            List of user documents
        """
        try:
            if not self.is_connected():
                logger.error("Cannot retrieve users: Firestore client not initialized")
                return []
            logger.info(f"{self.db.project} - Retrieving users from Firestore")
            users_ref = self.db.collection("Users")
            logger.info(f"Querying Users collection: {users_ref._path}")
            users = [doc.to_dict() for doc in users_ref.stream()]
            logger.info(f"Retrieved {len(users)} users")
            return users
            
        except Exception as e:
            logger.error(f"Error retrieving users: {e}")
            return []
        


# Create a singleton instance
_firestore_client = None

def get_firestore_client() -> Optional[FirestoreClient]:
    """
    Get or create the Firestore client instance.
    
    Returns:
        FirestoreClient instance or None if initialization failed
    """
    global _firestore_client
    
    if _firestore_client is None:
        try:
            _firestore_client = FirestoreClient()
        except Exception as e:
            logger.error(f"Failed to create Firestore client: {e}")
            return None
    
    return _firestore_client