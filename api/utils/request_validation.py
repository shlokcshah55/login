"""
Request validation utilities for the TikTok processing API.
This module provides functions for validating request inputs.
"""
import re
import logging
from typing import Optional, Dict, Any, List
from urllib.parse import urlparse

# Configure logging
logger = logging.getLogger(__name__)

# TikTok URL patterns
TIKTOK_URL_PATTERNS = [
    r'^https?://(?:www\.)?tiktok\.com/@[\w.-]+/video/\d+',  # Standard TikTok URL
    r'^https?://(?:www\.)?tiktok\.com/t/[\w]+',            # Shortened TikTok URL
    r'^https?://vm\.tiktok\.com/[\w]+',                    # vm.tiktok.com URL
    r'^https?://(?:m\.)?tiktok\.com/v/\d+',                # Alternative format
]

def validate_tiktok_url(url: str) -> bool:
    """
    Validate that a string is a valid TikTok video URL.
    
    Args:
        url: The URL to validate
        
    Returns:
        True if the URL is a valid TikTok video URL, False otherwise
    """
    if not url or not isinstance(url, str):
        logger.warning(f"Invalid TikTok URL: {url} (not a string)")
        return False
    
    # Check URL against TikTok patterns
    for pattern in TIKTOK_URL_PATTERNS:
        if re.match(pattern, url):
            # Basic validation passed - now check if it's a well-formed URL
            try:
                parsed = urlparse(url)
                if not all([parsed.scheme, parsed.netloc]):
                    logger.warning(f"Invalid TikTok URL: {url} (missing scheme or netloc)")
                    return False
                return True
            except Exception as e:
                logger.warning(f"Error parsing URL {url}: {e}")
                return False
    
    # No patterns matched
    logger.warning(f"Invalid TikTok URL format: {url}")
    return False

def validate_location_data(location: Dict[str, Any]) -> bool:
    """
    Validate location data structure.
    
    Args:
        location: A dictionary containing location data
        
    Returns:
        True if the location data is valid, False otherwise
    """
    if not isinstance(location, dict):
        return False
    
    # Check for required fields
    required_fields = ["landmark", "location"]
    for field in required_fields:
        if field not in location or not location[field]:
            return False
    
    return True

def validate_batch_request(data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Validate and sanitize batch processing request data.
    
    Args:
        data: Dictionary containing request data
        
    Returns:
        Sanitized request data
    """
    sanitized = {}
    
    # Validate limit
    if "limit" in data:
        try:
            limit = int(data["limit"])
            # Cap limit at reasonable value
            sanitized["limit"] = min(max(1, limit), 50)
        except (ValueError, TypeError):
            # Default to 10 if invalid
            sanitized["limit"] = 10
    else:
        sanitized["limit"] = 10
    
    # Pass through user ID if present
    if "userId" in data and isinstance(data["userId"], str) and data["userId"]:
        sanitized["userId"] = data["userId"]
    
    return sanitized