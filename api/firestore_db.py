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