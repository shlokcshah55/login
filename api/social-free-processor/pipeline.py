"""
Pipeline orchestrator.

Coordinates the extraction stages into a single process_url() call
that returns a PipelineResult without touching any media storage.

Stage order:
  1.  URL metadata (OGP / oEmbed)        — cheap, always runs
  2.  Thumbnail OCR                      — in-memory, always runs if thumbnail exists
  2b. Slideshow OCR                      — TikTok photo posts: OCR all slides in memory
  3.  Candidate extraction (LLM)         — from text + thumbnail/slideshow OCR
  4.  Place resolution (Google Places)   — for all candidates
  5.  Confidence scoring                 — tier decision
  6a. Subtitle transcript                — FALLBACK: TikTok machine captions (text-only, cheap)
  6b. Frame OCR (ffmpeg pipe)            — FALLBACK: only if subtitles didn't resolve it
  7.  Re-run candidate extraction        — only when a fallback added new signal
  8.  Re-run resolution + scoring        — final tier decision
"""
import logging

from openai import OpenAI

from models import (
    CandidateMatch, EvidenceFlags, PipelineResult, URLMetadata
)
from stages.url_metadata import fetch_url_metadata, resolve_canonical_url
from stages.candidate_extractor import extract_candidates
from stages.thumbnail_ocr import ocr_thumbnail
from stages.slideshow_ocr import ocr_slideshow
from stages.subtitles import fetch_transcript
from stages.frame_ocr import ocr_frames
from stages.place_resolver import resolve_candidates
from stages.confidence_scorer import score as score_match

logger = logging.getLogger(__name__)

_TIER_HIGH   = "high"
_TIER_MEDIUM = "medium"
_MAX_CONFIRMATION_CHOICES = 4


def _platform(url: str) -> str:
    return "instagram" if "instagram" in url.lower() else "tiktok"


def _build_matches(
    resolved: list[tuple],
    evidence: EvidenceFlags,
) -> list[CandidateMatch]:
    return [
        CandidateMatch(candidate=candidate, place=place, score=score_match(candidate, place, evidence))
        for candidate, places in resolved
        for place in places
    ]


def _best_match(matches: list[CandidateMatch]) -> CandidateMatch | None:
    return max(matches, key=lambda m: m.score.overall) if matches else None


def _top_n(matches: list[CandidateMatch], n: int = _MAX_CONFIRMATION_CHOICES) -> list[CandidateMatch]:
    return sorted(matches, key=lambda m: m.score.overall, reverse=True)[:n]


def _dedupe_by_place(matches: list[CandidateMatch]) -> list[CandidateMatch]:
    """Keep the highest-scoring match per place_id, sorted by score descending."""
    best_per_place: dict[str, CandidateMatch] = {}
    for m in matches:
        existing = best_per_place.get(m.place.place_id)
        if not existing or m.score.overall > existing.score.overall:
            best_per_place[m.place.place_id] = m
    return sorted(best_per_place.values(), key=lambda m: m.score.overall, reverse=True)


def _make_result(
    *,
    source_url: str,
    platform: str,
    evidence: EvidenceFlags,
    matches: list[CandidateMatch],
    best: CandidateMatch,
    meta: URLMetadata,
) -> PipelineResult:
    tier = best.score.tier
    if tier == _TIER_HIGH:
        # A single video can cover many venues (listicles) — auto-save EVERY
        # high-confidence match, not just the best one.
        resolved_matches = _dedupe_by_place(
            [m for m in matches if m.score.tier == _TIER_HIGH]
        )
        return PipelineResult(
            status="resolved",
            source_url=source_url,
            platform=platform,
            evidence_flags=evidence,
            top_match=best,
            candidate_matches=resolved_matches,
            meta=meta,
        )
    if tier == _TIER_MEDIUM:
        return PipelineResult(
            status="needs_confirmation",
            source_url=source_url,
            platform=platform,
            evidence_flags=evidence,
            top_match=best,
            candidate_matches=_top_n(matches),
            meta=meta,
        )
    # low — fall through to caller
    return PipelineResult(
        status="pending",
        source_url=source_url,
        platform=platform,
        evidence_flags=evidence,
        top_match=best,
        candidate_matches=_top_n(matches),
        meta=meta,
    )


def process_url(url: str, openai_client: OpenAI, gmaps_key: str) -> PipelineResult:
    """
    Run the full extraction pipeline for a user-submitted social URL.
    Never raises — returns a PipelineResult with status='failed' on hard error.
    """
    platform = _platform(url)
    evidence = EvidenceFlags()

    try:
        # ── Stage 0: Resolve short links to the canonical post URL ─────────
        # gallery-dl and oEmbed misbehave on vm.tiktok.com short links.
        # `url` (as shared) remains the stored source_url; `work_url` feeds tools.
        work_url = resolve_canonical_url(url)
        if work_url != url:
            logger.info("Canonical URL: %s", work_url)

        # ── Stage 1: Cheap URL metadata ────────────────────────────────────
        meta: URLMetadata = fetch_url_metadata(work_url)
        logger.info(
            "URL metadata: title=%r hashtags=%d has_thumbnail=%s",
            meta.title[:60] if meta.title else "",
            len(meta.hashtags),
            bool(meta.thumbnail_url),
        )
        evidence.caption = bool(meta.title or meta.description or meta.hashtags or meta.location_tag)

        # ── Stage 2: Thumbnail OCR ─────────────────────────────────────────
        thumb_ocr_text = ""
        if meta.thumbnail_url:
            thumb_ocr_text = ocr_thumbnail(meta)
            if thumb_ocr_text:
                evidence.thumbnail_ocr = True
                logger.info("Thumbnail OCR: %d chars", len(thumb_ocr_text))

        # ── Stage 2b: Slideshow OCR (TikTok photo posts) ───────────────────
        # Photo posts have no video stream but their slides are text-heavy —
        # OCRing every slide is cheap and has a high venue-name hit rate.
        is_slideshow, slideshow_text = (False, "")
        if platform == "tiktok":
            is_slideshow, slideshow_text = ocr_slideshow(work_url)
            if slideshow_text:
                evidence.slideshow_ocr = True
                logger.info("Slideshow OCR: %d chars", len(slideshow_text))

        # ── Stage 3: Candidate extraction (caption + cheap OCR) ────────────
        cheap_ocr = " ".join(filter(None, [thumb_ocr_text, slideshow_text]))
        candidates = extract_candidates(openai_client, meta, cheap_ocr)
        logger.info("Candidates extracted: %d", len(candidates))

        # ── Stage 4+5: Place resolution + confidence scoring ───────────────
        cheap_matches: list[CandidateMatch] = []
        cheap_best: CandidateMatch | None = None
        if candidates:
            resolved = resolve_candidates(candidates, gmaps_key)
            cheap_matches = _build_matches(resolved, evidence)
            cheap_best = _best_match(cheap_matches)

            if cheap_best and cheap_best.score.tier in (_TIER_HIGH, _TIER_MEDIUM):
                logger.info("Cheap path confidence: %.3f (%s)", cheap_best.score.overall, cheap_best.score.tier)
                return _make_result(
                    source_url=url, platform=platform,
                    evidence=evidence, matches=cheap_matches, best=cheap_best, meta=meta,
                )

        # ── Stage 6a: Subtitle transcript fallback (video posts only) ──────
        # TikTok's machine captions are a tiny text file — much cheaper than
        # frame OCR and often name every venue the creator talks about.
        best_so_far = cheap_best
        matches_so_far = cheap_matches

        if not is_slideshow:
            logger.info("Low confidence from cheap path — trying subtitle transcript")
            transcript = fetch_transcript(work_url)
            if transcript:
                meta.transcript = transcript
                evidence.subtitles = True

                candidates = extract_candidates(openai_client, meta, cheap_ocr)
                logger.info("Candidates with transcript: %d", len(candidates))
                if candidates:
                    resolved = resolve_candidates(candidates, gmaps_key)
                    matches = _build_matches(resolved, evidence)
                    best = _best_match(matches)
                    if best and (not best_so_far or best.score.overall > best_so_far.score.overall):
                        best_so_far, matches_so_far = best, matches
                    if best_so_far and best_so_far.score.tier in (_TIER_HIGH, _TIER_MEDIUM):
                        logger.info("Transcript path confidence: %.3f (%s)",
                                    best_so_far.score.overall, best_so_far.score.tier)
                        return _make_result(
                            source_url=url, platform=platform,
                            evidence=evidence, matches=matches_so_far, best=best_so_far, meta=meta,
                        )

        # ── Stage 6b: Frame OCR fallback (still low confidence) ────────────
        frame_ocr_text = ""
        if is_slideshow:
            logger.info("Photo post — no video stream, skipping frame OCR")
        else:
            logger.info("Still low confidence — attempting frame OCR")
            frame_ocr_text = ocr_frames(work_url)
            if frame_ocr_text:
                evidence.frame_ocr = True
                logger.info("Frame OCR: %d chars", len(frame_ocr_text))

        # ── Stage 7+8: Re-extract and re-score, only if new signal arrived ─
        if frame_ocr_text:
            combined_ocr = " ".join(filter(None, [cheap_ocr, frame_ocr_text]))
            candidates = extract_candidates(openai_client, meta, combined_ocr)
            logger.info("Candidates after frame OCR: %d", len(candidates))

            if candidates:
                resolved = resolve_candidates(candidates, gmaps_key)
                matches = _build_matches(resolved, evidence)
                best = _best_match(matches)
                if best and (not best_so_far or best.score.overall > best_so_far.score.overall):
                    best_so_far, matches_so_far = best, matches

        # ── Return the strongest result found across all paths ─────────────
        if best_so_far:
            logger.info("Final result: %.3f (%s)", best_so_far.score.overall, best_so_far.score.tier)
            return _make_result(
                source_url=url, platform=platform,
                evidence=evidence, matches=matches_so_far, best=best_so_far, meta=meta,
            )

        # ── No candidates found at all ─────────────────────────────────────
        logger.info("No candidates found after all stages — returning pending")
        return PipelineResult(
            status="pending",
            source_url=url,
            platform=platform,
            evidence_flags=evidence,
            meta=meta,
        )

    except Exception as exc:
        logger.error("Pipeline error for %s: %s", url, exc, exc_info=True)
        return PipelineResult(
            status="failed",
            source_url=url,
            platform=platform,
            error=str(exc),
        )
