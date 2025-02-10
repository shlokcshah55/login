import os
import json
import google.generativeai as genai
from dotenv import load_dotenv

load_dotenv()

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
    if not gemini_api_key:
        genai.configure(api_key=os.environ["GEMINI_API_KEY"])
    else: 
        genai.configure(api_key=gemini_api_key)
    
    generation_config = {
        "temperature": 1,
        "top_p": 0.95,
        "top_k": 40,
        "max_output_tokens": 8192,
        "response_mime_type": "text/plain",
    }
    
    model = genai.GenerativeModel(
        model_name="gemini-2.0-flash-exp",
        generation_config=generation_config,
    )
    
    # Updated prompt to instruct multiple location extraction and JSON output.
    chat_session = model.start_chat(
        history=[
            {
                "role": "user",
                "parts": [
                    (
                        "Given a dictionary of metadata regarding a TikTok, "
                        "identify the name of the landmark or restaurant being addressed. "
                        "Do not pick up on generic shop names"
                        "{\n"
                        '  "locations": [\n'
                        '      {"landmark": "<landmark name or \'Not Found\'>", "location": "<location or \'Not Found\'>"},\n'
                        "      ...\n"
                        "  ]\n"
                        "}\n\n"
                        "If no valid landmarks or locations are found, return {\"locations\": []}."
                    ),
                ],
            },
            {
                "role": "model",
                "parts": [
                    (
                        '{\n'
                        '  "locations": []\n'
                        '}'
                    ),
                ],
            },
        ]
    )
    
    return chat_session

def find_locations(chat_session, metadata):
    """
    Extracts multiple landmark and location information from TikTok metadata using the AI chat model.
    
    :param chat_session: chat session object
    :param metadata: dictionary or JSON string containing TikTok metadata
    :return: list of dictionaries with keys "landmark" and "location"
    """
    # Convert metadata to JSON string if it is a dictionary.
    if isinstance(metadata, dict):
        metadata_str = json.dumps(metadata)
    else:
        metadata_str = metadata
    
    response = chat_session.send_message(metadata_str)
    return _extract_locations(response.text.strip()[7:-3])  # format the response 

def _extract_locations(response_text):
    """
    Parses the model's response text (expected to be in JSON format) and returns a list of location objects.
    
    :param response_text: The text returned by the model.
    :return: A list of dictionaries, each with "landmark" and "location" keys.
    """
    try:
        result = json.loads(response_text)
        if "locations" in result and isinstance(result["locations"], list):
            return result["locations"]
        else:
            return []
    except json.JSONDecodeError:
        # If JSON parsing fails, attempt a fallback parsing strategy.
        locations = []
        lines = response_text.split("\n")
        current = {}
        for line in lines:
            if line.startswith("Landmark"):
                current["landmark"] = line.split(":", 1)[1].strip()
            elif line.startswith("Location:"):
                current["location"] = line.split(":", 1)[1].strip()
                if current:
                    locations.append(current)
                    current = {}
        return locations

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
    
    locations1 = find_locations(session, TEST_INPUT)
    print("Test Input 1 Locations:")
    print(json.dumps(locations1, indent=2))
    
    locations2 = find_locations(session, TEST_INPUT2)
    print("Test Input 2 Locations:")
    print(json.dumps(locations2, indent=2))
