"""
Cuisine Classification Module
=============================
Multi-label cuisine classification for restaurant locations.

Usage:
    from cuisines import detect_cuisine
    
    result = detect_cuisine({
        "name": "Xi'an Impression",
        "types": "chinese_restaurant,restaurant,food",
        "reviews": [...],
    })
    
    print(result.primary)      # "Chinese (Xi'an/Shaanxi)"
    print(result.labels)       # ["Chinese", "Chinese (Xi'an/Shaanxi)"]
    print(result.confidence)   # "high"

For batch processing:
    python batch_backfill.py --help
"""

from classifier import (
    detect_cuisine,
    CuisineResult,
    get_cuisine_version,
    get_available_cuisines,
    normalize_text,
    CUISINE_VERSION,
)

__all__ = [
    "detect_cuisine",
    "CuisineResult",
    "get_cuisine_version",
    "get_available_cuisines",
    "normalize_text",
    "CUISINE_VERSION",
]

__version__ = CUISINE_VERSION
