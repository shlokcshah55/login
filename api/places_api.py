"""
Google Places API integration for retrieving detailed location information.
This module handles interactions with the Google Places API to get comprehensive
location details based on place names and locations.
"""
import os
import logging
import json
import requests
from typing import Dict, Any, Optional, List
from dotenv import load_dotenv

load_dotenv()

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class PlacesAPI:
    """
    Google Places API client for retrieving detailed location information.
    """
    
    def __init__(self, api_key=None):
        """
        Initialize the Places API client with the API key.
        
        Args:
            api_key: Google Places API key (optional, will use environment variable if not provided)
        """
        self.api_key = api_key or os.environ.get("GOOGLE_PLACE_API_KEY")
        if not self.api_key:
            logger.warning("No Google Places API key found")
            
        self.base_url = "https://maps.googleapis.com/maps/api/place"
    
    def search_place(self, query: str) -> Optional[Dict[str, Any]]:
        """
        Search for a place using the Places API Find Place endpoint.
        
        Args:
            query: The search query (e.g., "Eiffel Tower, Paris")
            
        Returns:
            Dictionary with place information or None if not found
        """
        if not self.api_key:
            logger.error("Cannot search place: No Google Places API key available")
            return None
            
        try:
            # First use Find Place to get the place ID
            find_url = f"{self.base_url}/findplacefromtext/json"
            params = {
                "input": query,
                "inputtype": "textquery",
                "fields": "place_id,name,formatted_address",
                "key": self.api_key
            }
            
            logger.info(f"Searching for place: {query}")
            response = requests.get(find_url, params=params)
            response.raise_for_status()
            
            data = response.json()
            
            if data.get("status") != "OK" or not data.get("candidates"):
                logger.warning(f"No places found for query: {query}")
                return None
                
            # Get the first candidate (most relevant)
            place_id = data["candidates"][0]["place_id"]
            
            # Now get detailed place information
            return self.get_place_details(place_id)
            
        except requests.exceptions.RequestException as e:
            logger.error(f"Request error searching for place {query}: {e}")
            return None
        except Exception as e:
            logger.error(f"Error searching for place {query}: {e}")
            return None
    
    def get_place_details(self, place_id: str) -> Optional[Dict[str, Any]]:
        """
        Get detailed information about a place using its Place ID.
        
        Args:
            place_id: The Google Place ID
            
        Returns:
            Dictionary with detailed place information or None if not found
        """
        if not self.api_key:
            logger.error("Cannot get place details: No Google Places API key available")
            return None
            
        try:
            details_url = f"{self.base_url}/details/json"
            params = {
                "place_id": place_id,
                "fields": "place_id,name,formatted_address,geometry,photos,url,website,formatted_phone_number,opening_hours,rating,user_ratings_total,types,price_level,vicinity,international_phone_number,editorial_summary",
                "key": self.api_key
            }
            
            logger.info(f"Getting details for place ID: {place_id}")
            response = requests.get(details_url, params=params)
            response.raise_for_status()
            
            data = response.json()
            
            if data.get("status") != "OK":
                logger.warning(f"Failed to get details for place ID {place_id}: {data.get('status')}")
                return None
                
            place_details = data["result"]
            
            # Extract relevant data and format it for storage
            formatted_details = {
                "place_id": place_id,
                "name": place_details.get("name"),
                "address": place_details.get("formatted_address"),
                "phone": place_details.get("formatted_phone_number"),
                "international_phone": place_details.get("international_phone_number"),
                "website": place_details.get("website"),
                "google_maps_url": place_details.get("url"),
                "rating": place_details.get("rating"),
                "user_ratings_total": place_details.get("user_ratings_total"),
                "types": place_details.get("types"),
                "price_level": place_details.get("price_level"),
                "vicinity": place_details.get("vicinity"),
                "coordinates": {
                    "lat": place_details.get("geometry", {}).get("location", {}).get("lat"),
                    "lng": place_details.get("geometry", {}).get("location", {}).get("lng")
                },
                "opening_hours": place_details.get("opening_hours"),
                "editorial_summary": place_details.get("editorial_summary", {}).get("overview")
            }
            
            # Handle photos
            if "photos" in place_details and place_details["photos"]:
                photo_references = []
                for photo in place_details["photos"][:5]:  # Limit to 5 photos
                    if "photo_reference" in photo:
                        photo_references.append({
                            "reference": photo["photo_reference"],
                            "width": photo.get("width"),
                            "height": photo.get("height"),
                            "html_attributions": photo.get("html_attributions", [])
                        })
                
                formatted_details["photos"] = photo_references
            
            return formatted_details
            
        except requests.exceptions.RequestException as e:
            logger.error(f"Request error getting details for place ID {place_id}: {e}")
            return None
        except Exception as e:
            logger.error(f"Error getting details for place ID {place_id}: {e}")
            return None
    
    def get_photo_url(self, photo_reference: str, max_width: int = 800) -> Optional[str]:
        """
        Get the URL for a place photo.
        
        Args:
            photo_reference: The photo reference from the Place Details
            max_width: Maximum width of the photo
            
        Returns:
            URL to the photo or None if error
        """
        if not self.api_key or not photo_reference:
            return None
            
        try:
            photo_url = f"{self.base_url}/photo"
            params = {
                "photoreference": photo_reference,
                "maxwidth": max_width,
                "key": self.api_key
            }
            
            return f"{photo_url}?{requests.compat.urlencode(params)}"
            
        except Exception as e:
            logger.error(f"Error generating photo URL: {e}")
            return None

# Create a singleton instance for reuse
_places_api = None

def get_places_api() -> Optional[PlacesAPI]:
    """
    Get or create the Places API client instance.
    
    Returns:
        PlacesAPI instance or None if initialization failed
    """
    global _places_api
    
    if _places_api is None:
        try:
            _places_api = PlacesAPI()
        except Exception as e:
            logger.error(f"Failed to create Places API client: {e}")
            return None
    
    return _places_api

# Test function when module is run directly
if __name__ == "__main__":
    places_api = get_places_api()
    
    if not places_api:
        print("Places API client initialization failed")
        exit(1)
    
    test_queries = [
        "Eiffel Tower, Paris",
        "Statue of Liberty, New York",
        "Taj Mahal, India"
    ]
    
    for query in test_queries:
        print(f"\nSearching for: {query}")
        place_info = places_api.search_place(query)
        
        if place_info:
            print(f"Found place: {place_info['name']}")
            print(f"Address: {place_info['address']}")
            print(f"Place ID: {place_info['place_id']}")
            
            if place_info.get('photos'):
                print(f"First photo URL: {places_api.get_photo_url(place_info['photos'][0]['reference'])}")
        else:
            print(f"No information found for {query}")