"""
Stage 1: Cheap URL metadata extraction.

Priority:
  1. TikTok oEmbed API (official, no auth required)
  2. HTML OGP meta tag parsing (og:title, og:description, og:image)

No media is downloaded or stored — only text and a thumbnail URL are returned.
"""
import re
import logging
from urllib.parse import urlparse, urlunparse

import httpx
from bs4 import BeautifulSoup

from models import URLMetadata

logger = logging.getLogger(__name__)

_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/120.0.0.0 Safari/537.36"
    ),
    "Accept-Language": "en-US,en;q=0.9",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
}


def resolve_canonical_url(url: str) -> str:
    """
    Follow redirects (vm.tiktok.com short links etc.) to the canonical post URL,
    with tracking query params stripped. Falls back to the input on failure.
    Downstream tools (gallery-dl, oEmbed) behave unreliably on short links.
    """
    try:
        with httpx.Client(timeout=10.0, headers=_HEADERS, follow_redirects=True) as client:
            with client.stream("GET", url) as resp:
                final = str(resp.url)
        parsed = urlparse(final)
        if not parsed.netloc:
            return url
        return urlunparse((parsed.scheme, parsed.netloc, parsed.path, "", "", ""))
    except Exception as exc:
        logger.warning("Canonical URL resolution failed for %s: %s", url, exc)
        return url


def _extract_hashtags(text: str) -> list[str]:
    return list(dict.fromkeys(
        t.lower() for t in re.findall(r'#(\w+)', text or '')
    ))


def _parse_ogp(html: str) -> dict:
    """Extract og:title, og:description, og:image from raw HTML."""
    soup = BeautifulSoup(html, "html.parser")
    result: dict = {}
    for tag in soup.find_all("meta"):
        prop = tag.get("property", "") or tag.get("name", "")
        content = (tag.get("content", "") or "").strip()
        if not content:
            continue
        if prop in ("og:title", "twitter:title") and "title" not in result:
            result["title"] = content
        elif prop in ("og:description", "twitter:description", "description") and "description" not in result:
            result["description"] = content
        elif prop in ("og:image", "twitter:image") and "thumbnail_url" not in result:
            result["thumbnail_url"] = content
    return result


def _fetch_tiktok_oembed(url: str) -> URLMetadata | None:
    """Use TikTok's official oEmbed endpoint — returns caption, thumbnail, author."""
    try:
        # oEmbed 400s on /photo/ URLs but accepts the same post via /video/
        oembed_url = f"https://www.tiktok.com/oembed?url={url.replace('/photo/', '/video/')}"
        with httpx.Client(timeout=8.0, headers=_HEADERS) as client:
            resp = client.get(oembed_url)
            resp.raise_for_status()
            data = resp.json()

        title = data.get("title", "")
        hashtags = _extract_hashtags(title)
        return URLMetadata(
            title=title,
            description=title,
            hashtags=hashtags,
            thumbnail_url=data.get("thumbnail_url"),
            creator_handle=data.get("author_name"),
        )
    except Exception as exc:
        logger.warning("TikTok oEmbed failed for %s: %s", url, exc)
        return None


def _fetch_ogp(url: str) -> URLMetadata | None:
    """Fall back to parsing OGP meta tags from the page HTML."""
    try:
        with httpx.Client(timeout=10.0, headers=_HEADERS, follow_redirects=True) as client:
            resp = client.get(url)
            resp.raise_for_status()
            ogp = _parse_ogp(resp.text)

        title = ogp.get("title", "")
        description = ogp.get("description", "")
        combined = f"{title} {description}"
        hashtags = _extract_hashtags(combined)
        return URLMetadata(
            title=title,
            description=description,
            hashtags=hashtags,
            thumbnail_url=ogp.get("thumbnail_url"),
        )
    except Exception as exc:
        logger.warning("OGP fetch failed for %s: %s", url, exc)
        return None


def fetch_url_metadata(url: str) -> URLMetadata:
    """
    Extract cheap signals from a TikTok or Instagram URL.
    Returns URLMetadata — never raises.
    """
    is_tiktok = "tiktok.com" in url

    meta: URLMetadata | None = None

    if is_tiktok:
        meta = _fetch_tiktok_oembed(url)

    if not meta or not meta.title:
        meta = _fetch_ogp(url) or URLMetadata()

    return meta
