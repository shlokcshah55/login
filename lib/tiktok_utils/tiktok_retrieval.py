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

ms_token = os.environ.get(
    "ms_token", None
)  # set your own ms_token, go to tiktok.com and inspect and then go to cookies within the application tab


async def get_video_info(url: str):
    async with TikTokApi() as api:
        await api.create_sessions(ms_tokens=[ms_token], num_sessions=1, sleep_after=3)
        video = api.video(
            url=url
        )

        video_info = await video.info()
        keys = ["id", "locationCreated", "contentLocation", "poi", "diversificationLabels"]
        res = {key: video_info[key] for key in keys if key in video_info}
        res["description"] = video_info["desc"]

        print("========== video info =========")
        for key, value in video_info.items():
            print(f"{key}: {value}")

        print("========== res dictionary =========")
        for key, value in res.items():
            print(f"{key}: {value}")

        # video_bytes = await video.bytes()
        # with open("video.mp4", "wb") as f:
        #     f.write(video_bytes)

        return res

if __name__ == "__main__":
    asyncio.run(get_video_info("https://www.tiktok.com/@findfluffs/video/7269735509210041632?is_from_webapp=1&sender_device=pc&web_id=7410112369073325600"))