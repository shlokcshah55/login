"""
Firebase Cloud Function to trigger TikTok processing when new links are added to Firestore.
This function is triggered on document creation in the 'incoming_tiktok_links' collection
and calls the Cloud Run API to process the TikTok link.
"""
from firebase_functions import firestore_fn, https_fn
from firebase_admin import initialize_app, firestore
import requests
import os
import logging
import json

# Initialize Firebase
initialize_app()

# Setup logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# Environment configuration
# This URL should be set to your deployed Cloud Run service URL in production
TIKTOK_PROCESSOR_API_URL = os.environ.get('TIKTOK_PROCESSOR_API_URL', 'http://localhost:8080')

@firestore_fn.on_document_created(
    document="incoming_tiktok_links/{docId}", 
    region="europe-west2"
)
def trigger_tiktok_processing(event: firestore_fn.Event) -> None:
    """
    Firebase Cloud Function triggered when a new document is created in the 
    'incoming_tiktok_links' collection.
    
    The function extracts the TikTok URL and document ID, then sends these to 
    the Cloud Run API for processing.
    """
    try:
        # Get document data
        doc_snapshot = event.data
        doc_id = doc_snapshot.id
        doc_data = doc_snapshot.to_dict()
        
        logging.info(f"Processing triggered for document: {doc_id}")
        
        # Extract TikTok URL
        tiktok_url = doc_data.get('tiktokUrl')
        if not tiktok_url:
            logging.error(f"Document {doc_id} does not contain a tiktokUrl field")
            # Update document with error status
            doc_snapshot.reference.update({
                'status': 'failed',
                'error': 'Missing tiktokUrl field',
                'processedAt': firestore.SERVER_TIMESTAMP
            })
            return
        
        # Extract user ID if present
        user_id = doc_data.get('userId')
        
        # Update status to 'processing'
        doc_snapshot.reference.update({
            'status': 'processing',
            'processingStartedAt': firestore.SERVER_TIMESTAMP
        })
        
        # Send request to Cloud Run API
        api_url = f"{TIKTOK_PROCESSOR_API_URL}/process-tiktok"
        
        logging.info(f"Sending request to {api_url} for document {doc_id}")
        
        # Prepare request data
        request_data = {
            'url': tiktok_url,
            'documentId': doc_id
        }
        
        # Add user ID if available
        if user_id:
            request_data['userId'] = user_id
        
        # Make the API request
        response = requests.post(
            api_url,
            json=request_data,
            headers={'Content-Type': 'application/json'}
        )
        
        # Check if request was successful
        if response.status_code >= 200 and response.status_code < 300:
            logging.info(f"Successfully triggered processing for document {doc_id}")
            # The Cloud Run API will update the document status when processing is complete
        else:
            # Log error and update document status
            error_msg = f"API request failed with status {response.status_code}: {response.text}"
            logging.error(error_msg)
            
            doc_snapshot.reference.update({
                'status': 'failed',
                'error': f"API request failed with status {response.status_code}",
                'processedAt': firestore.SERVER_TIMESTAMP
            })
            
    except Exception as e:
        logging.exception(f"Error in trigger_tiktok_processing: {e}")
        
        # Try to update document with error status
        try:
            event.data.reference.update({
                'status': 'failed',
                'error': str(e),
                'processedAt': firestore.SERVER_TIMESTAMP
            })
        except Exception as update_error:
            logging.error(f"Failed to update document with error: {update_error}")