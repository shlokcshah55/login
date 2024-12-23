import os
import google.generativeai as genai

def start_gpt_session():
    '''
    creates a new chat session with configured Gemini AI model to extract location information from TikTok metadata
    :return: chat session object
    '''

    genai.configure(api_key=os.environ["GEMINI_API_KEY"])  
    # Define the model configuration
    generation_config = {
        "temperature": 1,
        "top_p": 0.95,
        "top_k": 40,
        "max_output_tokens": 8192,
        "response_mime_type": "text/plain",
    }

    # Create the Generative Model
    model = genai.GenerativeModel(
        model_name="gemini-2.0-flash-exp",
        generation_config=generation_config,
    )

    # Start the chat session with improved prompts
    chat_session = model.start_chat(
        history=[
            {
                "role": "user",
                "parts": [
                    (
                        "Given a dictionary of metadata regarding a TikTok, "
                        "identify the name of the landmark or restaurant being addressed. "
                        "If no valid landmark or location information is present, respond with "
                        "'No identifiable landmark or location found.' "
                        "Produce the output in the format: \n"
                        "Landmark/Restaurant Name: <name or 'Not Found'>\n"
                        "Location: <location or 'Not Found'>"
                    ),
                ],
            },
            {
                "role": "model",
                "parts": [
                    (
                        "Landmark/Restaurant Name: Not Found\n"
                        "Location: Not Found\n"
                    ),
                ],
            },
        ]
    )

    return chat_session

def find_location(chat_session, metadata):
    '''
    extracts landmark and location information from TikTok metadata using AI chat model
    :param chat_session: chat session object
    :param metadata: dictionary containing TikTok metadata
    :return: tuple containing landmark and location information
    '''
    response = chat_session.send_message(metadata)
    return _extract_landmark_and_location(response.text)

def _extract_landmark_and_location(response_text):
    lines = response_text.split("\n")
    landmark = "Not Found"
    location = "Not Found"
    
    for line in lines:
        if line.startswith("Landmark/Restaurant Name:"):
            landmark = line.split(":", 1)[1].strip()
        elif line.startswith("Location:"):
            location = line.split(":", 1)[1].strip()
    
    return landmark, location

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
    "description": "If you're in Brighton, you need to try this place called Cutie Pies you can find them on instagram @cutiepiesandfries #brightoneats #pizzainbrighton #brightonfood #detroitpizza #ugcfoodcontent "
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
    "description": "A weekend in Littlehampton #visittheuk #weekendtrips #staycation #ukstays #seasidetrips #aestheticvideos "
    }
    """
    
    session = start_gpt_session()
    response = find_location(session, TEST_INPUT)
    print(response)

    response = find_location(session, TEST_INPUT2)
    print(response)    