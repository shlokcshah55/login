'''
File usage:
- This file is used to retrieve and clean TikTok video metadata based on a url.

Setting up TikTokApi:

    Installing Dependencies:
    pip install TikTokApi cleantext python-dotenv
    python -m playwright install

    If this runs into an error, you may need to downgrade your playwright dependencies:
    pip install playwright==1.37.0
    playwright install
'''

from TikTokApi import TikTokApi
import asyncio
import os
import json
import logging
from typing import Dict, Any, Optional, Union, List
from cleantext import clean
# from gpt_utils import start_gpt_session, find_locations # Keep commented unless used directly here
from dotenv import load_dotenv

load_dotenv()

# Setup logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# --- Helper Function ---

def _clean_value(value: Any) -> Any:
    """Recursively cleans strings within a nested structure (dict or list)."""
    if isinstance(value, dict):
        return {k: _clean_value(v) for k, v in value.items()}
    elif isinstance(value, list):
        return [_clean_value(item) for item in value]
    elif isinstance(value, str):
        try:
            # Added basic error handling for clean() just in case
            return clean(value, no_emoji=True)
        except Exception as e:
            logging.warning(f"Could not clean text: {value}. Error: {e}")
            return value # Return original string if cleaning fails
    else:
        return value

# --- Core Function ---

async def get_cleaned_video_info(url: str) -> Optional[Dict[str, Any]]:
    '''
    Retrieves and cleans relevant video information from a TikTok video URL.

    :param url: The TikTok video URL.
    :return: Dictionary containing cleaned video information or None if an error occurs.
    '''
    logging.info(f"Attempting to retrieve video info for URL: {url}")
    try:
        # Read ms_tokens from environment variables, or use fallback if not available
        ms_tokens = os.environ.get("MS_TOKENS", "").split(",") if os.environ.get("MS_TOKENS") else []
        
        logging.info(f"Using {len(ms_tokens)} ms_tokens for TikTok API")

        async with TikTokApi() as api:
            # Create sessions with the ms_tokens
            await api.create_sessions(ms_tokens=ms_tokens, num_sessions=1, sleep_after=3, headless=True)
            video = api.video(url=url)
            video_info = await video.info()

            # Define keys to extract
            keys_to_extract = [
                "id",                   # Video ID
                "desc",                 # Video Description/Caption
                "locationCreated",      # Specific location tag (often granular)
                "contentLocation",      # Broader content location (less common)
                "poi",                  # Point of Interest information (if tagged)
                "diversificationLabels" # Algorithmic labels (might hint at location type)
            ]

            # Extract data safely, defaulting to None if key doesn't exist
            extracted_data = {key: video_info.get(key) for key in keys_to_extract}

            # Rename 'desc' to 'description' for consistency if preferred
            if 'desc' in extracted_data:
                extracted_data['description'] = extracted_data.pop('desc')
            else:
                 extracted_data['description'] = None # Ensure key exists

            logging.info(f"Successfully retrieved raw data for {url}")
            # logging.debug(f"Raw data: {json.dumps(extracted_data, indent=2)}") # Optional: Log raw data if needed

            # Clean the extracted data
            cleaned_data = _clean_value(extracted_data)
            logging.info(f"Successfully cleaned data for {url}")
            # logging.debug(f"Cleaned data: {json.dumps(cleaned_data, indent=2)}") # Optional: Log cleaned data

            return cleaned_data

    except KeyError as e:
        logging.error(f"Missing expected key in video info for URL {url}: {e}")
        return None
    except Exception as e:
        # Catch any other unexpected errors
        logging.error(f"An unexpected error occurred for URL {url}: {e}", exc_info=True) # Log traceback
        return None


# --- Test Block (Commented out for server use) ---
if __name__ == "__main__":
    EXAMPLE_TIKTOK = "https://www.tiktok.com/@findfluffs/video/7269735509210041632?is_from_webapp=1&sender_device=pc&web_id=7410112369073325600"
    # EXAMPLE_TIKTOK2 = "https://www.tiktok.com/@findfluffs/video/7346303859205147937?is_from_webapp=1&web_id=7410112369073325600"
    # NO_LOCATION = "https://vm.tiktok.com/ZGdhGqvYC/"
    # MORE_OBSCURE_TIKTOK = "https://vm.tiktok.com/ZGdhGUgHJ/"
    # MIGHT_WORK = "https://vm.tiktok.com/ZGdhGtNaa/"

    async def run_test():
        logging.info("--- Running Test ---")
        metadata = await get_cleaned_video_info(EXAMPLE_TIKTOK)

        if metadata:
            print("\n--- Cleaned Metadata ---")
            print(json.dumps(metadata, indent=2))

            # Example of how you might use GPT utils (if needed here)
            # try:
            #     from gpt_utils import start_gpt_session, find_locations
            #     session = start_gpt_session()
            #     print("\n--- GPT Location Finding ---")
            #     # Pass the cleaned metadata string or relevant parts
            #     locations = find_locations(session, json.dumps(metadata))
            #     print(locations)
            # except ImportError:
            #     logging.warning("gpt_utils not found, skipping GPT location finding test.")
            # except Exception as e:
            #     logging.error(f"Error during GPT processing: {e}")
        else:
            print("\nFailed to retrieve or process video metadata.")
        logging.info("--- Test Complete ---")

    asyncio.run(run_test())
