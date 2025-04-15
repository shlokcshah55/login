import os
import json
import logging
import google.generativeai as genai
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def start_gpt_session(gemini_api_key=None):
    """
    Creates a new chat session with the configured Gemini AI model to extract multiple location information
    from TikTok metadata. The model is instructed to produce a JSON output.
    
    Expected output format:
    {
      "locations": [
        {"landmark": "<landmark name or 'Not Found'>", "location": "<location or 'Not Found'>"},
        ...
      ]
    }
    If no valid locations are found, the model should return:
    { "locations": [] }
    
    :return: chat session object
    """
    try:
        # Configure API key
        if not gemini_api_key:
            if "GEMINI_API_KEY" not in os.environ:
                logger.warning("No Gemini API key found in environment variables")
                return None
            genai.configure(api_key=os.environ["GEMINI_API_KEY"])
        else: 
            genai.configure(api_key=gemini_api_key)
        
        # Fixed generation config by removing the problematic "response_mime_type" field
        generation_config = {
            "temperature": 0.2,  # Lower temperature for more deterministic results
            "top_p": 0.95,
            "top_k": 40,
            "max_output_tokens": 4096  # Reduced from 8192 for efficiency
        }
        
        # Use Gemini 1.5 Pro model which has better handling of structured data
        model = genai.GenerativeModel(
            model_name="gemini-1.5-pro",  # Updated to a stable model version
            generation_config=generation_config,
        )
        
        # Improved prompt for more accurate location extraction
        prompt = """
        Given a dictionary of metadata regarding a TikTok video, extract ALL landmarks, restaurants, or notable places mentioned.
        
        Return ONLY a valid JSON object in the following exact format:
        {
          "locations": [
            {"landmark": "<name of landmark/restaurant/place>", "location": "<city, country or address>"}
          ]
        }
        
        IMPORTANT RULES:
        1. If no valid places are found, return: {"locations": []}
        2. Include ALL relevant places from both the metadata and description.
        3. Return ONLY the JSON object, no explanations or other text.
        4. For landmarks, prefer specific places over generic areas.
        5. Ignore generic shop names or common place types unless they have a specific proper name.
        """
        
        # Create chat session with history
        chat_session = model.start_chat(
            history=[
                {
                    "role": "user",
                    "parts": [prompt]
                },
                {
                    "role": "model",
                    "parts": ['{"locations": []}']
                },
            ]
        )
        
        return chat_session
        
    except Exception as e:
        logger.error(f"Error initializing Gemini session: {e}")
        return None

def find_locations(chat_session, metadata):
    """
    Extracts multiple landmark and location information from TikTok metadata using the AI chat model.
    
    :param chat_session: chat session object
    :param metadata: dictionary or JSON string containing TikTok metadata
    :return: list of dictionaries with keys "landmark" and "location"
    """
    if not chat_session:
        logger.warning("No valid chat session provided")
        return []
        
    try:
        # Convert metadata to JSON string if it is a dictionary
        if isinstance(metadata, dict):
            metadata_str = json.dumps(metadata)
        else:
            metadata_str = metadata
        
        # Send message and get response
        response = chat_session.send_message(metadata_str)
        response_text = response.text.strip()
        
        # Extract and parse the JSON response
        return _extract_locations(response_text)
        
    except Exception as e:
        logger.error(f"Error in find_locations: {e}")
        return []

def _extract_locations(response_text):
    """
    Parses the model's response text and extracts the location information.
    Improved to handle various response formats more robustly.
    
    :param response_text: The text returned by the model.
    :return: A list of dictionaries, each with "landmark" and "location" keys.
    """
    try:
        # First, try to extract JSON directly from the response
        # Look for JSON object patterns in the text
        json_start = response_text.find("{")
        json_end = response_text.rfind("}") + 1
        
        if json_start >= 0 and json_end > json_start:
            json_text = response_text[json_start:json_end]
            result = json.loads(json_text)
            
            if "locations" in result and isinstance(result["locations"], list):
                # Validate each location has the required fields
                valid_locations = []
                for loc in result["locations"]:
                    if isinstance(loc, dict) and "landmark" in loc and "location" in loc:
                        valid_locations.append({
                            "landmark": loc["landmark"].strip(),
                            "location": loc["location"].strip()
                        })
                return valid_locations
        
        # If JSON parsing failed, try alternative parsing
        logger.warning("JSON parsing failed, attempting alternative parsing")
        locations = []
        lines = response_text.split("\n")
        current = {}
        
        for line in lines:
            line = line.strip()
            if "landmark" in line.lower() and ":" in line:
                if current and "landmark" in current and "location" in current:
                    locations.append(current)
                    current = {}
                current["landmark"] = line.split(":", 1)[1].strip().strip('"\'')
            elif "location" in line.lower() and ":" in line:
                current["location"] = line.split(":", 1)[1].strip().strip('"\'')
                if "landmark" in current:  # If we have both fields, add to locations
                    locations.append(current.copy())
                    current = {}
        
        # Add the last location if it's complete
        if current and "landmark" in current and "location" in current:
            locations.append(current)
            
        return locations
        
    except json.JSONDecodeError as e:
        logger.error(f"JSON parsing error: {e}")
        return []
    except Exception as e:
        logger.error(f"Error extracting locations: {e}")
        return []

# Test function when module is run directly
if __name__ == "__main__":
    TEST_INPUT = """ 
    {
      "id": "7269735509210041632",
      "locationCreated": "GB",
      "contentLocation": {
        "address": {
          "addressCountry": "",
          "addressLocality": "",
          "addressRegion": "",
          "streetAddress": "Brighton and Hove, United Kingdom"
        }
      },
      "poi": {
        "name": "Brighton and Hove",
        "address": "United Kingdom",
        "city": "",
        "province": "",
        "country": "",
        "id": "22535796482835066",
        "fatherPoiId": "",
        "fatherPoiName": "",
        "type": 0,
        "category": "Place and Address",
        "cityCode": "85000019",
        "countryCode": "2635167",
        "ttTypeCode": "19a3a0",
        "typeCode": "",
        "ttTypeNameTiny": "City",
        "ttTypeNameMedium": "Places",
        "ttTypeNameSuper": "Place and Address"
      },
      "diversificationLabels": [
        "Food Tour & Recommendations",
        "Food & Drink",
        "Lifestyle"
      ],
      "description": "If you're in Brighton, you need to try this place called Cutie Pies. Also check out The Ice Cream Shop near the park."
    }
    """
    TEST_INPUT2 = """
    {
      "id": "7346303859205147937",
      "locationCreated": "GB",
      "contentLocation": {
        "address": {
          "addressCountry": "",
          "addressLocality": "",
          "addressRegion": "",
          "streetAddress": "Littlehampton, United Kingdom"
        }
      },
      "poi": {
        "name": "Littlehampton",
        "address": "United Kingdom",
        "city": "",
        "province": "",
        "country": "",
        "id": "22535796484930657",
        "fatherPoiId": "",
        "fatherPoiName": "",
        "type": 0,
        "category": "Place and Address",
        "cityCode": "7281601",
        "countryCode": "2635167",
        "ttTypeCode": "19a3a6",
        "typeCode": "",
        "ttTypeNameTiny": "Other Places",
        "ttTypeNameMedium": "Places",
        "ttTypeNameSuper": "Place and Address"
      },
      "diversificationLabels": [
        "Travel",
        "Travel",
        "Lifestyle"
      ],
      "description": "A weekend in Littlehampton with a visit to The Coffee Bar and a stroll at Seaside Diner."
    }
    """
    
    session = start_gpt_session()
    
    if not session:
        print("Failed to create Gemini session. Check your API key.")
        exit(1)
    
    locations1 = find_locations(session, TEST_INPUT)
    print("Test Input 1 Locations:")
    print(json.dumps(locations1, indent=2))
    
    locations2 = find_locations(session, TEST_INPUT2)
    print("Test Input 2 Locations:")
    print(json.dumps(locations2, indent=2))
