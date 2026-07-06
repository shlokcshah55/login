"""
Stage 3: In-memory thumbnail OCR.

Downloads the thumbnail to an in-memory buffer, crops three regions
(top overlay, centre text, bottom subtitle/caption), runs OCR on each,
deduplicates the output, and returns a single string of candidate text.

No images are written to disk. All buffers are explicitly released after use.
"""
import io
import logging

import httpx
from PIL import Image

from models import URLMetadata
from stages.ocr_utils import ocr_image_regions

logger = logging.getLogger(__name__)


def ocr_thumbnail(meta: URLMetadata) -> str:
    """
    Run OCR on the thumbnail referenced in URLMetadata.
    Returns deduplicated extracted text, or "" on failure / no thumbnail.
    """
    thumbnail_url = meta.thumbnail_url
    if not thumbnail_url:
        return ""

    img: Image.Image | None = None
    try:
        with httpx.Client(timeout=12.0) as client:
            resp = client.get(thumbnail_url)
            resp.raise_for_status()
            img = Image.open(io.BytesIO(resp.content)).convert("RGB")

        seen: set[str] = set()
        ocr_lines: list[str] = []
        ocr_image_regions(img, seen, ocr_lines)
        return " ".join(ocr_lines)

    except Exception as exc:
        logger.warning("Thumbnail OCR failed: %s", exc)
        return ""
    finally:
        img = None  # release decoded image buffer
