"""
Insight extraction — runs after a place is resolved.

Extracts key dishes, special offers, vibe signals, sentiment, and a
creator note from the post metadata. These are stored in video_insights
and are bonus enrichment — they never block the save flow.

Adapted from the original tiktok-processor/processor.py extraction calls.
"""
import json
import logging
from pathlib import Path

from openai import OpenAI

from models import URLMetadata

logger = logging.getLogger(__name__)

_SCRIPT_DIR = Path(__file__).resolve().parent


def _venue_scope(place_name: str | None) -> str:
    if not place_name:
        return ""
    return f"""
# Venue scope — IMPORTANT
This post may mention multiple venues. Extract insights for ONE venue only: "{place_name}".
Only include content clearly attributable to "{place_name}". If something belongs to a
different venue, or you cannot tell which venue it refers to, DO NOT include it.
"""


def extract_factual_insights(client: OpenAI, meta: URLMetadata, place_name: str | None = None) -> dict:
    """
    Extract key dishes and special offers explicitly mentioned in the post,
    scoped to a single venue when place_name is given.
    Requires verbatim evidence — returns empty arrays rather than guessing.
    """
    prompt = f"""You are a factual claim extractor for a restaurant-discovery app.
Find specific dishes and special offers EXPLICITLY mentioned in this social media post.
{_venue_scope(place_name)}

# Source data
- Title/Caption: "{meta.title}"
- Description: "{meta.description}"
- Hashtags: {', '.join(f'#{h}' for h in meta.hashtags) if meta.hashtags else 'None'}
- Spoken transcript (machine-generated subtitles): "{meta.transcript or 'None'}"

For every item you extract you MUST include an "evidence" field with the verbatim quote
that supports it. If you cannot find a direct quote, omit the item entirely.
Return empty arrays rather than fabricating claims.
The spoken transcript counts as a valid evidence source — creators usually describe dishes
aloud rather than in the caption. It is machine-generated, so dish names may be slightly
garbled; normalise only when the intended name is obvious.

# Output — JSON only
{{
  "key_dishes": [
    {{"evidence": "the spicy rigatoni here is literally the best pasta in NYC", "name": "Spicy Rigatoni", "description": "Creator favourite"}}
  ],
  "special_offers": [
    {{"evidence": "mention this video at the door and get a free dessert", "offer": "Free dessert on mention", "valid_until": null, "code": null}}
  ]
}}

If nothing to extract: {{"key_dishes": [], "special_offers": []}}"""

    try:
        response = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[{"role": "user", "content": prompt}],
            response_format={"type": "json_object"},
            temperature=0,
        )
        data = json.loads(response.choices[0].message.content)
        return {
            "key_dishes": data.get("key_dishes") or [],
            "special_offers": data.get("special_offers") or [],
        }
    except Exception as exc:
        logger.error("Factual insight extraction failed: %s", exc)
        return {"key_dishes": [], "special_offers": []}


def extract_interpretive_signals(client: OpenAI, meta: URLMetadata, place_name: str | None = None) -> dict:
    """
    Extract vibe scores, overall sentiment, and a creator summary note,
    scoped to a single venue when place_name is given.
    These are impression-based, not factual, so no evidence quoting required.
    """
    vibe_tags_list = ""
    vibe_path = _SCRIPT_DIR / "vibe_table.txt"
    if vibe_path.exists():
        vibe_tags_list = vibe_path.read_text().strip()

    prompt = f"""You are an atmosphere and sentiment analyser for a restaurant-discovery app.
Given social media post metadata about a venue, extract:
1. vibe_signals — scored impressions of the venue's atmosphere
2. sentiment — the creator's overall tone
3. creator_notes — a short summary of the creator's take (1–2 sentences)
{_venue_scope(place_name)}

# Source data
- Title/Caption: "{meta.title}"
- Description: "{meta.description}"
- Hashtags: {', '.join(f'#{h}' for h in meta.hashtags) if meta.hashtags else 'None'}
- Spoken transcript (machine-generated subtitles): "{meta.transcript or 'None'}"

The spoken transcript is usually the richest signal for atmosphere and the creator's
genuine opinion — weight it strongly when present.

# Vibe vocabulary (use ONLY these tags)
{vibe_tags_list}

Score each vibe 0.0–1.0. Only include vibes with clear evidence — typically 2–5.

# Output — JSON only
{{
  "vibe_signals": {{"romantic": 0.8, "elegant": 0.7}},
  "sentiment": "positive",
  "creator_notes": "A go-to date spot with impeccable pasta."
}}"""

    try:
        response = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[{"role": "user", "content": prompt}],
            response_format={"type": "json_object"},
            temperature=0,
        )
        data = json.loads(response.choices[0].message.content)
        return {
            "vibe_signals": data.get("vibe_signals") or {},
            "sentiment": data.get("sentiment"),
            "creator_notes": data.get("creator_notes"),
        }
    except Exception as exc:
        logger.error("Interpretive signal extraction failed: %s", exc)
        return {"vibe_signals": {}, "sentiment": None, "creator_notes": None}


def extract_all_insights(client: OpenAI, meta: URLMetadata, place_name: str | None = None) -> dict:
    """Convenience wrapper — returns merged dict of factual + interpretive signals for one venue."""
    factual = extract_factual_insights(client, meta, place_name)
    interpretive = extract_interpretive_signals(client, meta, place_name)
    return {**factual, **interpretive}
