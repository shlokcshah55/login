from TikTokApi import TikTokApi
import asyncio

ms_token = "fRcI4TtrrnUMoYSBJ8RxJ6vcdLOUY-GbMgzt-2ssSUiMyyaRecW85L_cYAT8BUNP3qyoNPelz6owR3eFUSukX5VivB3gmspGawEyVlnVsqgM0HFdtlVETwS5X1gPiytv3d33hzaRJSYT"


async def user_example():
    async with TikTokApi() as api:
        await api.create_sessions(ms_tokens=[ms_token], num_sessions=1, sleep_after=3)
        user = api.user("therock")
        user_data = await user.info()
        print(user_data)

        async for video in user.videos(count=30):
            print(video)
            print(video.as_dict)

        async for playlist in user.playlists():
            print(playlist)


if __name__ == "__main__":
    asyncio.run(user_example())