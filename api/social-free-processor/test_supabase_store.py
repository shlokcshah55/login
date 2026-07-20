import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(__file__))

from models import URLMetadata
import supabase_store


class SupabaseStorePolicyTest(unittest.TestCase):
    def test_post_metadata_fields_include_caption_and_thumbnail(self):
        meta = URLMetadata(
            title="Best noodles in London",
            description="Three bowls worth ordering",
            thumbnail_url="https://images.example/noodles.jpg",
            creator_handle="noodlefan",
        )

        self.assertEqual(
            supabase_store.post_metadata_fields(meta),
            {
                "creator_handle": "noodlefan",
                "title": "Best noodles in London",
                "caption": "Three bowls worth ordering",
                "thumbnail_url": "https://images.example/noodles.jpg",
            },
        )

    def test_only_high_confidence_places_auto_save(self):
        high = {"location_id": 10, "confidence_tier": "high"}
        medium = {"location_id": 11, "confidence_tier": "medium"}
        unresolved = {"location_id": None, "confidence_tier": "high"}

        self.assertTrue(supabase_store.should_auto_save_place(high))
        self.assertFalse(supabase_store.should_auto_save_place(medium))
        self.assertFalse(supabase_store.should_auto_save_place(unresolved))


if __name__ == "__main__":
    unittest.main()
