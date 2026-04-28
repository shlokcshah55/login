import unittest

from deeplink import (
    DeepLinkResolutionError,
    find_existing_deep_link,
    normalize_notification_type,
    resolve_deep_link,
)


class DeeplinkTests(unittest.TestCase):
    def test_find_existing_deeplink(self):
        self.assertEqual(
            find_existing_deep_link({"deepLink": "pinit://user/123"}),
            "pinit://user/123",
        )
        self.assertEqual(
            find_existing_deep_link({"deep_link": "pinit://location/1"}),
            "pinit://location/1",
        )
        self.assertIsNone(find_existing_deep_link({}))

    def test_normalize_type_aliases(self):
        self.assertEqual(normalize_notification_type("location_saved"), "video_processed")
        self.assertEqual(
            normalize_notification_type("proximity_locaiton"), "proximity_location"
        )
        self.assertEqual(normalize_notification_type("  FOLLOW_REQUEST "), "follow_request")

    def test_resolve_follow_request(self):
        self.assertEqual(
            resolve_deep_link("follow_request", {"userId": "u1"}),
            "pinit://user/u1",
        )

    def test_resolve_proximity_location(self):
        self.assertEqual(
            resolve_deep_link("proximity_location", {"locationId": "42"}),
            "pinit://location/42",
        )

    def test_resolve_video_processed(self):
        self.assertEqual(
            resolve_deep_link("video_processed", {"locationId": "42"}),
            "pinit://location/42",
        )

    def test_missing_required_id_raises(self):
        with self.assertRaises(DeepLinkResolutionError):
            resolve_deep_link("new_message", {})
        with self.assertRaises(DeepLinkResolutionError):
            resolve_deep_link("video_processed", {})


if __name__ == "__main__":
    unittest.main()
