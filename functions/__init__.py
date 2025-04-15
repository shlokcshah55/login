# Update tiktok_retrieval.py to make it easier to import
"""
Export the new improved get_cleaned_video_info function for use by other modules.
The original get_video_info function remains for backward compatibility.
"""
from api.tiktok_retrieval import get_cleaned_video_info

# Keep existing functions for backward compatibility
async def get_video_info(url: str):
    """Legacy function, retained for backward compatibility."""
    video_info = await get_cleaned_video_info(url)
    return video_info