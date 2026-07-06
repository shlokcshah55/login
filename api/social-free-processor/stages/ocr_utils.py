"""
Shared in-memory OCR helpers.

Two modes:
  - ocr_image_regions: crops top/centre/bottom bands — for video frames and
    thumbnails where text appears as overlays
  - ocr_full_image: OCRs the whole image — for slideshow slides where text
    can appear anywhere (usually a text-heavy list)

All operate on PIL images in memory; nothing touches disk.
"""
import logging

import pytesseract
from PIL import Image

logger = logging.getLogger(__name__)

# Fractional (y_start, y_end) crop regions — covers where overlay text typically appears
CROP_REGIONS = [
    (0.00, 0.22),   # top overlay / title banner
    (0.35, 0.65),   # centre text / graphic
    (0.72, 1.00),   # bottom subtitle / caption / username bar
]

TESSERACT_CONFIG = "--psm 6 --oem 3"
MIN_CROP_HEIGHT_PX = 40
_FULL_IMAGE_MAX_WIDTH = 720


def ocr_image_regions(img: Image.Image, seen: set[str], out_lines: list[str]) -> None:
    """
    OCR the three overlay crop regions of `img`, appending new deduped
    lines to out_lines. Crop buffers are released after each pass.
    """
    w, h = img.size
    for y_start_frac, y_end_frac in CROP_REGIONS:
        y0 = int(h * y_start_frac)
        y1 = int(h * y_end_frac)
        if (y1 - y0) < MIN_CROP_HEIGHT_PX:
            continue
        crop: Image.Image | None = None
        try:
            crop = img.crop((0, y0, w, y1))
            # Upscale small crops for better OCR accuracy
            if crop.height < 100:
                scale = max(2, 100 // crop.height)
                crop = crop.resize(
                    (crop.width * scale, crop.height * scale),
                    Image.LANCZOS,
                )
            _collect_lines(pytesseract.image_to_string(crop, config=TESSERACT_CONFIG), seen, out_lines)
        except Exception as exc:
            logger.debug("Crop OCR error: %s", exc)
        finally:
            crop = None  # release crop buffer


def ocr_full_image(img: Image.Image, seen: set[str], out_lines: list[str]) -> None:
    """
    OCR the entire image (downscaled for speed), appending new deduped
    lines to out_lines. Used for slideshow slides.
    """
    scaled: Image.Image | None = None
    try:
        if img.width > _FULL_IMAGE_MAX_WIDTH:
            new_height = int(img.height * _FULL_IMAGE_MAX_WIDTH / img.width)
            scaled = img.resize((_FULL_IMAGE_MAX_WIDTH, new_height), Image.LANCZOS)
        else:
            scaled = img
        _collect_lines(pytesseract.image_to_string(scaled, config=TESSERACT_CONFIG), seen, out_lines)
    except Exception as exc:
        logger.debug("Full-image OCR error: %s", exc)
    finally:
        scaled = None  # release scaled buffer


def _collect_lines(raw: str, seen: set[str], out_lines: list[str]) -> None:
    for line in raw.splitlines():
        line = line.strip()
        if line and line not in seen:
            seen.add(line)
            out_lines.append(line)
