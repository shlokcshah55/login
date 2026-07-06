"""
Stage 6a (fallback): Subtitle transcript extraction.

TikTok generates machine subtitles for most videos with speech. They're a
tiny WebVTT text file — effectively a free transcript with no audio
processing. Creators usually SAY the restaurant names ("first up is
Dhamaka on the Lower East Side") even when the caption doesn't name them.

Implementation note: TikTok's API is inconsistent about exposing subtitle
URLs in metadata (yt-dlp -J often returns an empty subtitles dict even when
captions exist), so we use yt-dlp's subtitle download machinery instead,
pointed at a throwaway temp directory that is deleted before this function
returns. In the Docker image TMPDIR is /dev/shm, so the file only ever
lives in RAM. No video/audio media is downloaded (--skip-download).
"""
import glob
import logging
import os
import subprocess
import tempfile

logger = logging.getLogger(__name__)

_YTDLP_TIMEOUT = 45   # seconds
_MAX_TRANSCRIPT_CHARS = 4000


def fetch_transcript(url: str) -> str:
    """
    Return a plain-text transcript from the video's subtitle track,
    or "" when no subtitles exist / extraction fails.
    """
    vtt_text = ""
    try:
        with tempfile.TemporaryDirectory(prefix="pinit-subs-") as tmpdir:
            result = subprocess.run(
                [
                    "yt-dlp",
                    "--skip-download",
                    "--write-subs",
                    "--write-auto-subs",
                    "--sub-langs", "en.*,eng.*",
                    "--no-playlist",
                    "-o", os.path.join(tmpdir, "subs"),
                    url,
                ],
                capture_output=True,
                text=True,
                timeout=_YTDLP_TIMEOUT,
            )
            if result.returncode != 0:
                logger.debug("yt-dlp subs exited %d: %s", result.returncode, result.stderr[:200])

            vtt_files = glob.glob(os.path.join(tmpdir, "*.vtt"))
            if vtt_files:
                with open(vtt_files[0], "r", encoding="utf-8", errors="replace") as f:
                    vtt_text = f.read()
        # tmpdir and its contents are deleted here, before any parsing output escapes
    except subprocess.TimeoutExpired:
        logger.warning("yt-dlp subtitles timed out for %s", url)
        return ""
    except FileNotFoundError:
        logger.warning("yt-dlp not installed — subtitles unavailable")
        return ""
    except Exception as exc:
        logger.warning("Subtitle extraction failed: %s", exc)
        return ""

    if not vtt_text:
        return ""

    transcript = parse_vtt(vtt_text)
    if transcript:
        logger.info("Subtitle transcript: %d chars", len(transcript))
    return transcript


def parse_vtt(vtt_text: str, max_chars: int = _MAX_TRANSCRIPT_CHARS) -> str:
    """Strip WebVTT headers/timestamps and collapse duplicate cues to plain text."""
    lines: list[str] = []
    prev: str | None = None
    for raw_line in vtt_text.splitlines():
        line = raw_line.strip()
        if (not line
                or line.startswith(("WEBVTT", "NOTE", "STYLE"))
                or "-->" in line
                or line.isdigit()):
            continue
        if line != prev:
            lines.append(line)
            prev = line
    return " ".join(lines)[:max_chars]
