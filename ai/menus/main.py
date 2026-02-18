"""
Restaurant Menu Crawler & Dietary Analysis Pipeline
====================================================
Uses Crawl4AI to discover menu pages, extract content,
and Grok (xAI) to analyse dietary friendliness.

Usage:
    # Single restaurant
    result = await analyse_restaurant("https://example-restaurant.com", "ChIJ...")

    # Batch from Supabase
    await run_batch_pipeline(supabase_url, supabase_key)
"""

import asyncio
import base64
import json
import re
import os
import io
import logging
from dataclasses import dataclass, field, asdict
from typing import Optional
from urllib.parse import urljoin, urlparse

import httpx
import pdfplumber
from crawl4ai import AsyncWebCrawler, BrowserConfig, CrawlerRunConfig
from supabase import create_client, Client
from openai import AsyncOpenAI
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# ── Configuration ────────────────────────────────────────────────────────────

XAI_API_KEY=os.getenv("XAI_API_KEY", "your-xai-api-key")
print(XAI_API_KEY)
SUPABASE_URL=os.getenv("SUPABASE_URL", "https://your-supabase-url.supabase.co")
SUPABASE_KEY=os.getenv("SUPABASE_KEY", "your-supabase-key")
XAI_BASE_URL = "https://api.x.ai/v1"
MODEL = "grok-4-fast-non-reasoning"  # Fast Grok model for text and vision

MENU_PATH_PATTERNS = [
    "/menu", "/food", "/our-menu", "/food-menu", "/food-drink",
    "/food-and-drink", "/eat", "/dine", "/dishes", "/carte",
    "/a-la-carte", "/lunch", "/dinner", "/brunch",
    "/menus", "/the-menu",
]

MENU_PATH_ANTI_PATTERNS = [ "drinks-menu", "drinks", "wine-list", "cocktail-menu",
    "/about", "/contact", "/locations", "/privacy", "/terms",
    "/blog", "/news", "/events", "/careers", "/jobs",
]

MENU_LINK_KEYWORDS = [
    "menu", "food", "dishes", "carte", "dine", "eat",
    "lunch", "dinner", "brunch", "drinks", "kitchen",
]

DIETARY_REQUIREMENTS = [
    "vegetarian",
    "vegan",
    "gluten-free",
    "dairy-free",
    "nut-free",
    "pescatarian",
]

# Tag IDs for dietary requirements in Supabase
DIETARY_TAG_IDS = {
    "halal": "f63c9f41-8f9a-4bf1-8268-d21613d9f45b",
    "vegan": "f84b570b-64a3-4055-9ab5-81806876eea2",
    "gluten-free": "d01fbf0d-a31f-4a6f-a5f4-29acf65ec471",
    "vegetarian": "4d7627f0-cd72-48d1-a595-824dd22caf0d",
    "dairy-free": "8cad845c-8207-4cd6-a877-306bc4e2a45d",
    "nut-free": "196df3ce-ebdd-4d7c-8521-ea9070c24d93",
}

MAX_PAGES_PER_SITE = 15
MAX_PDF_DOWNLOADS = 3
MAX_IMAGE_DOWNLOADS = 3

logging.basicConfig(level=logging.WARNING, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger(__name__)

# Progress logger - only for essential progress updates
progress_logger = logging.getLogger("progress")
progress_logger.setLevel(logging.INFO)
progress_handler = logging.StreamHandler()
progress_handler.setFormatter(logging.Formatter("%(message)s"))
progress_logger.addHandler(progress_handler)
progress_logger.propagate = False


# ── Data Models ──────────────────────────────────────────────────────────────

@dataclass
class DietaryScore:
    requirement: str
    dish_count: int
    friendliness_pct: int  # 0, 25, 60, 80

    @staticmethod
    def compute_pct(count: int) -> int:
        if count == 0:
            return 0
        elif count <= 2:
            return 25
        elif count <= 5:
            return 60
        else:
            return 80


@dataclass
class MenuAnalysisResult:
    google_place_id: str
    website: str
    menu_url: Optional[str] = None
    menu_found: bool = False
    menu_markdown: Optional[str] = None
    restaurant_description: Optional[str] = None
    total_dishes: int = 0
    dietary_scores: list[DietaryScore] = field(default_factory=list)
    halal_mentioned: bool = False
    confidence: str = "low"
    reccomended_dishes: Optional[str] = None
    notes: str = ""
    error: Optional[str] = None

    def to_db_row(self) -> dict:
        """Convert to a dict suitable for inserting into menu_analysis table."""
        return {
            "google_place_id": self.google_place_id,
            "menu_url": self.menu_url,
            "menu_found": self.menu_found,
            "total_dishes": self.total_dishes,
            "dietary_scores": {s.requirement: s.friendliness_pct for s in self.dietary_scores},
            "dietary_counts": {s.requirement: s.dish_count for s in self.dietary_scores},
            "restaurant_description": self.restaurant_description,
            "halal_mentioned": self.halal_mentioned,
            "confidence": self.confidence,
            "reccomended_dishes": self.reccomended_dishes,
            "notes": self.notes,
        }


# ── PDF Detection & Extraction ───────────────────────────────────────────────

# Keywords that strongly suggest a PDF is a food/drink menu
PDF_MENU_KEYWORDS = [
    "menu", "food", "alc", "a-la-carte", "carte", "lunch", "dinner",
    "brunch", "drinks", "beverage", "bev", "feast", "tasting",
    "supper", "breakfast", "dish",
]

# Keywords that suggest it's NOT a menu (deprioritise)
PDF_NON_MENU_KEYWORDS = [
    "nutritional", "allergen", "allergy", "wine-list", "cocktail",
    "privacy", "terms", "policy", "report", "press",
]

# ── PDF Detection & Extraction ─────────────────────────────────────────────


def _score_pdf_as_menu(url: str, link_text: str = "") -> int:
    """Score how likely a PDF link is to be a food menu. Higher = more likely."""
    score = 0
    path = urlparse(url).path.lower()
    filename = path.split("/")[-1].lower()
    text = link_text.lower()

    # Check filename for menu keywords
    for keyword in PDF_MENU_KEYWORDS:
        if keyword in filename:
            score += 50
            break

    # Check surrounding link text
    for keyword in PDF_MENU_KEYWORDS:
        if keyword in text:
            score += 40
            break

    # Penalise non-menu PDFs
    for keyword in PDF_NON_MENU_KEYWORDS:
        if keyword in filename or keyword in text:
            score -= 60
            break

    # Bonus for "download" link text (common pattern for menu PDFs)
    if "download" in text:
        score += 20

    # Bonus for recent-sounding filenames (e.g. "Winter_ALC_Jan")
    season_words = ["winter", "spring", "summer", "autumn", "jan", "feb", "mar", "apr", "may", "jun"]
    if any(s in filename for s in season_words):
        score += 10

    return score


def extract_pdf_links(markdown: str, base_url: str) -> list[tuple[int, str]]:
    """
    Extract PDF links from crawled markdown content.
    Returns list of (score, full_url) sorted by score descending.
    """
    # Match markdown links: [text](url.pdf) and bare URLs ending in .pdf
    link_pattern = r'\[([^\]]*)\]\((https?://[^\s\)]+\.pdf[^\s\)]*)\)'
    bare_pattern = r'(https?://[^\s\)]+\.pdf[^\s\)]*)'

    candidates = {}  # url -> (score, url) to deduplicate

    # Markdown links with text context
    for match in re.finditer(link_pattern, markdown, re.IGNORECASE):
        text, url = match.group(1), match.group(2)
        full_url = urljoin(base_url, url)
        score = _score_pdf_as_menu(full_url, text)
        if full_url not in candidates or score > candidates[full_url][0]:
            candidates[full_url] = (score, full_url)

    # Bare PDF URLs (might not have link text)
    for match in re.finditer(bare_pattern, markdown, re.IGNORECASE):
        url = match.group(1)
        full_url = urljoin(base_url, url)
        if full_url not in candidates:
            score = _score_pdf_as_menu(full_url, "")
            candidates[full_url] = (score, full_url)

    # Sort by score descending
    sorted_pdfs = sorted(candidates.values(), key=lambda x: -x[0])
    return sorted_pdfs


async def download_and_extract_pdf(url: str, client: httpx.AsyncClient) -> Optional[str]:
    """Download a PDF and extract its text content using pdfplumber."""
    try:
        logger.info(f"    Downloading PDF: {url}")
        response = await client.get(url, follow_redirects=True, timeout=15.0)

        if response.status_code != 200:
            logger.warning(f"    PDF download failed ({response.status_code}): {url}")
            return None

        content_type = response.headers.get("content-type", "")
        if "pdf" not in content_type and not url.lower().endswith(".pdf"):
            logger.warning(f"    Not a PDF (content-type: {content_type}): {url}")
            return None

        pdf_bytes = response.content
        if len(pdf_bytes) < 100:
            return None

        # Extract text with pdfplumber
        text_parts = []
        with pdfplumber.open(io.BytesIO(pdf_bytes)) as pdf:
            for page in pdf.pages:
                page_text = page.extract_text()
                if page_text:
                    text_parts.append(page_text)

        if not text_parts:
            logger.warning(f"    PDF has no extractable text (image-based?): {url}")
            return None

        full_text = "\n\n".join(text_parts)
        logger.info(f"    ✓ Extracted {len(full_text)} chars from PDF: {url}")
        return full_text

    except Exception as e:
        logger.warning(f"    PDF extraction error for {url}: {e}")
        return None


async def extract_pdfs_from_markdown(
    markdown: str,
    base_url: str,
    max_pdfs: int = MAX_PDF_DOWNLOADS,
) -> list[tuple[str, str]]:
    """
    Find PDF links in markdown, download and extract text from top candidates.
    Returns list of (url, extracted_text) for successful extractions.
    """
    pdf_candidates = extract_pdf_links(markdown, base_url)

    if not pdf_candidates:
        return []

    # Only attempt the top N by score, skip any with very negative scores
    top_candidates = [(score, url) for score, url in pdf_candidates if score > -10][:max_pdfs]

    if not top_candidates:
        return []

    logger.info(f"  Found {len(pdf_candidates)} PDF links, attempting top {len(top_candidates)}")

    results = []
    async with httpx.AsyncClient(
        headers={"User-Agent": "Mozilla/5.0 (compatible; PinItBot/1.0)"},
    ) as http_client:
        for score, url in top_candidates:
            text = await download_and_extract_pdf(url, http_client)
            if text:
                results.append((url, text))

    return results


# ── Image Detection & Extraction ─────────────────────────────────────────────

IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}

# Keywords suggesting image is a menu photo
IMAGE_MENU_KEYWORDS = [
    "menu", "food", "carte", "alc", "a-la-carte", "dinner", "lunch",
    "brunch", "breakfast", "dish", "feast", "tasting", "supper",
]

# Keywords suggesting image is NOT a menu
IMAGE_NON_MENU_KEYWORDS = [
    "logo", "icon", "decor", "bg", "background", "arrow", "close",
    "banner", "hero", "header", "footer", "social", "avatar", "profile",
    "button", "graphic", "pattern", "texture", "quarter-arch", "key",
]


def _score_image_as_menu(url: str) -> int:
    """Score how likely an image URL is to be a menu photo. Higher = more likely."""
    score = 0
    path = urlparse(url).path.lower()
    filename = path.split("/")[-1].lower()

    # Must be an actual image
    if not any(filename.endswith(ext) for ext in IMAGE_EXTENSIONS):
        return -100

    # Check filename for menu keywords
    for keyword in IMAGE_MENU_KEYWORDS:
        if keyword in filename:
            score += 50
            break

    # Penalise non-menu images
    for keyword in IMAGE_NON_MENU_KEYWORDS:
        if keyword in filename:
            score -= 80
            return score  # definitely not a menu, bail early

    # Bonus for "scaled" images (WordPress full-size uploads, likely menu photos)
    if "scaled" in filename or "2000x" in filename or "1440x" in filename:
        score += 15

    # Bonus for images in uploads paths with date folders (real content, not theme assets)
    if "/uploads/" in path:
        score += 20
    # Penalise theme/library assets
    if "/themes/" in path or "/library/" in path or "/assets/" in path:
        score -= 40

    # Small icons/thumbnails unlikely to be menu photos (check for size hints in URL)
    if "800x800" in path or "150x" in path or "100x" in path:
        score -= 10
    if "2000x" in path or "1440x" in path or "scaled" in path:
        score += 10

    return score


def extract_image_links(markdown: str, base_url: str) -> list[tuple[int, str]]:
    """
    Extract image links from crawled markdown content.
    Returns list of (score, full_url) sorted by score descending.
    """
    # Match markdown images: ![alt](url)
    image_pattern = r'!\[[^\]]*\]\(([^\s\)]+)\)'

    candidates = {}  # url -> (score, url) to deduplicate

    for match in re.finditer(image_pattern, markdown):
        url = match.group(1)
        full_url = urljoin(base_url, url)
        score = _score_image_as_menu(full_url)
        if full_url not in candidates or score > candidates[full_url][0]:
            candidates[full_url] = (score, full_url)

    sorted_images = sorted(candidates.values(), key=lambda x: -x[0])
    return sorted_images


async def download_menu_images(
    markdown: str,
    base_url: str,
    max_images: int = MAX_IMAGE_DOWNLOADS,
) -> list[tuple[str, str, str]]:
    """
    Find likely menu images in markdown, download them.
    Returns list of (url, base64_data, media_type) for successful downloads.
    """
    image_candidates = extract_image_links(markdown, base_url)

    if not image_candidates:
        return []

    # Only attempt top N with positive scores
    top_candidates = [(score, url) for score, url in image_candidates if score > 0][:max_images]

    if not top_candidates:
        return []

    logger.info(f"  Found {len(image_candidates)} images, attempting top {len(top_candidates)} as menu images")

    results = []
    async with httpx.AsyncClient(
        headers={"User-Agent": "Mozilla/5.0 (compatible; PinItBot/1.0)"},
    ) as http_client:
        for score, url in top_candidates:
            try:
                logger.info(f"    Downloading image (score={score}): {url}")
                response = await http_client.get(url, follow_redirects=True, timeout=15.0)

                if response.status_code != 200:
                    logger.warning(f"    Image download failed ({response.status_code}): {url}")
                    continue

                content_type = response.headers.get("content-type", "")
                # Determine media type
                if "png" in content_type or url.lower().endswith(".png"):
                    media_type = "image/png"
                elif "webp" in content_type or url.lower().endswith(".webp"):
                    media_type = "image/webp"
                else:
                    media_type = "image/jpeg"  # default

                img_bytes = response.content
                if len(img_bytes) < 1000:
                    logger.debug(f"    Image too small, skipping: {url}")
                    continue

                # Encode as base64
                b64_data = base64.b64encode(img_bytes).decode("utf-8")
                results.append((url, b64_data, media_type))
                logger.info(f"    ✓ Downloaded menu image ({len(img_bytes)} bytes): {url}")

            except Exception as e:
                logger.warning(f"    Image download error for {url}: {e}")
                continue

    return results



 # ── Menu HTML url extraction ─────────────────────────────────────────────

def _score_url_as_menu(url: str, link_text: str = "", verbose: bool = False) -> int:
    """Heuristic score for how likely a URL is a menu page. Higher = more likely."""
    score = 0
    path = urlparse(url).path.lower().rstrip("/")
    text = link_text.lower()
    score_breakdown = []

    # Exact path matches score highest
    if path in MENU_PATH_PATTERNS:
        score += 100
        score_breakdown.append(f"+100 (exact path match: {path})")

    # Partial path matches
    for pattern in MENU_PATH_PATTERNS:
        if pattern.strip("/") in path:
            score += 50
            score_breakdown.append(f"+50 (partial path match: {pattern})")
            break

    # Link text matches
    for keyword in MENU_LINK_KEYWORDS:
        if keyword in text:
            score += 30
            score_breakdown.append(f"+30 (link text contains: '{keyword}')")
            break

    for keyword in MENU_PATH_ANTI_PATTERNS:
        if keyword in path or keyword in text:
            score -= 50
            score_breakdown.append(f"-50 (anti-pattern: '{keyword}')")
            break

    # Penalise deep pages, PDFs (we want HTML menus first)
    if path.endswith(".pdf"):
        score -= 20
        score_breakdown.append(f"-20 (PDF file)")
    if path.count("/") > 3:
        score -= 10
        score_breakdown.append(f"-10 (deep page: {path.count('/')} levels)")

    if verbose and score_breakdown:
        logger.debug(f"      Score breakdown for {url}: {' '.join(score_breakdown)}")

    return score


async def discover_menu_url(base_url: str, crawler: AsyncWebCrawler) -> tuple[Optional[str], str]:
    """
    Crawl the homepage and discover the most likely menu page URL.
    Returns (menu_url, homepage_markdown).
    """
    config = CrawlerRunConfig(
        word_count_threshold=10,
        exclude_external_links=True,
        excluded_tags=["footer", "script", "style", "noscript", "iframe"],
        process_iframes=False,
        page_timeout=60000,  # Wait up to 60 seconds for page load
        delay_before_return_html=2.0,  # Wait 2 seconds for Angular/React to load
    )

    logger.info(f"Crawling homepage: {base_url}")
    result = await crawler.arun(url=base_url, config=config)

    if not result.success:
        logger.warning(f"Failed to crawl {base_url}: {result.error_message}")
        return None, ""

    homepage_md = result.markdown or ""
    logger.info(f"  Crawled homepage with {len(homepage_md)} chars of markdown")

    # ── Strategy 0: Check if homepage itself contains menu ──
    logger.info(f"  === MENU DISCOVERY: Strategy 0 - Checking if homepage has menu content ===")
    if _contains_menu_content(homepage_md):
        logger.info(f"  ✓✓✓ Homepage itself contains menu content! Using homepage as menu URL.")
        return base_url, homepage_md
    else:
        logger.info(f"  Homepage doesn't contain full menu, will search for dedicated menu page")

    # ── Strategy 1: Check internal links found on the page ──
    candidates = []
    logger.info(f"  === MENU DISCOVERY: Strategy 1 - Analyzing homepage links ===")

    if result.links and "internal" in result.links:
        logger.info(f"  Found {len(result.links['internal'])} internal links on homepage")

        for link in result.links["internal"]:
            href = link.get("href", "")
            text = link.get("text", "")
            if not href:
                continue
            full_url = urljoin(base_url, href)
            score = _score_url_as_menu(full_url, text, verbose=True)

            # Log all links with their scores for transparency
            if score > 0:
                logger.info(f"    ✓ Link: '{text[:40]}' → {full_url} (score: {score})")
                candidates.append((score, full_url))
            elif score == 0:
                logger.debug(f"    ○ Link: '{text[:40]}' → {full_url} (score: 0, neutral)")
            else:
                logger.debug(f"    ✗ Link: '{text[:40]}' → {full_url} (score: {score}, excluded)")
    else:
        logger.info(f"  No internal links found on homepage")

    logger.info(f"  Strategy 1 found {len(candidates)} menu candidates")

    # ── Strategy 2: Try common paths directly ──
    logger.info(f"  === MENU DISCOVERY: Strategy 2 - Adding common path patterns ===")
    parsed = urlparse(base_url)
    base = f"{parsed.scheme}://{parsed.netloc}"

    strategy2_count = 0
    for pattern in MENU_PATH_PATTERNS[:8]:  # top 8 most common
        pattern_url = urljoin(base, pattern)
        candidates.append((40, pattern_url))
        strategy2_count += 1
        logger.debug(f"    + Added pattern: {pattern_url} (score: 40)")

    logger.info(f"  Strategy 2 added {strategy2_count} common path patterns")

    if not candidates:
        logger.warning(f"  No menu candidates found!")
        return None, homepage_md

    # Deduplicate and sort by score
    logger.info(f"  === MENU DISCOVERY: Deduplication & Ranking ===")
    logger.info(f"  Total candidates before deduplication: {len(candidates)}")

    seen = set()
    unique = []
    for score, url in sorted(candidates, key=lambda x: -x[0]):
        normalised = url.rstrip("/").lower()
        if normalised not in seen:
            seen.add(normalised)
            unique.append((score, url))

    logger.info(f"  Unique candidates after deduplication: {len(unique)}")
    logger.info(f"  === MENU DISCOVERY: Top 5 candidates to try ===")

    for i, (score, url) in enumerate(unique[:5], 1):
        logger.info(f"    #{i}: {url} (score: {score})")

    # Try the top candidates until one works
    logger.info(f"  === MENU DISCOVERY: Attempting to crawl candidates ===")
    for idx, (score, candidate_url) in enumerate(unique[:5], 1):
        logger.info(f"  [{idx}/5] Trying: {candidate_url} (score={score})")
        try:
            menu_result = await crawler.arun(url=candidate_url, config=config)
            if menu_result.success and menu_result.markdown and len(menu_result.markdown) > 200:
                logger.info(f"  ✓✓✓ SUCCESS! Found menu at: {candidate_url} ({len(menu_result.markdown)} chars)")
                return candidate_url, homepage_md
            elif menu_result.success:
                logger.warning(f"  ✗ Page loaded but too short: {candidate_url} ({len(menu_result.markdown or '')} chars)")
            else:
                logger.warning(f"  ✗ Failed to load: {candidate_url}")
        except Exception as e:
            logger.warning(f"  ✗ Error crawling {candidate_url}: {e}")
            continue

    logger.warning(f"  === MENU DISCOVERY: No valid menu page found ===")
    return None, homepage_md


# ── Step 2: Extract Menu Content ─────────────────────────────────────────────

def _contains_menu_content(markdown: str) -> bool:
    """
    Detect if markdown contains actual menu content (dishes, prices, etc.)
    rather than just navigation/teasers.
    """
    if not markdown or len(markdown) < 300:
        return False

    # Count price patterns (£X.XX, $X.XX, €X.XX, etc.)
    price_patterns = [
        r'£\d+\.\d{2}',  # £12.50
        r'\$\d+\.\d{2}',  # $12.50
        r'€\d+\.\d{2}',  # €12.50
        r'£\d+',         # £12
        r'\$\d+',        # $12
    ]
    price_count = 0
    for pattern in price_patterns:
        price_count += len(re.findall(pattern, markdown))

    # Count food/dish keywords
    dish_keywords = [
        'starters', 'mains', 'desserts', 'appetizers', 'entrees',
        'served with', 'topped with', 'garnished', 'grilled', 'fried',
        'roasted', 'baked', 'steamed'
    ]
    keyword_count = sum(1 for keyword in dish_keywords if keyword.lower() in markdown.lower())

    # Heuristic: If we have multiple prices AND food keywords, likely a menu
    has_prices = price_count >= 5  # At least 5 prices
    has_food_context = keyword_count >= 3  # At least 3 food keywords

    logger.debug(f"Menu detection: {price_count} prices, {keyword_count} food keywords")

    return has_prices and has_food_context


async def extract_menu_content(
    menu_url: str,
    crawler: AsyncWebCrawler,
) -> tuple[Optional[str], list[tuple[str, str, str]]]:
    """
    Fetch the menu page and return cleaned markdown + any menu images.
    Returns (text_content, menu_images) where menu_images is a list of
    (url, base64_data, media_type) tuples.
    
    Fallback chain:
      1. HTML text extraction
      2. PDF download + text extraction (if text is thin)
      3. Image download for vision model (if PDFs also fail)
    """
    config = CrawlerRunConfig(
        word_count_threshold=2,
        process_iframes=False,
        page_timeout=60000,  # Wait up to 60 seconds for page load
        delay_before_return_html=2.0,  # Wait 2 seconds for Angular/React to load and render
    )

    logger.info(f"  === MENU EXTRACTION: Starting extraction from {menu_url} ===")

    result = await crawler.arun(url=menu_url, config=config)

    if not result.success or not result.markdown:
        logger.error(f"  ✗ Failed to crawl menu page: {result.error_message if result else 'Unknown error'}")
        return None, []

    markdown = result.markdown
    logger.info(f"  ✓ Successfully fetched menu page: {len(markdown)} chars of raw markdown")
    menu_images = []

    # Basic cleanup — remove excessive whitespace, nav/footer junk
    lines = markdown.split("\n")
    cleaned = []
    for line in lines:
        stripped = line.strip()
        if len(stripped) < 3:
            continue
        if any(skip in stripped.lower() for skip in [
            "cookie", "privacy policy", "terms of service",
            "all rights reserved", "©", "instagram", "facebook",
            "sign up for", "subscribe to", "newsletter",
        ]):
            continue
        cleaned.append(line)

    content = "\n".join(cleaned).strip()
    logger.info(f"  Extracted {len(content)} chars of text from menu page (after cleanup)")

    # Calculate actual text (without images/links/formatting) for logging
    text_only = re.sub(r'!\[[^\]]*\]\([^\)]*\)', '', content)
    text_only = re.sub(r'\[[^\]]*\]\([^\)]*\)', '', text_only)
    text_only = re.sub(r'[#*_\-\|>\s]+', ' ', text_only).strip()

    logger.info(f"  === MENU EXTRACTION: Analyzing content ({len(text_only)} chars of actual text) ===")

    # ── ALWAYS check for PDFs (regardless of text richness) ──
    logger.info(f"  === MENU EXTRACTION: Looking for PDF menus ===")
    pdf_results = await extract_pdfs_from_markdown(markdown, menu_url)

    if pdf_results:
        logger.info(f"  ✓ SUCCESS: Found and extracted {len(pdf_results)} PDF menu(s)")
        pdf_sections = []
        for idx, (pdf_url, pdf_text) in enumerate(pdf_results, 1):
            filename = pdf_url.split("/")[-1]
            truncated = pdf_text[:5000]
            pdf_sections.append(f"### Menu PDF: {filename}\n{truncated}")
            logger.info(f"    PDF #{idx}: {filename} ({len(pdf_text)} chars extracted)")

        pdf_content = "\n\n".join(pdf_sections)
        content = content + "\n\n## Extracted from PDF Menus\n" + pdf_content
    else:
        logger.info(f"  No PDFs found on page")

    # ── ALWAYS check for menu images (regardless of text richness or PDF presence) ──
    logger.info(f"  === MENU EXTRACTION: Looking for menu images ===")
    menu_images = await download_menu_images(markdown, menu_url)

    if menu_images:
        logger.info(f"  ✓ SUCCESS: Downloaded {len(menu_images)} menu image(s) for vision analysis")
        for idx, (img_url, b64_data, media_type) in enumerate(menu_images, 1):
            logger.info(f"    Image #{idx}: {img_url.split('/')[-1]} ({len(b64_data)} chars base64, {media_type})")
    else:
        logger.info(f"  No menu images found on page")

    # ── Summary of what we're using ──
    logger.info(f"  === MENU EXTRACTION: Content Summary ===")
    has_text = len(text_only) > 100
    has_pdfs = len(pdf_results) > 0 if pdf_results else False
    has_images = len(menu_images) > 0

    sources = []
    if has_text:
        sources.append(f"HTML text ({len(text_only)} chars)")
    if has_pdfs:
        sources.append(f"{len(pdf_results)} PDF(s)")
    if has_images:
        sources.append(f"{len(menu_images)} image(s)")

    if not sources:
        logger.error(f"  ✗✗✗ FLOW FAILED: No menu content found (no text, no PDFs, no images)")
    else:
        logger.info(f"  ✓ FLOW COMPLETE: Using {' + '.join(sources)}")

    # Cap total content
    if len(content) > 15000:
        logger.warning(f"  ⚠ Content too long ({len(content)} chars), truncating to 15000 chars")
        content = content[:15000] + "\n\n[... menu truncated ...]"

    # Final summary
    logger.info(f"  === MENU EXTRACTION: Summary ===")
    logger.info(f"    Total content for LLM: {len(content)} chars")
    logger.info(f"    Images for vision model: {len(menu_images)}")
    logger.info(f"    Extraction complete!")

    return content, menu_images


# ── Step 3: LLM Analysis ─────────────────────────────────────────────────────

ANALYSIS_PROMPT = """You are analysing a restaurant's website content to extract menu information and assess dietary friendliness.

## Input
**Restaurant name:** {restaurant_name}
**Known cuisine type:** {cuisine_hint}

**Restaurant website content (may include homepage + menu page):**
{content}

## Your Tasks

### 1. Restaurant Description (MANDATORY — you must ALWAYS produce this)
Write a 2-3 sentence description of this restaurant. Cover the cuisine type, vibe/atmosphere, price point, and what makes it distinctive. Write it as if for a food discovery app — enticing but factual.
Use ALL available signals: the homepage text, imagery descriptions, restaurant name, the cuisine hint provided, and any other clues on the page (about us sections, taglines, location info, social media bios, review snippets, etc.).
IMPORTANT: The menu page being unavailable does NOT mean you cannot describe the restaurant. A broken menu page is irrelevant to this task. You have the homepage, the restaurant name, and the cuisine type — that is always enough. Never return "Unable to provide description" or similar. Always write something useful.

### 2. Menu Extraction & Dietary Analysis
If a menu is available, go through every dish. For each dietary requirement below, count how many distinct dishes a person with ONLY that requirement could eat.

If NO menu is available (e.g. 404, site under construction, content is just navigation):
- Set total_dishes to 0
- Set all dietary counts to 0
- Set confidence to "no_menu"
- Still provide the description above

Be practical when counting:
- A salad with cheese is vegetarian but NOT vegan or dairy-free
- Plain grilled fish is pescatarian, gluten-free, dairy-free, nut-free, and keto-friendly
- If a dish COULD be modified (e.g. "ask for no cheese"), only count it if the menu explicitly offers that option
- For halal: Search the ENTIRE page content for ANY mention of "halal" (certification, labels, descriptions, about us, footer, anywhere). If halal is mentioned anywhere, set halal_mentioned to true. If not mentioned at all, set halal_mentioned to false. Do NOT try to count halal dishes — just report whether it's mentioned.
- For kosher: unless the restaurant explicitly states kosher certification or specific dishes are marked, count as 0 and note this
- You should be strict, if there is some doubt as to whether someone with a specific requirement could have it, do not assume they can
- If the menu is too vague to determine ingredients, mark confidence as "low"

### 3. Key dish extraction

If the menu exists, extract 2 dishes from the menu that we would be recommending to users. The criteria for these is:

The first one should be a staple that you have high confidence that would be good
The second one should be something unique to that restaurant, something unusual that may be interesting to try

Dietary requirements:
{dietary_list}

### 3. Output Format
Return ONLY valid JSON, no markdown fences:
{{
  "menu_url": "<URL of the menu page, or null if no menu found>",
  "description": "<2-3 sentence restaurant description — ALWAYS provide this>",
  "total_dishes": <total number of distinct dishes on the menu, 0 if no menu>,
  "dietary_counts": {{
    "vegetarian": <int>,
    "vegan": <int>,
    "gluten-free": <int>,
    "dairy-free": <int>,
    "nut-free": <int>,
    "pescatarian": <int>,
    }},
  "halal_mentioned": <true if halal is mentioned anywhere on the site, false otherwise>,
  "confidence": "high" | "medium" | "low" | "no_menu",
  "reccomended_dishes": <names of the two dishes that we want to reccomend seperated by commas>,
  "notes": "<any caveats>"
}}"""


async def analyse_with_llm(
    content: str,
    client: AsyncOpenAI,
    restaurant_name: str = "",
    cuisine_hint: str = "",
    menu_images: list[tuple[str, str, str]] | None = None,
) -> dict:
    """
    Send menu content to xAI Grok for dietary analysis.
    Automatically includes images as vision input when available.
    """
    dietary_list = "\n".join(f"- {d}" for d in DIETARY_REQUIREMENTS)

    prompt = ANALYSIS_PROMPT.format(
        content=content,
        dietary_list=dietary_list,
        restaurant_name=restaurant_name or "Unknown",
        cuisine_hint=cuisine_hint or "Unknown",
    )

    # Build message content — multimodal if we have images
    if menu_images:
        model = MODEL  # grok-4-fast-non-reasoning supports vision
        message_content = []

        # Add images first so the model sees them before the prompt
        for url, b64_data, media_type in menu_images:
            message_content.append({
                "type": "image_url",
                "image_url": {
                    "url": f"data:{media_type};base64,{b64_data}",
                },
            })

        # Prepend extra context to the prompt
        image_note = (
            f"\n\nNOTE: {len(menu_images)} menu image(s) are attached above. "
            f"These are photographs of the restaurant's physical menu. "
            f"Read ALL text visible in the images to extract dish names, descriptions, and prices. "
            f"Use this information for the dietary analysis.\n"
        )
        message_content.append({"type": "text", "text": prompt + image_note})

        logger.info(f"  Using Grok vision model with {len(menu_images)} image(s)")
    else:
        model = MODEL
        message_content = prompt

    response = await client.chat.completions.create(
        model=model,
        max_tokens=1500,
        response_format={"type": "json_object"},
        messages=[
            {"role": "system", "content": "You are a restaurant menu analyst. Always respond with valid JSON."},
            {"role": "user", "content": message_content},
        ],
    )

    raw = response.choices[0].message.content.strip()

    # Strip markdown fences if present
    raw = re.sub(r"^```(?:json)?\s*", "", raw)
    raw = re.sub(r"\s*```$", "", raw)

    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        logger.error(f"Failed to parse LLM response: {raw[:200]}")
        return {
            "description": "",
            "total_dishes": 0,
            "dietary_counts": {d: 0 for d in DIETARY_REQUIREMENTS},
            "confidence": "low",
            "notes": "LLM response parsing failed",
        }


# ── Step 4: Full Pipeline for One Restaurant ─────────────────────────────────

async def analyse_restaurant(
    website: str,
    google_place_id: str,
    crawler: AsyncWebCrawler,
    client: AsyncOpenAI,
    restaurant_name: str = "",
    cuisine_hint: str = "",
) -> MenuAnalysisResult:
    """End-to-end analysis for a single restaurant."""
    result = MenuAnalysisResult(
        google_place_id=google_place_id,
        website=website,
    )

    # Normalise URL
    if not website.startswith("http"):
        website = "https://" + website

    try:
        # 1. Discover menu page
        menu_url, homepage_md = await discover_menu_url(website, crawler)

        # 2. Extract menu content (includes PDF + image fallback)
        menu_md = ""
        menu_images = []
        if menu_url:
            result.menu_url = menu_url
            result.menu_found = True

            # Check if menu_url is the homepage (avoid re-crawling)
            menu_is_homepage = menu_url.rstrip("/").lower() == website.rstrip("/").lower()

            if menu_is_homepage:
                logger.info(f"  Menu is on homepage, using already-crawled content")
                menu_md = homepage_md
                pdf_results = await extract_pdfs_from_markdown(menu_md, menu_url)
                if pdf_results:
                    _, pdf_text = pdf_results[0]
                    menu_md += f"\n\n### PDF Menu\n{pdf_text[:5000]}"
                else:
                    menu_images = await download_menu_images(menu_md, menu_url)
            else:
                # Menu is on separate page, crawl it
                extracted_text, extracted_images = await extract_menu_content(menu_url, crawler)
                menu_md = extracted_text or ""
                menu_images = extracted_images

        # Combine homepage (for general info) + menu page
        combined = ""
        if homepage_md:
            combined += f"## Homepage Content\n{homepage_md[:5000]}\n\n"
        if menu_md:
            combined += f"## Menu Page Content\n{menu_md}\n\n"
            result.menu_markdown = menu_md

        # Always call the LLM — even with minimal content we can still
        # generate a description from the restaurant name + cuisine hint
        if not combined or len(combined.strip()) < 100:
            combined = (
                f"No website content could be extracted.\n"
                f"Restaurant name: {restaurant_name or 'Unknown'}\n"
                f"Known cuisine: {cuisine_hint or 'Unknown'}\n"
            )

        # 3. LLM analysis
        analysis = await analyse_with_llm(
            combined, client,
            restaurant_name=restaurant_name,
            cuisine_hint=cuisine_hint,
            menu_images=menu_images,
        )
        
        result.menu_url = analysis.get("menu_url", result.menu_url)
        result.restaurant_description = analysis.get("description", "")
        result.total_dishes = analysis.get("total_dishes", 0)
        result.confidence = analysis.get("confidence", "low")
        result.reccomended_dishes = analysis.get("reccomended_dishes", None)
        result.notes = analysis.get("notes", "")

        # 4. Compute dietary scores with the friendliness thresholds
        dietary_counts = analysis.get("dietary_counts", {})
        halal_mentioned = analysis.get("halal_mentioned", False)
        result.halal_mentioned = halal_mentioned

        # First pass: compute all non-halal scores
        pescatarian_pct = 0
        for req in DIETARY_REQUIREMENTS:
            if req == "halal":
                continue  # handle after we know pescatarian score
            count = dietary_counts.get(req, 0)
            pct = DietaryScore.compute_pct(count)
            if req == "pescatarian":
                pescatarian_pct = pct
            result.dietary_scores.append(DietaryScore(
                requirement=req,
                dish_count=count,
                friendliness_pct=pct,
            ))

        # Halal: 100% if mentioned anywhere on site, otherwise fallback to pescatarian score
        halal_count = dietary_counts.get("halal", 0)
        if halal_mentioned:
            halal_pct = 100
        else:
            halal_pct = pescatarian_pct
        # Append halal at the end (it's not in DIETARY_REQUIREMENTS list)
        result.dietary_scores.append(
            DietaryScore(
                requirement="halal",
                dish_count=halal_count,
                friendliness_pct=halal_pct,
            )
        )

    except Exception as e:
        logger.error(f"Pipeline error for {website}: {e}")
        result.error = str(e)

    return result


# ── Step 5: Batch Pipeline ────────────────────────────────────────────────────

async def run_batch_pipeline(
    restaurants: list[dict],
    concurrency: int = 3,
    xai_api_key: str = "",
) -> list[MenuAnalysisResult]:
    """
    Process multiple restaurants with controlled concurrency.

    Args:
        restaurants: list of dicts with 'website', 'google_place_id', 'name', 'cuisine' keys
        concurrency: max parallel crawls (be polite, keep this low)
        xai_api_key: xAI API key for Grok
    """
    api_key = xai_api_key or XAI_API_KEY
    client = AsyncOpenAI(api_key=api_key, base_url=XAI_BASE_URL)

    browser_config = BrowserConfig(
        headless=True,
        viewport_width=1280,
        viewport_height=800,
    )

    semaphore = asyncio.Semaphore(concurrency)
    results = []
    total = len(restaurants)
    counter = {"count": 0}  # Use dict to allow mutation in nested function

    async with AsyncWebCrawler(config=browser_config) as crawler:

        async def _process(restaurant: dict) -> MenuAnalysisResult:
            async with semaphore:
                website = restaurant.get("website", "")
                place_id = restaurant.get("google_place_id", "")
                name = restaurant.get("name", "")
                cuisine = restaurant.get("cuisine", "")

                if not website:
                    counter["count"] += 1
                    progress_logger.info(f"{counter['count']}/{total}: [no website] - Menu: ✗")
                    return MenuAnalysisResult(
                        google_place_id=place_id,
                        website="",
                        error="No website URL",
                    )

                result = await analyse_restaurant(
                    website, place_id, crawler, client,
                    restaurant_name=name,
                    cuisine_hint=cuisine,
                )

                counter["count"] += 1
                menu_status = "✓" if result.menu_found else "✗"
                progress_logger.info(f"{counter['count']}/{total}: {website} - Menu: {menu_status}")

                return result

        tasks = [_process(r) for r in restaurants]
        results = await asyncio.gather(*tasks, return_exceptions=False)

    return results


# ── Supabase Integration ─────────────────────────────────────────────────────

def fetch_locations_with_websites(
    supabase_url: str,
    supabase_key: str,
    limit: int | None = None,
    order_by: str = "user_ratings_total",
    ascending: bool = False,
    skip_processed: bool = True,
) -> list[dict]:
    """
    Fetch locations with websites from Supabase.
    Handles pagination automatically to fetch more than 1000 rows.

    Args:
        supabase_url: Supabase project URL
        supabase_key: Supabase service key or anon key
        limit: Maximum number of locations to fetch (None for all)
        order_by: Column to order by (default: user_ratings_total)
        ascending: Sort order (default: False for descending)
        skip_processed: If True, only fetch locations without menu_analysis_confidence (default: True)

    Returns:
        List of dicts with 'website', 'google_place_id', 'name', 'cuisine' keys
    """
    supabase: Client = create_client(supabase_url, supabase_key)

    # DIAGNOSTIC: Check total count of unprocessed locations
    if skip_processed:
        count_query = supabase.table("locations").select(
            "google_place_id", count="exact"
        ).not_.is_("website", "null").is_("menu_analysis_confidence", "null")
        count_response = count_query.execute()
        total_unprocessed = count_response.count if hasattr(count_response, 'count') else '?'
        print(f"[DIAGNOSTIC] Total unprocessed locations with websites: {total_unprocessed}")

    all_results = []
    batch_size = 1000  # Supabase default max
    offset = 0

    # If a specific limit is set and it's less than batch_size, use it
    if limit is not None and limit < batch_size:
        batch_size = limit

    while True:
        # Query locations table for records with non-null, non-empty websites
        query = supabase.table("locations").select(
            "website, google_place_id, name, cuisine"
        ).not_.is_("website", "null")

        # Skip locations that have already been processed (have menu_analysis_confidence)
        if skip_processed:
            query = query.is_("menu_analysis_confidence", "null")
            print(f"[DEBUG] Filtering for unprocessed locations (menu_analysis_confidence IS NULL)")
        else:
            print(f"[DEBUG] NOT filtering by processed status - will fetch all locations with websites")

        query = query.limit(batch_size)
        print(f"[DEBUG] Requesting batch_size: {batch_size}, offset: {offset}")

        # Add ordering if specified
        if order_by:
            query = query.order(order_by, desc=not ascending)

        # Add pagination
        query = query.range(offset, offset + batch_size - 1)

        response = query.execute()
        batch = response.data

        print(f"[DEBUG] Query returned {len(batch)} results")
        if batch:
            print(f"[DEBUG] First result: {batch[0]}")

        if not batch:
            # No more results
            print(f"[DEBUG] No more results found. Breaking pagination loop.")
            break

        all_results.extend(batch)
        print(f"Fetched batch: {len(batch)} rows (total so far: {len(all_results)})")

        # Check if we've reached the limit
        if limit is not None and len(all_results) >= limit:
            all_results = all_results[:limit]
            break

        # Check if we got fewer results than batch_size (last page)
        if len(batch) < batch_size:
            break

        offset += batch_size

    print(f"Got total response from Supabase: {len(all_results)} locations")
    logger.info(f"Fetched {len(all_results)} locations from Supabase")
    return all_results


def update_location_with_menu_analysis(
    supabase_url: str,
    supabase_key: str,
    result: MenuAnalysisResult,
) -> dict:
    """
    Update a location in Supabase with menu analysis results.

    Args:
        supabase_url: Supabase project URL
        supabase_key: Supabase service key or anon key
        result: MenuAnalysisResult object from analysis

    Returns:
        Dict with update status and response
    """
    supabase: Client = create_client(supabase_url, supabase_key)

    # Prepare update data
    update_data = {
        "menu": result.menu_url,
        "generated_summary": result.restaurant_description,
        "reccomended_dishes": result.reccomended_dishes,
        "menu_analysis_confidence": result.confidence,
    }

    # Remove None values to avoid overwriting with null
    update_data = {k: v for k, v in update_data.items() if v is not None}

    try:
        # Update location by google_place_id
        response = supabase.table("locations").update(update_data).eq(
            "google_place_id", result.google_place_id
        ).execute()

        logger.info(f"✓ Updated location {result.google_place_id} in Supabase")
        return {"success": True, "data": response.data}

    except Exception as e:
        logger.error(f"✗ Failed to update location {result.google_place_id}: {e}")
        return {"success": False, "error": str(e)}


def batch_update_locations_with_menu_analysis(
    supabase_url: str,
    supabase_key: str,
    results: list[MenuAnalysisResult],
) -> dict:
    """
    Update multiple locations in Supabase with menu analysis results.

    Args:
        supabase_url: Supabase project URL
        supabase_key: Supabase service key or anon key
        results: List of MenuAnalysisResult objects

    Returns:
        Dict with summary of updates (success_count, failed_count, errors)
    """
    success_count = 0
    failed_count = 0
    errors = []

    logger.info(f"Updating {len(results)} locations in Supabase...")

    for result in results:
        # Skip results with errors
        if result.error:
            logger.warning(f"Skipping {result.google_place_id} - has error: {result.error}")
            failed_count += 1
            errors.append({"google_place_id": result.google_place_id, "error": result.error})
            continue

        update_result = update_location_with_menu_analysis(supabase_url, supabase_key, result)

        if update_result["success"]:
            success_count += 1
        else:
            failed_count += 1
            errors.append({"google_place_id": result.google_place_id, "error": update_result["error"]})

    logger.info(f"Batch update complete: {success_count} succeeded, {failed_count} failed")

    return {
        "success_count": success_count,
        "failed_count": failed_count,
        "total": len(results),
        "errors": errors,
    }


def update_location_tags_with_scores(
    supabase_url: str,
    supabase_key: str,
    result: MenuAnalysisResult,
) -> dict:
    """
    Update location_tags table with dietary scores from menu analysis.

    Args:
        supabase_url: Supabase project URL
        supabase_key: Supabase service key or anon key
        result: MenuAnalysisResult object with dietary scores

    Returns:
        Dict with update status
    """
    supabase: Client = create_client(supabase_url, supabase_key)

    try:
        # Step 1: Get location_id from google_place_id
        location_response = supabase.table("locations").select("location_id").eq(
            "google_place_id", result.google_place_id
        ).execute()

        if not location_response.data:
            logger.error(f"✗ Location not found for google_place_id: {result.google_place_id}")
            return {"success": False, "error": "Location not found"}

        location_id = location_response.data[0]["location_id"]
        logger.info(f"Found location_id {location_id} for {result.google_place_id}")

        # Step 2: Prepare tag scores
        tags_to_upsert = []
        for dietary_score in result.dietary_scores:
            requirement = dietary_score.requirement
            tag_id = DIETARY_TAG_IDS.get(requirement)

            if not tag_id:
                logger.warning(f"No tag_id found for requirement: {requirement}")
                continue

            tags_to_upsert.append({
                "location_id": location_id,
                "tag_id": tag_id,
                "score": dietary_score.friendliness_pct,
                "source": "menu_analysis",
                "metadata": {
                    "dish_count": dietary_score.dish_count,
                    "total_dishes": result.total_dishes,
                    "confidence": result.confidence,
                    "menu_url": result.menu_url,
                }
            })

        if not tags_to_upsert:
            logger.warning(f"No tags to upsert for {result.google_place_id}")
            return {"success": True, "tags_updated": 0}

        # Step 3: Delete existing tags for this location (for these dietary tags)
        dietary_tag_ids = [t["tag_id"] for t in tags_to_upsert]
        supabase.table("location_tags").delete().eq("location_id", location_id).in_("tag_id", dietary_tag_ids).execute()

        # Step 4: Insert new tags
        response = supabase.table("location_tags").insert(tags_to_upsert).execute()

        logger.info(f"✓ Updated {len(tags_to_upsert)} dietary tags for location {location_id}")
        return {"success": True, "tags_updated": len(tags_to_upsert), "data": response.data}

    except Exception as e:
        logger.error(f"✗ Failed to update tags for {result.google_place_id}: {e}")
        return {"success": False, "error": str(e)}


def batch_update_location_tags_with_scores(
    supabase_url: str,
    supabase_key: str,
    results: list[MenuAnalysisResult],
) -> dict:
    """
    Update location_tags table for multiple locations with dietary scores.

    Args:
        supabase_url: Supabase project URL
        supabase_key: Supabase service key or anon key
        results: List of MenuAnalysisResult objects

    Returns:
        Dict with summary of updates
    """
    success_count = 0
    failed_count = 0
    total_tags_updated = 0
    errors = []

    logger.info(f"Updating location tags for {len(results)} locations...")

    for result in results:
        # Skip results with errors
        if result.error:
            logger.warning(f"Skipping {result.google_place_id} - has error: {result.error}")
            failed_count += 1
            continue

        update_result = update_location_tags_with_scores(supabase_url, supabase_key, result)

        if update_result["success"]:
            success_count += 1
            total_tags_updated += update_result.get("tags_updated", 0)
        else:
            failed_count += 1
            errors.append({"google_place_id": result.google_place_id, "error": update_result["error"]})

    logger.info(f"Batch tag update complete: {success_count} locations, {total_tags_updated} total tags updated")

    return {
        "success_count": success_count,
        "failed_count": failed_count,
        "total_tags_updated": total_tags_updated,
        "total": len(results),
        "errors": errors,
    }


async def process_single_restaurant(
    website: str,
    name: str = "",
    cuisine: str = "",
    google_place_id: str = "",
    xai_api_key: str = "",
    update_supabase: bool = False,
    supabase_url: str = "",
    supabase_key: str = "",
) -> MenuAnalysisResult:
    """
    Process a single restaurant manually (for testing or one-off analysis).

    Args:
        website: Restaurant website URL
        name: Restaurant name (optional)
        cuisine: Cuisine type (optional)
        google_place_id: Google Place ID (optional, required for Supabase updates)
        xai_api_key: xAI API key
        update_supabase: Whether to update Supabase with results
        supabase_url: Supabase URL (required if update_supabase=True)
        supabase_key: Supabase key (required if update_supabase=True)

    Returns:
        MenuAnalysisResult object
    """
    logger.info("=" * 70)
    logger.info("MANUAL MODE: Processing single restaurant")
    logger.info("=" * 70)
    logger.info(f"Website: {website}")
    logger.info(f"Name: {name or 'Not provided'}")
    logger.info(f"Cuisine: {cuisine or 'Not provided'}")

    # Create client
    api_key = xai_api_key or XAI_API_KEY
    client = AsyncOpenAI(api_key=api_key, base_url=XAI_BASE_URL)

    # Create browser config
    browser_config = BrowserConfig(
        headless=True,
        viewport_width=1280,
        viewport_height=800,
    )

    # Analyze the restaurant
    async with AsyncWebCrawler(config=browser_config) as crawler:
        result = await analyse_restaurant(
            website=website,
            google_place_id=google_place_id or f"manual_{website}",
            crawler=crawler,
            client=client,
            restaurant_name=name,
            cuisine_hint=cuisine,
        )

    # Print results
    print(f"\n{'='*70}")
    print(f"RESULTS FOR: {website}")
    print("=" * 70)
    print(f"Menu found: {result.menu_found}")
    if result.menu_url:
        print(f"Menu URL: {result.menu_url}")
    print(f"Description: {result.restaurant_description or 'N/A'}")
    print(f"Total dishes: {result.total_dishes}")
    print(f"Confidence: {result.confidence}")
    if result.reccomended_dishes:
        print(f"Recommended dishes: {result.reccomended_dishes}")

    if result.dietary_scores:
        print(f"\nDietary Scores:")
        for s in result.dietary_scores:
            bar = "█" * (s.friendliness_pct // 10)
            print(f"  {s.requirement:15s} {s.friendliness_pct:3d}% ({s.dish_count} dishes) {bar}")

    if result.notes:
        print(f"\nNotes: {result.notes}")

    if result.error:
        print(f"\n⚠ Error: {result.error}")

    # Update Supabase if requested
    if update_supabase:
        if not supabase_url or not supabase_key:
            logger.error("Supabase credentials required for updates")
        elif not google_place_id:
            logger.error("google_place_id required for Supabase updates")
        else:
            logger.info(f"\nUpdating Supabase...")

            # Update locations table
            location_result = update_location_with_menu_analysis(
                supabase_url=supabase_url,
                supabase_key=supabase_key,
                result=result,
            )

            # Update location_tags table
            tags_result = update_location_tags_with_scores(
                supabase_url=supabase_url,
                supabase_key=supabase_key,
                result=result,
            )

            if location_result["success"] and tags_result["success"]:
                print(f"✓ Successfully updated Supabase")
            else:
                print(f"⚠ Supabase update had issues - check logs")

    return result


async def process_and_update_locations(
    supabase_url: str,
    supabase_key: str,
    xai_api_key: str = "",
    limit: int | None = None,
    order_by: str = "user_ratings_total",
    ascending: bool = False,
    concurrency: int = 3,
    skip_processed: bool = True,
) -> dict:
    """
    Complete end-to-end pipeline: fetch locations, analyze menus, and update Supabase.

    Args:
        supabase_url: Supabase project URL
        supabase_key: Supabase service key or anon key
        xai_api_key: xAI API key for Grok model
        limit: Maximum number of locations to process (None for all)
        order_by: Column to order by when fetching locations
        ascending: If True, sort ascending (ASC); if False, sort descending (DESC)
        concurrency: Number of parallel crawls
        skip_processed: If True, only process locations without existing analysis (default: True)

    Returns:
        Dict with complete summary of the process
    """
    logger.info("=" * 70)
    logger.info("STARTING COMPLETE MENU ANALYSIS PIPELINE")
    logger.info("=" * 70)

    # Step 1: Fetch locations with websites
    logger.info(f"\n{'='*70}")
    logger.info("STEP 1: Fetching locations from Supabase")
    logger.info("=" * 70)

    restaurants = fetch_locations_with_websites(
        supabase_url=supabase_url,
        supabase_key=supabase_key,
        limit=limit,
        order_by=order_by,
        ascending=ascending,
        skip_processed=skip_processed,
    )


    if not restaurants:
        logger.error("No restaurants found with websites!")
        return {"error": "No restaurants found"}

    logger.info(f"✓ Fetched {len(restaurants)} restaurants")

    # Step 2: Analyze menus
    logger.info(f"\n{'='*70}")
    logger.info("STEP 2: Analyzing restaurant menus")
    logger.info("=" * 70)

    results = await run_batch_pipeline(
        restaurants=restaurants,
        concurrency=concurrency,
        xai_api_key=xai_api_key or XAI_API_KEY,
    )

    logger.info(f"✓ Completed analysis for {len(results)} restaurants")

    # Count successes
    successful_analyses = sum(1 for r in results if r.menu_found)
    logger.info(f"  - Successful: {successful_analyses}")
    logger.info(f"  - Failed/No menu: {len(results) - successful_analyses}")

    # Step 3: Update locations table
    logger.info(f"\n{'='*70}")
    logger.info("STEP 3: Updating locations table")
    logger.info("=" * 70)

    location_summary = batch_update_locations_with_menu_analysis(
        supabase_url=supabase_url,
        supabase_key=supabase_key,
        results=results,
    )

    logger.info(f"✓ Updated locations:")
    logger.info(f"  - Success: {location_summary['success_count']}")
    logger.info(f"  - Failed: {location_summary['failed_count']}")

    # Step 4: Update location_tags table
    logger.info(f"\n{'='*70}")
    logger.info("STEP 4: Updating location_tags table")
    logger.info("=" * 70)

    tags_summary = batch_update_location_tags_with_scores(
        supabase_url=supabase_url,
        supabase_key=supabase_key,
        results=results,
    )

    logger.info(f"✓ Updated location tags:")
    logger.info(f"  - Locations: {tags_summary['success_count']}")
    logger.info(f"  - Total tags: {tags_summary['total_tags_updated']}")
    logger.info(f"  - Failed: {tags_summary['failed_count']}")

    # Final summary
    logger.info(f"\n{'='*70}")
    logger.info("PIPELINE COMPLETE - SUMMARY")
    logger.info("=" * 70)
    logger.info(f"Restaurants fetched:      {len(restaurants)}")
    logger.info(f"Menus analyzed:           {len(results)}")
    logger.info(f"Successful analyses:      {successful_analyses}")
    logger.info(f"Locations updated:        {location_summary['success_count']}")
    logger.info(f"Location tags updated:    {tags_summary['success_count']}")
    logger.info(f"Total dietary tags added: {tags_summary['total_tags_updated']}")
    logger.info("=" * 70)

    return {
        "restaurants_fetched": len(restaurants),
        "menus_analyzed": len(results),
        "successful_analyses": successful_analyses,
        "location_updates": location_summary,
        "tag_updates": tags_summary,
        "results": results,
    }


# ── Example Usage ─────────────────────────────────────────────────────────────

async def main():
    """
    Menu analysis pipeline - supports batch mode and manual mode.
    """
    # Configuration from environment variables
    SUPABASE_URL = os.environ.get("SUPABASE_URL")
    SUPABASE_KEY = os.environ.get("SUPABASE_KEY")
    XAI_API_KEY_ENV = os.environ.get("XAI_API_KEY", "")

    # ═══════════════════════════════════════════════════════════════
    # MANUAL MODE: Test a single restaurant
    # ═══════════════════════════════════════════════════════════════
    # Uncomment this section to test a single restaurant manually:

    # result = await process_single_restaurant(
    #     website="http://yi-ban.co.uk/",
    #     name="Yi ban",
    #     cuisine="Chinese",
    #     google_place_id="ChIJ...",  # Optional
    #     xai_api_key=XAI_API_KEY_ENV,
    #     update_supabase=False,  # Set to True to update Supabase
    #     supabase_url=SUPABASE_URL,
    #     supabase_key=SUPABASE_KEY,
    # )
    # return  # Exit after manual mode

    # ═══════════════════════════════════════════════════════════════
    # BATCH MODE: Process multiple restaurants from Supabase
    # ═══════════════════════════════════════════════════════════════

    # Validate configuration
    if not SUPABASE_URL or not SUPABASE_KEY:
        print("Error: SUPABASE_URL and SUPABASE_KEY must be set")
        print('  export SUPABASE_URL="https://yourproject.supabase.co"')
        print('  export SUPABASE_KEY="your-key"')
        return
    
    print("Getting the locations")

    summary = await process_and_update_locations(
        supabase_url=SUPABASE_URL,
        supabase_key=SUPABASE_KEY,
        xai_api_key=XAI_API_KEY_ENV,
        limit=1000,  # Process 1000 at a time to respect rate limits
        order_by="user_ratings_total",
        ascending=False,
        concurrency=3,
        skip_processed=True,  # Skip locations already analyzed
    )

    # Print results
    for r in summary["results"]:
        print(f"\n{'='*60}")
        print(f"Restaurant: {r.website}")
        print(f"Menu: {r.menu_url if r.menu_found else 'Not found'}")
        print(f"Description: {r.restaurant_description or 'N/A'}")
        print(f"Dishes: {r.total_dishes} | Confidence: {r.confidence}")
        if r.reccomended_dishes:
            print(f"Recommended: {r.reccomended_dishes}")
        if r.dietary_scores:
            for s in r.dietary_scores:
                bar = "█" * (s.friendliness_pct // 10)
                print(f"  {s.requirement:15s} {s.friendliness_pct:3d}% {bar}")
        if r.error:
            print(f"Error: {r.error}")


if __name__ == "__main__":
    asyncio.run(main())