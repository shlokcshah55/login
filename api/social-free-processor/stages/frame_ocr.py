"""
Stage 6 (fallback only): Ephemeral frame OCR via ffmpeg pipe.

This stage runs ONLY when cheap extraction produced low confidence.
It uses yt-dlp to obtain a playable CDN URL (no download), then pipes
ffmpeg frame output directly into memory and OCRs cropped regions.

Hard constraints:
  - No video files written to disk
  - No screenshot files written to disk
  - Maximum 8 frames, first 20 seconds only
  - Frame buffers explicitly discarded after each OCR pass
  - Raw OCR text is NEVER stored — caller receives candidate text only
"""
import io
import logging
import subprocess

from PIL import Image

from stages.ocr_utils import ocr_image_regions

logger = logging.getLogger(__name__)

MAX_FRAMES = 8
VIDEO_SECONDS = 20
FRAME_INTERVAL_EXPR = "1/3"   # ~1 frame every 3 seconds → 6–7 frames in 20s
SCALE_WIDTH = 640

_PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"

_YTDLP_TIMEOUT = 30   # seconds
_FFMPEG_TIMEOUT = 60  # seconds


def _get_playable_url(source_url: str) -> str | None:
    """
    Use yt-dlp to resolve the CDN video URL — no download occurs.
    Returns None if the platform blocks yt-dlp or the URL is unavailable.
    """
    try:
        result = subprocess.run(
            [
                "yt-dlp",
                "--get-url",
                "--no-playlist",
                "--format", "bestvideo[ext=mp4]/best[ext=mp4]/best",
                source_url,
            ],
            capture_output=True,
            text=True,
            timeout=_YTDLP_TIMEOUT,
        )
        lines = [l.strip() for l in result.stdout.splitlines() if l.strip().startswith("http")]
        return lines[0] if lines else None
    except subprocess.TimeoutExpired:
        logger.warning("yt-dlp timed out for %s", source_url)
        return None
    except FileNotFoundError:
        logger.warning("yt-dlp not installed — frame OCR unavailable")
        return None
    except Exception as exc:
        logger.warning("yt-dlp URL extraction failed: %s", exc)
        return None


def _split_png_stream(raw: bytes) -> list[bytes]:
    """
    Split a concatenated PNG byte-stream (ffmpeg image2pipe output)
    into individual frame byte buffers.
    """
    frames: list[bytes] = []
    i = 0
    while i < len(raw):
        start = raw.find(_PNG_SIGNATURE, i)
        if start == -1:
            break
        next_start = raw.find(_PNG_SIGNATURE, start + 8)
        frames.append(raw[start:next_start] if next_start != -1 else raw[start:])
        i = next_start if next_start != -1 else len(raw)
    return frames


def ocr_frames(source_url: str) -> str:
    """
    Extract and OCR up to MAX_FRAMES frames from the first VIDEO_SECONDS of
    the video referenced by source_url. All image buffers are discarded
    immediately after each OCR pass.

    Returns deduplicated candidate text, or "" if the pipeline cannot run.
    """
    playable_url = _get_playable_url(source_url)
    if not playable_url:
        logger.info("Frame OCR skipped — could not obtain playable URL for %s", source_url)
        return ""

    raw: bytes | None = None
    try:
        cmd = [
            "ffmpeg",
            "-loglevel", "error",
            "-ss", "0",
            "-t", str(VIDEO_SECONDS),
            "-i", playable_url,
            "-vf", f"fps={FRAME_INTERVAL_EXPR},scale={SCALE_WIDTH}:-1",
            "-frames:v", str(MAX_FRAMES),
            "-f", "image2pipe",
            "-vcodec", "png",
            "pipe:1",
        ]
        proc = subprocess.run(
            cmd, capture_output=True, timeout=_FFMPEG_TIMEOUT
        )
        if proc.returncode != 0:
            logger.warning("ffmpeg exited %d for %s", proc.returncode, source_url)
            return ""
        raw = proc.stdout
    except subprocess.TimeoutExpired:
        logger.warning("ffmpeg timed out for %s", source_url)
        return ""
    except FileNotFoundError:
        logger.warning("ffmpeg not installed — frame OCR unavailable")
        return ""
    except Exception as exc:
        logger.warning("ffmpeg pipe failed: %s", exc)
        return ""

    frame_blobs = _split_png_stream(raw)
    raw = None  # discard the full pipe output immediately

    seen: set[str] = set()
    ocr_lines: list[str] = []

    for frame_bytes in frame_blobs[:MAX_FRAMES]:
        img: Image.Image | None = None
        try:
            img = Image.open(io.BytesIO(frame_bytes)).convert("RGB")
            ocr_image_regions(img, seen, ocr_lines)
        except Exception as exc:
            logger.warning("Frame OCR error for one frame: %s", exc)
        finally:
            frame_bytes = None  # discard frame buffer
            img = None

    return " ".join(ocr_lines)
