"""
Test script for TikTok Processor internal functions
Tests the processor.py functions directly (not through the API)
"""
import asyncio
import json
import os
import sys
from dotenv import load_dotenv
from processor import TikTokProcessor

# Load environment variables
load_dotenv()

# Test configuration
TEST_URLS = [
    "https://vm.tiktok.com/ZNRFs8mSx/",
    "https://vm.tiktok.com/ZNRFpBHrT/",
]


def print_section(title: str):
    """Print a formatted section header"""
    print("\n" + "="*70)
    print(f"  {title}")
    print("="*70 + "\n")


async def test_get_tiktok_data(processor: TikTokProcessor, url: str):
    """
    Test the _get_tiktok_data function directly

    Args:
        processor: TikTokProcessor instance
        url: TikTok video URL to test
    """
    print_section(f"Testing _get_tiktok_data: {url}")

    try:
        print(f"📹 Fetching TikTok data from: {url}")
        print("⏳ This may take 30-60 seconds...\n")

        # Call the internal function
        video_data = await processor._get_tiktok_data(url)

        print("✅ Successfully fetched TikTok data!\n")

        # Pretty print the data
        print("Raw Video Data:")
        print(json.dumps(video_data, indent=2, ensure_ascii=False))

        # Print summary
        print("\n" + "-"*70)
        print("Summary:")
        print("-"*70)
        print(f"Video ID: {video_data.get('id')}")
        print(f"Description: {video_data.get('desc', '')[:100]}...")
        print(f"Hashtags: {video_data.get('hashtags', [])}")
        print(f"Number of comments: {len(video_data.get('comments', []))}")

        if video_data.get('comments'):
            print("\nTop 5 Comments:")
            for i, comment in enumerate(video_data.get('comments', [])[:5], 1):
                print(f"  {i}. [{comment.get('author')}] {comment.get('text', '')[:60]}...")
                print(f"     Likes: {comment.get('likes')}")

        return video_data

    except Exception as e:
        print(f"❌ Error fetching TikTok data: {e}")
        print(f"Error type: {type(e).__name__}")
        import traceback
        traceback.print_exc()
        return None


async def test_get_top_comments(processor: TikTokProcessor, url: str):
    """
    Test fetching comments for a video
    Note: This requires getting the video object first

    Args:
        processor: TikTokProcessor instance
        url: TikTok video URL to test
    """
    print_section(f"Testing _get_top_comments: {url}")

    try:
        print("Note: This test requires browser session, testing through _get_tiktok_data instead")
        # Comments are fetched as part of _get_tiktok_data
        video_data = await processor._get_tiktok_data(url)

        comments = video_data.get('comments', [])
        print(f"\n✅ Retrieved {len(comments)} comments\n")

        for i, comment in enumerate(comments, 1):
            print(f"{i}. Author: {comment.get('author')}")
            print(f"   Text: {comment.get('text')}")
            print(f"   Likes: {comment.get('likes')}")
            print()

        return comments

    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return None


def test_extract_location_with_llm(processor: TikTokProcessor, video_data: dict):
    """
    Test the LLM-based location extraction

    Args:
        processor: TikTokProcessor instance
        video_data: Video data dict (from _get_tiktok_data)
    """
    print_section("Testing _extract_location_with_llm")

    try:
        print("Video data being analyzed:")
        print(f"  Description: {video_data.get('desc', '')}")
        print(f"  Hashtags: {video_data.get('hashtags', [])}")
        print(f"  Comments: {len(video_data.get('comments', []))} comments")

        print("\n🤖 Extracting location with OpenAI...\n")

        location_queries = processor._extract_location_with_llm(video_data)

        if location_queries:
            print(f"✅ Extracted {len(location_queries)} location(s):\n")
            for i, query in enumerate(location_queries, 1):
                print(f"  {i}. {query}")
        else:
            print("❌ No locations extracted")

        return location_queries

    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return None


def test_search_google_place(processor: TikTokProcessor, query: str):
    """
    Test Google Places search

    Args:
        processor: TikTokProcessor instance
        query: Search query string
    """
    print_section(f"Testing _search_google_place: '{query}'")

    try:
        print(f"🔍 Searching Google Places for: {query}\n")

        result = processor._search_google_place(query)

        if result:
            print("✅ Found place:\n")
            print(f"  Name: {result.get('name')}")
            print(f"  Address: {result.get('formatted_address')}")
            print(f"  Place ID: {result.get('place_id')}")
            print(f"  Rating: {result.get('rating', 'N/A')}")
            print(f"  Types: {result.get('types', [])}")

            location = result.get('geometry', {}).get('location', {})
            if location:
                print(f"  Location: {location.get('lat')}, {location.get('lng')}")
        else:
            print("❌ No place found")

        return result

    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return None


async def full_pipeline_test(url: str):
    """
    Test the complete pipeline: TikTok -> LLM -> Google Places

    Args:
        url: TikTok video URL
    """
    print_section(f"Full Pipeline Test: {url}")

    # Get API key
    openai_key = os.environ.get('OPENAI_API_KEY')
    gmaps_key = os.environ.get('GOOGLE_PLACES_API_KEY')

    if not openai_key or not gmaps_key:
        print("❌ Missing API keys in environment!")
        print("Make sure OPENAI_API_KEY and GOOGLE_PLACES_API_KEY are set in .env")
        return

    # Initialize processor
    print("Initializing TikTok Processor...")
    processor = TikTokProcessor(
        openaiKey=openai_key,
        gmaps_key=gmaps_key
    )

    # Step 1: Get TikTok data
    print("\n📹 Step 1: Fetching TikTok video data...")
    video_data = await test_get_tiktok_data(processor, url)

    if not video_data:
        print("\n❌ Failed to fetch TikTok data. Stopping test.")
        return

    # Step 2: Extract location with LLM
    print("\n🤖 Step 2: Extracting location with OpenAI...")
    location_queries = test_extract_location_with_llm(processor, video_data)

    if not location_queries:
        print("\n❌ No locations extracted. Stopping test.")
        return

    # Step 3: Search Google Places
    print("\n🔍 Step 3: Searching Google Places...")
    for i, query in enumerate(location_queries, 1):
        print(f"\nQuery {i}/{len(location_queries)}:")
        test_search_google_place(processor, query)

    print_section("Pipeline Test Complete")


async def quick_test(url: str = None):
    """
    Quick test of _get_tiktok_data function only

    Args:
        url: TikTok URL to test (uses first TEST_URL if not provided)
    """
    test_url = url or TEST_URLS[0]

    # Get API keys
    openai_key = os.getenv('OPENAI_API_KEY')
    gmaps_key = os.getenv('GOOGLE_PLACES_API_KEY')

    if not openai_key or not gmaps_key:
        print("❌ Missing API keys in .env file!")
        return

    # Initialize processor
    processor = TikTokProcessor(
        openaiKey=openai_key,
        gmaps_key=gmaps_key
    )

    # Test _get_tiktok_data
    await test_get_tiktok_data(processor, test_url)


if __name__ == "__main__":
    # Check for .env file
    if not os.path.exists('.env'):
        print("⚠️  Warning: .env file not found!")
        print("Make sure you have OPENAI_API_KEY and GOOGLE_PLACES_API_KEY set")

    # Choose which test to run:

    # Option 1: Quick test of _get_tiktok_data only
    asyncio.run(quick_test())

    # Option 2: Quick test with specific URL
    # asyncio.run(quick_test("https://vm.tiktok.com/ZNRFs8mSx/"))

    # Option 3: Full pipeline test
    # asyncio.run(full_pipeline_test(TEST_URLS[0]))

    # Option 4: Test specific function with custom data
    # processor = TikTokProcessor(
    #     openaiKey=os.getenv('OPENAI_API_KEY'),
    #     gmaps_key=os.getenv('GOOGLE_PLACES_API_KEY')
    # )
    # test_search_google_place(processor, "Carbone Greenwich Village New York")
