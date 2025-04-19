"""Main function to test the FirestoreClient."""
import asyncio
import os
from dotenv import load_dotenv
from firestore_db import FirestoreClient, get_firestore_client  # Replace your_module

# Load environment variables (ensure .env file exists with necessary credentials)
load_dotenv()

async def main():
    """Asynchronous main function to test FirestoreClient."""
    client = get_firestore_client()

    if not client or not client.is_connected():
        print("Failed to initialize Firestore client. Check logs for errors.")
        return

    test_doc_id = "test_tiktok_123"
    test_user_id = "user_abc"
    test_video_info = {"id": "v123", "title": "Test Video"}
    test_url = "https://www.tiktok.com/@user/video/123"
    test_locations = [{"name": "London", "place_id": "ChIJddak6r4JdkgRgocCPNK9sJk"}]
    test_place_data = {
        "place_id": "ChIJddak6r4JdkgRgocCPNK9sJk",
        "name": "London",
        "formatted_address": "London, UK",
        "geometry": {"location": {"lat": 51.5074, "lng": 0.1278}}
    }
    test_post_id = "v123"

    print("\n--- Testing get database Users ---")
    users = client.retrieve_users()
    print(f"Users: {users}")

    print("\n--- Testing store_processed_tiktok (existing post) ---")
    store_result_existing = client.store_processed_tiktok(test_video_info, test_url, test_locations, user_id=test_user_id)
    print(f"Store processed TikTok (existing): {store_result_existing}")

    print("\n--- Testing update_tiktok_status ---")
    updated = client.update_tiktok_status(test_doc_id, "processing")
    print(f"Update to processing: {updated}")
    updated = client.update_tiktok_status(test_doc_id, "completed")
    print(f"Update to completed: {updated}")
    updated = client.update_tiktok_status(test_doc_id, "failed", error="Something went wrong")
    print(f"Update to failed: {updated}")

    print("\n--- Testing get_pending_tiktok_links ---")
    pending_links = client.get_pending_tiktok_links()
    print(f"Pending links (initial): {pending_links}")
    pending_links_user = client.get_pending_tiktok_links(user_id=test_user_id)
    print(f"Pending links for user {test_user_id}: {pending_links_user}")

    print("\n--- Testing store_processed_tiktok (new post) ---")
    store_result_new = client.store_processed_tiktok(test_video_info, test_url, test_locations, user_id=test_user_id)
    print(f"Store processed TikTok (new): {store_result_new}")


    print("\n--- Testing get_location_by_place_id (not exists) ---")
    location_not_exists = client.get_location_by_place_id("non_existent_place_id")
    print(f"Location by non_existent_place_id: {location_not_exists}")

    print("\n--- Testing store_location (new) ---")
    stored_location_id = client.store_location(test_place_data)
    print(f"Stored new location ID: {stored_location_id}")

    print("\n--- Testing get_location_by_place_id (exists) ---")
    location_exists = client.get_location_by_place_id(test_place_data["place_id"])
    print(f"Location by place_id {test_place_data['place_id']}: {location_exists}")

    print("\n--- Testing store_location (update) ---")
    updated_place_data = test_place_data.copy()
    updated_place_data["name"] = "Greater London"
    updated_location_id = client.store_location(updated_place_data)
    print(f"Updated location ID: {updated_location_id}")
    location_updated = client.get_location_by_place_id(test_place_data["place_id"])
    print(f"Location after update: {location_updated}")

    print("\n--- Testing link_post_to_location ---")
    linked = client.link_post_to_location(test_post_id, test_place_data["place_id"])
    print(f"Linked post {test_post_id} to location {test_place_data['place_id']}: {linked}")

if __name__ == "__main__":
    asyncio.run(main())