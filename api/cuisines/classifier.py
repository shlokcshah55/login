"""
Multi-Label Cuisine Classifier
==============================
Deterministic cuisine detection pipeline using multiple signals:
- Google Place types (high precision)
- Name tokens with cuisine indicators (high weight)
- Review summary explicit patterns (high weight)
- Reviews + review_summary keywords (medium weight)
- generated_summary (weak signal, suppressed if others exist)

Outputs:
- cuisine_primary: single best label for UI
- cuisine_scores_json: cuisine → score (0-1), only scores > 0.4

IMPORTANT: Only national/regional cuisines are scored.
Dietary labels (vegan/halal), venue types (pub/bar), and meal types 
(brunch/breakfast) are explicitly excluded from scoring.

Version: cuisine_v2
"""

import json
import re
import unicodedata
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional
from datetime import datetime, timezone

# ── Configuration ────────────────────────────────────────────────────────────

CUISINE_VERSION = "cuisine_v2"

# Score weights for different signal sources
WEIGHTS = {
    "google_types": 0.85,              # High precision from Google
    "name_cuisine_indicator": 0.70,    # Strong cuisine indicator in name (trattoria, taqueria)
    "name": 0.50,                      # Restaurant name keyword match
    "review_summary_explicit": 0.75,   # "This [CUISINE] restaurant" pattern
    "website": 0.40,                   # Website domain/path
    "menu_url": 0.40,                  # Menu URL tokens
    "reviews_high": 0.40,              # High-signal keyword in reviews
    "reviews_medium": 0.25,            # Medium-signal keyword in reviews
    "review_summary": 0.35,            # Review summary keyword match
    "generated_summary": 0.15,         # AI-generated summary (very weak)
}

# Minimum score threshold to include a cuisine
MIN_SCORE_THRESHOLD = 0.30

# Threshold for google_types to suppress weak signals
GOOGLE_TYPES_SUPPRESS_THRESHOLD = 0.80

# Fusion detection thresholds
FUSION_TOP1_SINGLE = 0.65    # If top1 >= this AND top2 <= 0.35 → single cuisine
FUSION_TOP2_THRESHOLD = 0.45  # Both cuisines must be >= this for fusion
FUSION_TOP1_MIN = 0.50        # Minimum top1 score for fusion consideration

# Maximum reviews to process
MAX_REVIEWS_TO_PROCESS = 10

# Name-based cuisine indicators (high precision patterns)
NAME_CUISINE_INDICATORS = {
    "trattoria": "Italian",
    "ristorante": "Italian",
    "osteria": "Italian",
    "pizzeria": "Italian",
    "taqueria": "Mexican",
    "cantina": "Mexican",
    "izakaya": "Japanese",
    "ramen": "Japanese",
    "sushi": "Japanese",
    "yakitori": "Japanese",
    "tandoori": "Indian",
    "dhaba": "Indian",
    "masala": "Indian",
    "biryani": "Indian",
    "pho": "Vietnamese",
    "banh mi": "Vietnamese",
    "bistro": "French",
    "brasserie": "French",
    "patisserie": "French",
    "taverna": "Greek",
    "souvlaki": "Greek",
    "gyros": "Greek",
    "kebab": "Middle Eastern",
    "shawarma": "Middle Eastern",
    "falafel": "Middle Eastern",
    "dim sum": "Chinese",
    "dumpling": "Chinese",
    "wok": "Chinese",
    "xi'an": "Chinese (Xi'an/Shaanxi)",
    "sichuan": "Chinese (Sichuan)",
    "szechuan": "Chinese (Sichuan)",
    "bbq": "American BBQ",
    "smokehouse": "American BBQ",
    "chippy": "British",
    "fish and chips": "British",
    "jerk": "Caribbean",
    "taco": "Mexican",
    "burrito": "Mexican",
    "dosa": "Indian (South Indian)",
    "curry": "Indian",
    "naan": "Indian",
    "tagine": "Moroccan",
    "khachapuri": "Georgian",
    "momo": "Nepalese",
    "poke": "Hawaiian",
    "injera": "Ethiopian",
}


# ── Data Classes ─────────────────────────────────────────────────────────────

@dataclass
class CuisineResult:
    """Result of cuisine detection for a location."""
    primary: Optional[str]
    scores_json: dict[str, float]
    version: str = CUISINE_VERSION
    detected_at: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())
    
    def to_db_update(self) -> dict:
        """Convert to dict suitable for database update."""
        return {
            "cuisine_primary": self.primary,
            "cuisine_scores_json": self.scores_json if self.scores_json else None,
        }


# ── Load Mappings ────────────────────────────────────────────────────────────

def _load_json(filename: str) -> dict:
    """Load JSON file from mappings directory."""
    script_dir = Path(__file__).parent
    mapping_path = script_dir / "mappings" / filename
    if not mapping_path.exists():
        raise FileNotFoundError(f"Mapping file not found: {mapping_path}")
    return json.loads(mapping_path.read_text())


# Load mappings at module level
_type_mapping_data = _load_json("type_to_cuisine.json")
_keyword_mapping_data = _load_json("keyword_to_cuisine.json")

TYPE_TO_CUISINE: dict[str, str] = _type_mapping_data["type_to_cuisine"]
IGNORED_TYPES: set[str] = set(_type_mapping_data["ignored_types"])
CUISINE_HIERARCHY: dict[str, str] = _type_mapping_data.get("cuisine_hierarchy", {})

KEYWORD_TO_CUISINE: dict[str, dict] = _keyword_mapping_data["keyword_to_cuisine"]
FUSION_PHRASES: list[str] = _keyword_mapping_data["fusion_phrases"]

# Build list of valid cuisine names for explicit pattern matching
VALID_CUISINES: set[str] = set(TYPE_TO_CUISINE.values()) | set(KEYWORD_TO_CUISINE.keys())


# ── Text Normalization ───────────────────────────────────────────────────────

def normalize_text(text: str) -> str:
    """Normalize text for matching: lowercase, remove accents, basic cleanup."""
    if not text:
        return ""
    text = text.lower()
    text = unicodedata.normalize('NFKD', text)
    text = ''.join(c for c in text if not unicodedata.combining(c))
    text = re.sub(r'[-_/\\|•·]', ' ', text)
    text = re.sub(r"[^\w\s']", ' ', text)
    text = re.sub(r'\s+', ' ', text).strip()
    return text


def extract_domain_path(url: str) -> str:
    """Extract domain and path from URL for keyword matching."""
    if not url:
        return ""
    url = re.sub(r'^https?://', '', url)
    url = re.sub(r'[?#].*$', '', url)
    url = re.sub(r'[./]', ' ', url)
    return normalize_text(url)


# ── Scoring Functions ────────────────────────────────────────────────────────

def _add_score(
    scores: dict[str, float],
    sources: dict[str, set[str]],
    cuisine: str,
    weight: float,
    source: str,
    max_score: float = 1.0
):
    """Add score for a cuisine, tracking the source."""
    if cuisine not in scores:
        scores[cuisine] = 0.0
        sources[cuisine] = set()
    
    scores[cuisine] = min(scores[cuisine] + weight, max_score)
    sources[cuisine].add(source)


def _check_name_cuisine_indicators(
    name: str,
    scores: dict[str, float],
    sources: dict[str, set[str]],
) -> bool:
    """Check for strong cuisine indicators in restaurant name using word boundaries."""
    if not name:
        return False
    
    normalized = normalize_text(name)
    found = False
    
    for indicator, cuisine in NAME_CUISINE_INDICATORS.items():
        if _word_match(indicator, normalized):
            _add_score(scores, sources, cuisine, WEIGHTS["name_cuisine_indicator"], "name_indicator")
            found = True
    
    return found


def _check_explicit_cuisine_pattern(
    text: str,
    scores: dict[str, float],
    sources: dict[str, set[str]],
) -> bool:
    """
    Check for explicit patterns like "this [CUISINE] restaurant" or 
    "[CUISINE] restaurant" in review_summary.
    
    These are very high confidence signals.
    """
    if not text:
        return False
    
    normalized = normalize_text(text)
    found = False
    
    for cuisine in VALID_CUISINES:
        # Skip regional variants for pattern matching, use base cuisine
        base_cuisine = cuisine.split("(")[0].strip() if "(" in cuisine else cuisine
        base_lower = normalize_text(base_cuisine)
        
        patterns = [
            rf'\bthis {re.escape(base_lower)} restaurant\b',
            rf'\bthis {re.escape(base_lower)} place\b',
            rf'\ba {re.escape(base_lower)} restaurant\b',
            rf'\ban {re.escape(base_lower)} restaurant\b',
            rf'\bthe {re.escape(base_lower)} restaurant\b',
            rf'\b{re.escape(base_lower)} restaurant\b',
            rf'\bauthentic {re.escape(base_lower)}\b',
            rf'\btraditional {re.escape(base_lower)}\b',
        ]
        
        for pattern in patterns:
            if re.search(pattern, normalized):
                _add_score(scores, sources, cuisine, WEIGHTS["review_summary_explicit"], "review_summary_explicit")
                found = True
                break
    
    return found


def _check_keywords_in_text(
    text: str,
    scores: dict[str, float],
    sources: dict[str, set[str]],
    source_name: str,
    high_weight: float,
    medium_weight: float,
) -> bool:
    """Check for cuisine keywords in text using word boundaries, update scores."""
    if not text:
        return False
    
    normalized = normalize_text(text)
    found_any = False
    
    for cuisine, keywords_dict in KEYWORD_TO_CUISINE.items():
        # Check high-signal keywords
        high_keywords = keywords_dict.get("high_signal", [])
        for keyword in high_keywords:
            if _word_match(keyword, normalized):
                _add_score(scores, sources, cuisine, high_weight, source_name)
                found_any = True
                break  # Only count once per cuisine per source
        
        # Check medium-signal keywords
        medium_keywords = keywords_dict.get("medium_signal", [])
        for keyword in medium_keywords:
            if _word_match(keyword, normalized):
                # Slightly lower weight for medium signal
                _add_score(scores, sources, cuisine, medium_weight * 0.7, source_name)
                found_any = True
                break
    
    return found_any


def _detect_fusion_phrase(text: str, source: str) -> bool:
    """
    Check if text contains explicit fusion language using word boundaries.
    Only returns True for real sources (not generated_summary).
    """
    if not text:
        return False
    
    # Don't trust fusion phrases from generated_summary
    if source == "generated_summary":
        return False
    
    normalized = normalize_text(text)
    for phrase in FUSION_PHRASES:
        if _word_match(phrase, normalized):
            return True
    return False


def _apply_hierarchy(
    scores: dict[str, float],
    sources: dict[str, set[str]]
):
    """Apply cuisine hierarchy: if child cuisine exists, ensure parent is also included."""
    for child, parent in CUISINE_HIERARCHY.items():
        if child in scores and parent not in scores:
            # Add parent with slightly lower score
            parent_score = scores[child] * 0.8
            if parent_score >= MIN_SCORE_THRESHOLD:
                scores[parent] = parent_score
                sources[parent] = sources[child].copy()
                sources[parent].add("hierarchy")


def _get_signal_source_count(sources: dict[str, set[str]]) -> int:
    """Count unique signal sources (excluding hierarchy and generated_summary)."""
    all_sources = set()
    for src_set in sources.values():
        all_sources.update(src_set)
    
    # Exclude weak/derived sources
    exclude = {"hierarchy", "generated_summary", "fusion_detection"}
    return len(all_sources - exclude)


def _word_match(pattern: str, text: str) -> bool:
    """Check if pattern matches text using word boundaries to avoid false positives."""
    # Escape special regex characters in the pattern
    escaped_pattern = re.escape(pattern)
    # Use word boundaries to match whole words only
    regex_pattern = rf'\b{escaped_pattern}\b'
    return bool(re.search(regex_pattern, text))


# ── Main Detection Function ──────────────────────────────────────────────────

def detect_cuisine(location_row: dict) -> CuisineResult:
    """
    Detect cuisines for a location using multiple signals.
    
    Args:
        location_row: Dict with keys like name, types, website, reviews, 
                      review_summary, generated_summary, menu_url, etc.
    
    Returns:
        CuisineResult with primary cuisine and scores.
    """
    scores: dict[str, float] = {}
    sources: dict[str, set[str]] = {}
    has_fusion_phrase = False
    google_types_cuisines: set[str] = set()
    
    # ── 1. Parse Google types (highest weight) ───────────────────────────────
    types_str = location_row.get("types", "") or ""
    if types_str:
        types_list = [t.strip().lower() for t in types_str.split(",")]
        for type_name in types_list:
            if type_name in IGNORED_TYPES:
                continue
            if type_name in TYPE_TO_CUISINE:
                cuisine = TYPE_TO_CUISINE[type_name]
                _add_score(scores, sources, cuisine, WEIGHTS["google_types"], "google_types")
                google_types_cuisines.add(cuisine)
    
    # ── 2. Check restaurant name for cuisine indicators ──────────────────────
    name = location_row.get("name", "") or ""
    if name:
        # First check strong indicators (trattoria, taqueria, etc.)
        _check_name_cuisine_indicators(name, scores, sources)
        
        # Then check general keywords
        _check_keywords_in_text(
            name, scores, sources, "name",
            WEIGHTS["name"], WEIGHTS["name"]
        )
        if _detect_fusion_phrase(name, "name"):
            has_fusion_phrase = True
    
    # ── 3. Check review_summary for explicit patterns ────────────────────────
    review_summary = location_row.get("review_summary", "") or ""
    if review_summary:
        # High-value explicit pattern detection
        _check_explicit_cuisine_pattern(review_summary, scores, sources)
        
        # Regular keyword matching
        _check_keywords_in_text(
            review_summary, scores, sources, "review_summary",
            WEIGHTS["review_summary"], WEIGHTS["review_summary"]
        )
        if _detect_fusion_phrase(review_summary, "review_summary"):
            has_fusion_phrase = True
    
    # ── 4. Check reviews ─────────────────────────────────────────────────────
    reviews = location_row.get("reviews", []) or []
    if isinstance(reviews, str):
        try:
            reviews = json.loads(reviews)
        except json.JSONDecodeError:
            reviews = []
    
    reviews_to_process = reviews[:MAX_REVIEWS_TO_PROCESS]
    review_texts = []
    for review in reviews_to_process:
        if isinstance(review, dict):
            text = review.get("text", "") or review.get("content", "") or ""
            if text:
                review_texts.append(text)
        elif isinstance(review, str):
            review_texts.append(review)
    
    combined_reviews = " ".join(review_texts)
    if combined_reviews:
        _check_keywords_in_text(
            combined_reviews, scores, sources, "reviews",
            WEIGHTS["reviews_high"], WEIGHTS["reviews_medium"]
        )
        if _detect_fusion_phrase(combined_reviews, "reviews"):
            has_fusion_phrase = True
    
    # ── 5. Check website URL ─────────────────────────────────────────────────
    website = location_row.get("website", "") or ""
    if website:
        website_text = extract_domain_path(website)
        _check_keywords_in_text(
            website_text, scores, sources, "website",
            WEIGHTS["website"], WEIGHTS["website"]
        )
    
    # ── 6. Check menu URL ────────────────────────────────────────────────────
    menu_url = location_row.get("menu_url", "") or location_row.get("menu", "") or ""
    if menu_url:
        menu_text = extract_domain_path(menu_url)
        _check_keywords_in_text(
            menu_text, scores, sources, "menu_url",
            WEIGHTS["menu_url"], WEIGHTS["menu_url"]
        )
    
    # ── 7. Check generated_summary (weak signal) ─────────────────────────────
    # Only use if we don't have 2+ other signal sources
    generated_summary = location_row.get("generated_summary", "") or ""
    signal_count = _get_signal_source_count(sources)
    
    if generated_summary and signal_count < 2:
        temp_scores: dict[str, float] = {}
        temp_sources: dict[str, set[str]] = {}
        _check_keywords_in_text(
            generated_summary, temp_scores, temp_sources, "generated_summary",
            WEIGHTS["generated_summary"], WEIGHTS["generated_summary"]
        )
        
        # Only add weak signals for new cuisines or to boost very low ones
        for cuisine, score in temp_scores.items():
            if cuisine not in scores:
                _add_score(scores, sources, cuisine, score, "generated_summary")
            elif scores[cuisine] < 0.25:
                _add_score(scores, sources, cuisine, score * 0.5, "generated_summary")
    
    # ── 8. Apply hierarchy (child → parent) ──────────────────────────────────
    _apply_hierarchy(scores, sources)
    
    # ── 9. Suppress weak signals if google_types is strong ───────────────────
    if google_types_cuisines:
        max_google_score = max(
            scores.get(c, 0) for c in google_types_cuisines
        )
        
        if max_google_score >= GOOGLE_TYPES_SUPPRESS_THRESHOLD:
            filtered_scores = {}
            filtered_sources = {}
            
            for cuisine, score in scores.items():
                cuisine_sources = sources.get(cuisine, set())
                
                # Keep if: from google_types, or has multiple sources, or high score
                has_google = "google_types" in cuisine_sources
                has_strong_signal = any(s in cuisine_sources for s in [
                    "name_indicator", "review_summary_explicit"
                ])
                has_multiple_sources = len(cuisine_sources - {"hierarchy", "generated_summary"}) >= 2
                
                if has_google or has_strong_signal or has_multiple_sources or score >= 0.50:
                    filtered_scores[cuisine] = score
                    filtered_sources[cuisine] = cuisine_sources
            
            scores = filtered_scores
            sources = filtered_sources
    
    # ── 10. Filter low scores ────────────────────────────────────────────────
    filtered_scores = {}
    filtered_sources = {}
    for cuisine, score in scores.items():
        cuisine_sources = sources.get(cuisine, set())
        if score >= MIN_SCORE_THRESHOLD or "google_types" in cuisine_sources:
            filtered_scores[cuisine] = score
            filtered_sources[cuisine] = cuisine_sources
    
    scores = filtered_scores
    sources = filtered_sources
    
    # ── 11. Fusion detection (only from real signals) ────────────────────────
    is_fusion = False
    sorted_cuisines = sorted(scores.items(), key=lambda x: x[1], reverse=True)
    
    if len(sorted_cuisines) >= 2:
        top1_cuisine, top1_score = sorted_cuisines[0]
        top2_cuisine, top2_score = sorted_cuisines[1]
        
        # Clear winner = no fusion
        if top1_score >= FUSION_TOP1_SINGLE and top2_score <= 0.35:
            is_fusion = False
        # Both scores strong = possible fusion
        elif top1_score >= FUSION_TOP1_MIN and top2_score >= FUSION_TOP2_THRESHOLD:
            # Only if both have real signal sources (not just generated_summary)
            top1_has_real = bool(sources.get(top1_cuisine, set()) - {"hierarchy", "generated_summary"})
            top2_has_real = bool(sources.get(top2_cuisine, set()) - {"hierarchy", "generated_summary"})
            
            if top1_has_real and top2_has_real:
                is_fusion = True
        
        # Explicit fusion phrase overrides (but not from generated_summary)
        if has_fusion_phrase and len(sorted_cuisines) >= 2:
            is_fusion = True
    
    # ── 12. Determine primary cuisine ────────────────────────────────────────
    primary = None
    if sorted_cuisines:
        non_fusion = [(c, s) for c, s in sorted_cuisines if c != "Fusion"]
        if non_fusion:
            if is_fusion and len(non_fusion) >= 2:
                top1, top1_score = non_fusion[0]
                top2, top2_score = non_fusion[1]
                
                # Prefer google_types if scores are close
                top2_has_google = "google_types" in sources.get(top2, set())
                top1_has_google = "google_types" in sources.get(top1, set())
                
                if top2_has_google and not top1_has_google and abs(top1_score - top2_score) < 0.15:
                    primary = top2
                else:
                    primary = top1
            else:
                primary = non_fusion[0][0]
    
    # ── 13. Filter scores to only > 0.4 for output ───────────────────────────
    filtered_scores_high = {
        k: round(v, 3) for k, v in scores.items() if v > 0.4
    }
    
    return CuisineResult(
        primary=primary,
        scores_json=filtered_scores_high,
    )


# ── Utility Functions ────────────────────────────────────────────────────────

def get_cuisine_version() -> str:
    """Get current cuisine detection version."""
    return CUISINE_VERSION


def get_available_cuisines() -> list[str]:
    """Get list of all valid cuisines in the mapping."""
    return sorted(VALID_CUISINES)
