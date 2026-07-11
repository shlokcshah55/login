"""
Stage 2b (TikTok photo posts): vision-based venue extraction.

TikTok slideshow venue names are usually stylised text over food photos —
exactly what tesseract OCR fails on. A vision model reads them reliably (it
recovers names like "Lazos Parrilla" that OCR mangles to "wazos Patrilla"),
so for photo posts we send the slide images straight to the model and get
back structured venue candidates, skipping slide OCR entirely.

Privacy note: unlike the OCR stages, this sends slide images (public TikTok
content) to OpenAI. Images are fetched into memory, base64-encoded for the
request, and never written to disk or persisted.
"""
import base64
import io
import json
import logging

import httpx
from openai import OpenAI
from PIL import Image

from models import Candidate, URLMetadata
from stages.slideshow_ocr import discover_slide_urls, MAX_SLIDES, _HEADERS

logger = logging.getLogger(__name__)

_VISION_MODEL = "gpt-4o-mini"

# Slides are downscaled before upload: TikTok photomode images are large
# portrait JPEGs, and sending 8 at full resolution makes the vision call slow
# (~2 min, risking the Cloud Run request timeout) and token-expensive. Venue
# names are large overlay text that survives downscaling to this longest edge.
_MAX_SLIDE_EDGE = 1024
_JPEG_QUALITY = 80


def extract_slides_via_vision(
    client: OpenAI, url: str, meta: URLMetadata
) -> tuple[bool, list[Candidate]]:
    """
    Detect whether `url` is a TikTok photo post and, if so, extract venue
    candidates from its slides with a vision model.

    Returns (is_slideshow, candidates):
      (False, []) — not a photo post (or slide discovery failed)
      (True,  […]) — photo post; list may be empty if no venues were found
    """
    slide_urls = discover_slide_urls(url)
    if not slide_urls:
        return (False, [])

    logger.info("Photo post detected: %d slides (vision, max %d)", len(slide_urls), MAX_SLIDES)

    images = _fetch_slide_images(slide_urls[:MAX_SLIDES])
    if not images:
        # It IS a slideshow, but we couldn't fetch any slide — return True so
        # the pipeline treats it as a photo post (skips the video fallbacks)
        # and surfaces it as a manual-add review item rather than a hard fail.
        return (True, [])

    candidates = _extract(client, meta, images)
    return (True, candidates)


def _fetch_slide_images(slide_urls: list[str]) -> list[str]:
    """
    Fetch slides into memory, downscale, and return base64 JPEG data URIs.
    Downscaling keeps the vision payload small (faster call, fewer tokens);
    slides that fail to fetch or decode are skipped.
    """
    images: list[str] = []
    with httpx.Client(timeout=12.0, headers=_HEADERS) as http:
        for slide_url in slide_urls:
            try:
                resp = http.get(slide_url)
                resp.raise_for_status()
                images.append(_downscale_to_data_uri(resp.content))
            except Exception as exc:
                logger.warning("Slide fetch failed: %s", exc)
    return images


def _downscale_to_data_uri(raw: bytes) -> str:
    """Downscale an image to _MAX_SLIDE_EDGE and return a base64 JPEG data URI."""
    img = Image.open(io.BytesIO(raw)).convert("RGB")
    longest = max(img.size)
    if longest > _MAX_SLIDE_EDGE:
        scale = _MAX_SLIDE_EDGE / longest
        img = img.resize((int(img.width * scale), int(img.height * scale)), Image.LANCZOS)
    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=_JPEG_QUALITY)
    b64 = base64.b64encode(buf.getvalue()).decode()
    return f"data:image/jpeg;base64,{b64}"


def _extract(client: OpenAI, meta: URLMetadata, images: list[str]) -> list[Candidate]:
    """Send slides (+ caption context) to the vision model → venue candidates."""
    instruction = f"""You are a location extraction tool for a restaurant-saving app.
These images are the slides of a TikTok photo post. Identify every specific
restaurant, cafe, bar, bakery, or named venue shown or captioned in the slides
so each can be looked up in Google Places.

Caption for context: "{meta.title or ''}"
Hashtags: {', '.join(f'#{h}' for h in meta.hashtags) if meta.hashtags else 'None'}

Rules:
- Only specific named venues — never generic terms like "best tacos" or "a cute cafe".
- Include the city/neighbourhood when shown or clear from context — it sharply
  improves Google Places matching.
- Slideshows often list many venues; extract every distinct one.
- Read stylised/handwritten text carefully; correct obvious misreadings.

Output JSON only, no markdown:
{{"candidates":[{{"name":"Lazos Parrilla","area":"Arequipa","search_query":"Lazos Parrilla Arequipa"}}]}}
If none: {{"candidates":[]}}"""

    content: list[dict] = [{"type": "text", "text": instruction}]
    for data_uri in images:
        content.append({"type": "image_url", "image_url": {"url": data_uri}})

    try:
        response = client.chat.completions.create(
            model=_VISION_MODEL,
            messages=[{"role": "user", "content": content}],
            response_format={"type": "json_object"},
            temperature=0,
            max_tokens=800,
        )
        data = json.loads(response.choices[0].message.content)
    except Exception as exc:
        logger.error("Slideshow vision extraction failed: %s", exc)
        return []

    candidates: list[Candidate] = []
    for c in data.get("candidates", []):
        name = (c.get("name") or "").strip()
        if not name:
            continue
        area = c.get("area") or None
        candidates.append(
            Candidate(
                name=name,
                area=area,
                search_query=c.get("search_query") or f"{name} {area or ''}".strip(),
                source="slideshow_vision",
                reasoning="Extracted from slide images by vision model",
            )
        )
    return candidates
