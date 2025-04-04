import os
import google.generativeai as genai
import googlemaps
import json
from dotenv import load_dotenv
from geopy.geocoders import Nominatim

# load_dotenv()

class LocationFinder:
    def __init__(self, gemini_key=None, gmaps_key=None):    
        # Get API Keys from environment variables or firestore secrets
        # gemini_key = os.getenv('GEMINI_API_KEY')  # for TESTING
        # gmaps_key = os.getenv('GOOGLE_PLACE_API_KEY')  # For TESTING

        # Initialize APIs
        genai.configure(api_key=gemini_key)
        self.gemini = genai.GenerativeModel('gemini-2.0-flash-lite')
        self.gmaps = googlemaps.Client(key=gmaps_key)
        self.geolocator = Nominatim(user_agent="location_finder")
        self.DEFAULT_LOCATION = (51.5074, -0.1278)  # Default to London for demo

        # Predefined mapping of common terms to Place types
        self.type_mapping = {
            'sightseeing': 'tourist_attraction',
            'museum': 'museum',
            'hotel': 'lodging',
            'park': 'park',
            'restaurant': 'restaurant',
            'cafe': 'cafe',
            'bar': 'bar',
        }

        self.allowed_types = [
            "accounting",
            "airport",
            "amusement_park",
            "aquarium",
            "art_gallery",
            "atm",
            "bakery",
            "bank",
            "bar",
            "beauty_salon",
            "bicycle_store",
            "book_store",
            "bowling_alley",
            "bus_station",
            "cafe",
            "campground",
            "car_dealer",
            "car_rental",
            "car_repair",
            "car_wash",
            "casino",
            "cemetery",
            "church",
            "city_hall",
            "clothing_store",
            "convenience_store",
            "courthouse",
            "dentist",
            "department_store",
            "doctor",
            "drugstore",
            "electrician",
            "electronics_store",
            "embassy",
            "fire_station",
            "florist",
            "funeral_home",
            "furniture_store",
            "gas_station",
            "gym",
            "hair_care",
            "hardware_store",
            "hindu_temple",
            "home_goods_store",
            "hospital",
            "insurance_agency",
            "jewelry_store",
            "laundry",
            "lawyer",
            "library",
            "light_rail_station",
            "liquor_store",
            "local_government_office",
            "locksmith",
            "lodging",
            "meal_delivery",
            "meal_takeaway",
            "mosque",
            "movie_rental",
            "movie_theater",
            "moving_company",
            "museum",
            "night_club",
            "painter",
            "park",
            "parking",
            "pet_store",
            "pharmacy",
            "physiotherapist",
            "plumber",
            "police",
            "post_office",
            "primary_school",
            "real_estate_agency",
            "restaurant",
            "roofing_contractor",
            "rv_park",
            "school",
            "secondary_school",
            "shoe_store",
            "shopping_mall",
            "spa",
            "stadium",
            "storage",
            "store",
            "subway_station",
            "supermarket",
            "synagogue",
            "taxi_stand",
            "tourist_attraction",
            "train_station",
            "transit_station",
            "travel_agency",
            "university",
            "veterinary_care",
            "zoo"
        ]

    def parse_query(self, query: str) -> dict:
        """Use Gemini to extract search parameters from natural language"""
        prompt = f"""
        Analyze this location search query and extract key parameters in JSON format, be sure to fix any typos in the query:
        {query}

        Return JSON with these possible fields:
        - activity_type: string (e.g., restaurant, tourist_attraction)
        - location: string (geographic area or "current_location")
        - keywords: array of strings
        - radius: number (in meters)
        - price_range: array of numbers (1-4)
        - open_now: boolean
        """

        response = self.gemini.generate_content(prompt)
        return self._safe_parse_json(response.text)

    def get_coordinates(self, location_name: str):
        """Convert location name to coordinates"""
        if location_name == "current_location":
            return self.DEFAULT_LOCATION  # Default to London for demo
        try:
            location = self.geolocator.geocode(location_name)
        except: 
            print("Failed to get location - defaulting to current location")
            return self.DEFAULT_LOCATION
        return (location.latitude, location.longitude) if location else None

    def search_places(self, query: str) -> list:
        """Main function to process query and return results"""
        # Parse query with Gemini
        tries = 3
        params = self.parse_query(query)
        while not params and tries > 0:
            try:
                print(f"Failed to parse query, retrying...")
                params = self.parse_query(query)
                tries -= 1
            except Exception as e:
                print(f"Error: {e}") 
            
        print(f"parsed_query: {params}")
        lat, lng = self.get_coordinates(params.get('location', 'current_location'))
        
        # Map to Google Places parameters
        places_params = {
            'location': f"{lat},{lng}",
            'radius': params.get('radius', 4000),
            'type': params.get('activity_type', '') if params.get('activity_type', '') in self.allowed_types 
                else self._map_place_type(params.get('activity_type', '')),
            'keyword': ' '.join(params.get('keywords', [])),
            'open_now': params.get('open_now', True),
        }
        print(places_params)
        results = self.gmaps.places_nearby(**places_params)  # google places API call
        return results

    def _map_place_type(self, activity: str) -> str:
        """Map natural language terms to Places API types"""
        return self.type_mapping.get(activity.lower(), '')

    def _format_results(self, results: list) -> list:
        """Format API response into usable structure"""
        return [{
            'name': place['name'],
            'address': place['vicinity'],
            'rating': place.get('rating', 'N/A'),
            'price_level': place.get('price_level', 'N/A'),
            'types': place['types'],
            'location': place['geometry']['location']
        } for place in results]

    def _safe_parse_json(self, text: str) -> dict:
        """Handle Gemini's JSON response safely"""
        try:
            res = json.loads(text.strip('` \n').replace('json', ''))
            return {k: v for k, v in res.items() if v is not None}
        except json.JSONDecodeError:
            return {}
    

# if __name__ == "__main__":
#     finder = LocationFinder()
#     results = finder.search_places("Find a vegetarian restaurant in copenhagen")
#     # results = finder.search_places("Find a museum near me")
#     # results = finder.search_places("Find a park near me")
#     print(results)