"""
Stage 5 / Stage 8: Confidence scoring.

Scores each (Candidate, ResolvedPlace) pair on five dimensions
and produces an overall score in [0, 1] plus a tier label.

Tier thresholds:
  high   >= 0.75  → auto-save
  medium >= 0.40  → ask user to confirm
  low     < 0.40  → save post as pending
"""
import re
import logging
from difflib import SequenceMatcher

from models import Candidate, ResolvedPlace, EvidenceFlags, ConfidenceResult

logger = logging.getLogger(__name__)

# Weights must sum to 1.0
_WEIGHTS = {
    "name_similarity": 0.40,
    "area_match":      0.25,
    "category_match":  0.15,
    "caption_support": 0.12,
    "ocr_support":     0.08,
}

_HIGH_THRESHOLD   = 0.75
_MEDIUM_THRESHOLD = 0.40

# Google Places types that indicate a food/drink venue
_FOOD_TYPES = frozenset({
    "restaurant", "food", "cafe", "bar", "bakery",
    "meal_takeaway", "meal_delivery", "night_club",
    "food_and_drink", "coffee_shop",
})


def _normalise(s: str) -> str:
    return re.sub(r"[^a-z0-9\s]", "", s.lower()).strip()


def _name_similarity(candidate_name: str, place_name: str) -> float:
    """Fuzzy string similarity between the extracted name and the Places result."""
    a = _normalise(candidate_name)
    b = _normalise(place_name)
    if not a or not b:
        return 0.0
    # Exact substring match gets a high score
    if a in b or b in a:
        return min(1.0, 0.85 + 0.15 * (min(len(a), len(b)) / max(len(a), len(b))))
    return SequenceMatcher(None, a, b).ratio()


def _area_match(candidate: Candidate, place: ResolvedPlace) -> float:
    """
    Score how well the candidate's area hint matches the place address.
    Returns 0 when no area hint is given (neutral, not penalising).
    """
    if not candidate.area:
        return 0.0
    area_norm = _normalise(candidate.area)
    address_norm = _normalise(place.address)
    words = [w for w in area_norm.split() if len(w) > 3]
    if not words:
        return 0.0
    hits = sum(1 for w in words if w in address_norm)
    return min(1.0, hits / len(words))


def _category_match(place: ResolvedPlace) -> float:
    """Returns 1.0 when the Place type is food/drink, 0.3 otherwise."""
    place_types = {t.lower().replace(" ", "_") for t in place.types}
    if place_types & _FOOD_TYPES:
        return 1.0
    return 0.3


def score(
    candidate: Candidate,
    place: ResolvedPlace,
    evidence: EvidenceFlags,
) -> ConfidenceResult:
    """Compute a ConfidenceResult for a single (candidate, place) pair."""
    name_sim  = _name_similarity(candidate.name, place.name)
    area_m    = _area_match(candidate, place)
    cat_m     = _category_match(place)
    cap_sup   = 1.0 if evidence.caption else 0.0
    # Media-derived text: OCR of any kind, or the platform's subtitle transcript
    ocr_sup   = 1.0 if (evidence.thumbnail_ocr or evidence.frame_ocr
                        or evidence.slideshow_ocr or evidence.subtitles) else 0.0

    overall = (
        name_sim  * _WEIGHTS["name_similarity"] +
        area_m    * _WEIGHTS["area_match"] +
        cat_m     * _WEIGHTS["category_match"] +
        cap_sup   * _WEIGHTS["caption_support"] +
        ocr_sup   * _WEIGHTS["ocr_support"]
    )
    overall = round(min(1.0, max(0.0, overall)), 4)

    if overall >= _HIGH_THRESHOLD:
        tier = "high"
    elif overall >= _MEDIUM_THRESHOLD:
        tier = "medium"
    else:
        tier = "low"

    return ConfidenceResult(
        overall=overall,
        tier=tier,
        name_similarity=name_sim,
        area_match=area_m,
        category_match=cat_m,
    )
