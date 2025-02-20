'''
File usage:
- This file is used to retrieve TikTok videos based on a url.

Setting up TikTokApi:

    Installing Dependencies:
    pip install TikTokApi
    python -m playwright install

    If this runs into an error, you may need to downgrade your playwright dependencies:
    pip install playwright==1.37.0
    playwright install
'''

from TikTokApi import TikTokApi
import asyncio
import os
import json
from cleantext import clean
from gpt_utils import start_gpt_session, find_locations
from dotenv import load_dotenv

load_dotenv()

async def get_video_info(url: str):
    '''
    This function retrieves the video information from a TikTok video URL.
    :param url:
    :return: dictionary containing video information necessary for location extraction
    '''
    def _clean_dict(d):
        if isinstance(d, dict):
            return {k: _clean_dict(v) for k, v in d.items()}
        elif isinstance(d, list):
            return [_clean_dict(item) for item in d]
        elif isinstance(d, str):
            return clean(d, no_emoji=True)
        else:
            return d

    async with TikTokApi() as api:
        await api.create_sessions(ms_tokens=[], num_sessions=1, sleep_after=3)
        video = api.video(
            url=url
        )

        video_info = await video.info()
        keys = ["id", "locationCreated", "contentLocation", "poi", "diversificationLabels"]
        res = {key: video_info[key] for key in keys if key in video_info}
        res["description"] = video_info["desc"]

        # print("========== video info =========")
        # for key, value in video_info.items():
        #     print(f"{key}: {value}")


        # video_bytes = await video.bytes()
        # with open("video.mp4", "wb") as f:
        #     f.write(video_bytes)

        return json.dumps(_clean_dict(res), indent=2)


if __name__ == "__main__":
    EXAMPLE_TIKTOK = "https://www.tiktok.com/@findfluffs/video/7269735509210041632?is_from_webapp=1&sender_device=pc&web_id=7410112369073325600"
    # EXAMPLE_TIKTOK2 = "https://www.tiktok.com/@findfluffs/video/7346303859205147937?is_from_webapp=1&web_id=7410112369073325600"
    # NO_LOCATION = "https://vm.tiktok.com/ZGdhGqvYC/"
    # MORE_OBSCURE_TIKTOK = "https://vm.tiktok.com/ZGdhGUgHJ/"  # worked perfectly
    # MIGHT_WORK = "https://vm.tiktok.com/ZGdhGtNaa/"  # didn't work 

    cutie_pies_metadata = asyncio.run(get_video_info(EXAMPLE_TIKTOK))
    # city_metadata = asyncio.run(get_video_info(EXAMPLE_TIKTOK2))
    # no_location_metadata = asyncio.run(get_video_info(NO_LOCATION))
    # more_obscure = asyncio.run(get_video_info(MORE_OBSCURE_TIKTOK))
    # might_work = asyncio.run(get_video_info(MIGHT_WORK))
    
    print(cutie_pies_metadata)  
    # print(more_obscure) 
    # print(might_work)
    # print(city_metadata)
    # print(no_location_metadata)

    session = start_gpt_session()
    print(find_locations(session, cutie_pies_metadata))
    # print(find_location(session, city_metadata))
    # print(find_location(session, no_location_metadata))
    # print(find_location(session, more_obscure))
    # print(find_location(session, might_work))


