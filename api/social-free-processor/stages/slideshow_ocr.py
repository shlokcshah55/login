"""
Stage 2b: TikTok slideshow (photo-mode) OCR.

TikTok photo posts have no video stream, but every slide is a static,
text-heavy image — creators typically write venue names directly on them,
so full-image OCR here has a very high hit rate.

Slide URL discovery:
  1. gallery-dl -g (URL-extraction mode — resolves TikTok's API, downloads nothing)
  2. Fallback: parse the page's embedded state JSON (works only when TikTok
     serves a hydrated page, which it often does not for plain HTTP clients)

Privacy constraints (same as thumbnail/frame OCR):
  - Slides are fetched into memory buffers only, never written to disk
  - Maximum 8 slides processed
  - Buffers are released immediately after each OCR pass
  - Raw OCR output is deduplicated in memory and never persisted
"""
import io
import json
import logging
import subprocess

import httpx
from bs4 import BeautifulSoup
from PIL import Image

from stages.ocr_utils import ocr_full_image

logger = logging.getLogger(__name__)

MAX_SLIDES = 8
_GALLERY_DL_TIMEOUT = 30  # seconds

# TikTok slide images carry the photomode marker; the audio track does not.
_IMAGE_MARKERS = ("photomode", ".jpeg", ".jpg", ".webp", ".png")

_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/120.0.0.0 Safari/537.36"
    ),
    "Accept-Language": "en-US,en;q=0.9",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
}


def ocr_slideshow(url: str) -> tuple[bool, str]:
    """
    Detect whether `url` is a TikTok photo post and OCR its slides.

    Returns (is_slideshow, deduped_text):
      (False, "") — not a slideshow (or slide discovery failed)
      (True,  "…") — slideshow; text may be empty if OCR found nothing
    """
    slide_urls = _slide_urls_via_gallery_dl(url)
    if not slide_urls:
        slide_urls = _slide_urls_via_page_json(url)
    if not slide_urls:
        return (False, "")

    logger.info("Photo post detected: %d slides (processing max %d)", len(slide_urls), MAX_SLIDES)

    seen: set[str] = set()
    lines: list[str] = []

    with httpx.Client(timeout=12.0, headers=_HEADERS) as client:
        for slide_url in slide_urls[:MAX_SLIDES]:
            img: Image.Image | None = None
            try:
                resp = client.get(slide_url)
                resp.raise_for_status()
                img = Image.open(io.BytesIO(resp.content)).convert("RGB")
                ocr_full_image(img, seen, lines)
            except Exception as exc:
                logger.warning("Slide OCR failed: %s", exc)
            finally:
                img = None  # release slide buffer

    return (True, " ".join(lines))


# ── Slide URL discovery ──────────────────────────────────────────────────────

def _slide_urls_via_gallery_dl(url: str) -> list[str]:
    """
    Use gallery-dl in URL-extraction mode (-g). Nothing is downloaded;
    it just resolves and prints the direct CDN URLs for each slide.
    Returns [] for regular video posts (no image URLs in output).
    """
    try:
        result = subprocess.run(
            ["gallery-dl", "-g", url],
            capture_output=True,
            text=True,
            timeout=_GALLERY_DL_TIMEOUT,
        )
        if result.returncode != 0:
            logger.debug("gallery-dl exited %d: %s", result.returncode, result.stderr[:200])
            return []
        urls = [l.strip() for l in result.stdout.splitlines() if l.strip().startswith("http")]
        return [u for u in urls if any(m in u.lower() for m in _IMAGE_MARKERS)]
    except subprocess.TimeoutExpired:
        logger.warning("gallery-dl timed out for %s", url)
        return []
    except FileNotFoundError:
        logger.warning("gallery-dl not installed — falling back to page JSON")
        return []
    except Exception as exc:
        logger.warning("gallery-dl slide extraction failed: %s", exc)
        return []


def _slide_urls_via_page_json(url: str) -> list[str]:
    """Fallback: parse TikTok's embedded state JSON for slide URLs."""
    try:
        with httpx.Client(timeout=12.0, headers=_HEADERS, follow_redirects=True) as client:
            resp = client.get(url)
            resp.raise_for_status()
            html = resp.text
    except Exception as exc:
        logger.warning("Slideshow page fetch failed for %s: %s", url, exc)
        return []

    soup = BeautifulSoup(html, "html.parser")
    for script_id, extractor in (
        ("__UNIVERSAL_DATA_FOR_REHYDRATION__", _urls_from_universal_data),
        ("SIGI_STATE", _urls_from_sigi_state),
    ):
        tag = soup.find("script", id=script_id)
        if not tag or not tag.string:
            continue
        try:
            urls = extractor(json.loads(tag.string))
            if urls:
                return urls
        except Exception as exc:
            logger.debug("State JSON parse failed for %s: %s", script_id, exc)
    return []


def _urls_from_universal_data(data: dict) -> list[str]:
    item = (
        data.get("__DEFAULT_SCOPE__", {})
        .get("webapp.video-detail", {})
        .get("itemInfo", {})
        .get("itemStruct", {})
    )
    return _image_post_urls(item)


def _urls_from_sigi_state(data: dict) -> list[str]:
    for item in (data.get("ItemModule") or {}).values():
        urls = _image_post_urls(item)
        if urls:
            return urls
    return []


def _image_post_urls(item: dict) -> list[str]:
    images = (item.get("imagePost") or {}).get("images") or []
    urls = []
    for image in images:
        url_list = (image.get("imageURL") or {}).get("urlList") or []
        if url_list:
            urls.append(url_list[0])
    return urls
