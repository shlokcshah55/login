import os
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, os.path.dirname(__file__))

import pipeline
from models import Candidate, ConfidenceResult, ResolvedPlace, URLMetadata


class PipelineFallbackTest(unittest.TestCase):
    def setUp(self):
        self.meta = URLMetadata(
            title="Hidden ramen in Soho",
            description="The chilli ramen is worth the queue",
            thumbnail_url="https://images.example/post.jpg",
            creator_handle="foodfriend",
        )
        self.candidate = Candidate(
            name="Ramen House",
            area="Soho",
            search_query="Ramen House Soho",
            source="caption",
        )
        self.place = ResolvedPlace(
            place_id="google-place-1",
            name="Ramen House",
            address="1 Greek Street, London",
            lat=51.5,
            lng=-0.1,
        )

    def _common_patches(self):
        return (
            patch.object(pipeline, "resolve_canonical_url", return_value="https://tiktok.com/video/1"),
            patch.object(pipeline, "fetch_url_metadata", return_value=self.meta),
            patch.object(pipeline, "ocr_thumbnail", return_value="RAMEN HOUSE"),
            patch.object(pipeline, "extract_slides_via_vision", return_value=(False, [])),
            patch.object(
                pipeline,
                "resolve_candidates",
                side_effect=lambda candidates, _: [
                    (candidate, [self.place]) for candidate in candidates
                ],
            ),
            patch.object(
                pipeline,
                "score_match",
                return_value=ConfidenceResult(overall=0.91, tier="high"),
            ),
        )

    def test_transcript_fallback_reuses_thumbnail_ocr_text(self):
        common = self._common_patches()
        with common[0], common[1], common[2], common[3], common[4], common[5], \
                patch.object(
                    pipeline,
                    "extract_candidates",
                    side_effect=[[], [self.candidate]],
                ) as extract, \
                patch.object(pipeline, "fetch_transcript", return_value="Ramen House Soho"), \
                patch.object(pipeline, "ocr_frames", return_value=""):
            result = pipeline.process_url(
                "https://tiktok.com/video/1",
                openai_client=object(),
                gmaps_key="maps-key",
            )

        self.assertEqual(result.status, "resolved")
        self.assertEqual(extract.call_args_list[1].args[2], "RAMEN HOUSE")

    def test_frame_fallback_combines_thumbnail_and_frame_ocr(self):
        common = self._common_patches()
        with common[0], common[1], common[2], common[3], common[4], common[5], \
                patch.object(
                    pipeline,
                    "extract_candidates",
                    side_effect=[[], [self.candidate]],
                ) as extract, \
                patch.object(pipeline, "fetch_transcript", return_value=""), \
                patch.object(pipeline, "ocr_frames", return_value="SOHO"):
            result = pipeline.process_url(
                "https://tiktok.com/video/1",
                openai_client=object(),
                gmaps_key="maps-key",
            )

        self.assertEqual(result.status, "resolved")
        self.assertEqual(extract.call_args_list[1].args[2], "RAMEN HOUSE SOHO")

    def test_failure_retains_metadata(self):
        with self.assertLogs(pipeline.logger, level="ERROR"), patch.object(
                pipeline,
                "resolve_canonical_url",
                return_value="https://tiktok.com/video/1",
            ), patch.object(
                pipeline,
                "fetch_url_metadata",
                return_value=self.meta,
            ), patch.object(
                pipeline,
                "ocr_thumbnail",
                return_value="",
            ), patch.object(
                pipeline,
                "extract_slides_via_vision",
                return_value=(False, []),
            ), patch.object(
                pipeline,
                "extract_candidates",
                side_effect=RuntimeError("extractor unavailable"),
            ):
                result = pipeline.process_url(
                    "https://tiktok.com/video/1",
                    openai_client=object(),
                    gmaps_key="maps-key",
                )

        self.assertEqual(result.status, "failed")
        self.assertIs(result.meta, self.meta)


if __name__ == "__main__":
    unittest.main()
