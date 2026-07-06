"""
Stage 2 / Stage 5: LLM extraction of restaurant/venue candidates from text signals.

Called twice:
  - After cheap extraction (caption + thumbnail OCR)
  - After frame OCR if cheap extraction gave low confidence
"""
import json
import logging

from openai import OpenAI
from models import Candidate, URLMetadata

logger = logging.getLogger(__name__)


def extract_candidates(
    client: OpenAI,
    meta: URLMetadata,
    ocr_text: str = "",
) -> list[Candidate]:
    """
    Ask the LLM to extract restaurant/venue candidates from available text signals.
    Returns a list of Candidate objects — empty list on failure.
    """
    prompt = f"""You are a location extraction tool for a restaurant-saving app.
Your only job is to identify specific restaurant or venue names from social media post metadata
so they can be looked up in the Google Places API.

# Available signals
- Post title/caption: "{meta.title}"
- Description: "{meta.description}"
- Hashtags: {', '.join(f'#{h}' for h in meta.hashtags) if meta.hashtags else 'None'}
- Platform location tag: "{meta.location_tag or 'None'}"
- Spoken transcript (machine-generated subtitles): "{meta.transcript or 'None'}"
- OCR text from thumbnail/slides/frames: "{ocr_text or 'None'}"

# Extraction rules
1. Only extract specific named venues — not generic food terms like "best pasta" or "coffee spot"
2. When a location_tag names a specific venue (not just a city), always include it
3. Include neighbourhood or area when mentioned (improves Google Places matching)
4. Creators often SAY venue names that never appear in the caption — treat the transcript
   as a first-class source. It is machine-generated, so names may be phonetically garbled;
   normalise obvious errors when the intended name is clear (e.g. "dama ka" → "Dhamaka")
5. A venue name in OCR text that also appears in the caption is higher confidence than OCR alone
6. OCR text is noisy — venue names may have OCR errors (e.g. "0" for "O", missing letters);
   normalise obvious errors when the intended name is clear
7. Slideshow posts often list MANY venues (e.g. "top 5 Indian spots") — extract every one
8. Rate each candidate's source: caption | hashtag | transcript | thumbnail_ocr | slideshow_ocr | frame_ocr | location_tag
9. There may be zero or multiple venues — return all you find

# Output — JSON only, no markdown
{{
  "candidates": [
    {{
      "name": "Carbone",
      "area": "Greenwich Village, NYC",
      "search_query": "Carbone Greenwich Village NYC",
      "source": "caption",
      "reasoning": "Name explicitly in caption with neighbourhood"
    }}
  ]
}}

If no specific venues found: {{"candidates": []}}"""

    try:
        response = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[{"role": "user", "content": prompt}],
            response_format={"type": "json_object"},
            temperature=0,
        )
        data = json.loads(response.choices[0].message.content)
        return [
            Candidate(
                name=c.get("name", "").strip(),
                area=c.get("area") or None,
                search_query=c.get("search_query") or c.get("name", ""),
                source=c.get("source", "caption"),
                reasoning=c.get("reasoning", ""),
            )
            for c in data.get("candidates", [])
            if c.get("name", "").strip()
        ]
    except Exception as exc:
        logger.error("Candidate extraction failed: %s", exc)
        return []
