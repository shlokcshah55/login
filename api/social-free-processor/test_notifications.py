import unittest
from unittest.mock import patch

import notifications


class NotificationPayloadTest(unittest.TestCase):
    @patch("notifications._send")
    @patch("notifications._fetch_fcm_token", return_value=None)
    def test_notification_is_persisted_even_without_fcm_token(self, _, send):
        notifications.notify_review_ready(
            object(),
            push_url="https://push.example",
            secret="secret",
            user_id="user-1",
            social_post_id="post-1",
            platform="tiktok",
            place_count=1,
            saved_count=1,
            first_place_name="Noodle Yard",
        )

        self.assertEqual(send.call_args.kwargs["fcm_token"], None)

    @patch("notifications._send")
    @patch("notifications._fetch_fcm_token", return_value="token")
    def test_saved_notification_includes_explicit_outcome(self, _, send):
        notifications.notify_review_ready(
            object(),
            push_url="https://push.example",
            secret="secret",
            user_id="user-1",
            social_post_id="post-1",
            platform="tiktok",
            place_count=2,
            saved_count=2,
            first_place_name="Noodle Yard",
        )

        payload = send.call_args.kwargs
        self.assertEqual(payload["metadata"]["outcome"], "saved")
        self.assertEqual(payload["metadata"]["savedCount"], 2)
        self.assertEqual(payload["metadata"]["firstPlaceName"], "Noodle Yard")
        self.assertEqual(payload["title"], "Saved from TikTok")

    @patch("notifications._send")
    @patch("notifications._fetch_fcm_token", return_value="token")
    def test_uncertain_and_failed_have_distinct_outcomes(self, _, send):
        common = dict(
            supabase=object(),
            push_url="https://push.example",
            secret="secret",
            user_id="user-1",
            social_post_id="post-1",
            platform="tiktok",
        )
        notifications.notify_review_ready(
            **common,
            place_count=1,
            saved_count=0,
        )
        notifications.notify_review_ready(
            **common,
            place_count=0,
            failed=True,
        )

        uncertain = send.call_args_list[0].kwargs["metadata"]
        failed = send.call_args_list[1].kwargs["metadata"]
        self.assertEqual(uncertain["outcome"], "needs_checking")
        self.assertEqual(failed["outcome"], "failed")


if __name__ == "__main__":
    unittest.main()
