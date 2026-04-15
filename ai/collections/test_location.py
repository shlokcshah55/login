"""
Test script for fine-tuning the collections LLM prompt.

Usage:
    python test_location.py <location_id>

Shows the full system prompt sent to the LLM, the raw response, and the parsed result.
"""
import sys
import asyncio
import json
from dotenv import load_dotenv

load_dotenv()

from main import CollectionGenerator, COLLECTION_METADATA


async def test_location(location_id: int):
    gen = CollectionGenerator(user_id="test")

    result = gen.supabase.table("locations").select("*").eq("location_id", location_id).execute()
    if not result.data:
        print(f"No location found with id={location_id}")
        return
    location = result.data[0]

    print("=" * 60)
    print(f"RESTAURANT: {location.get('name', 'Unknown')} (id={location_id})")
    print("=" * 60)

    system_prompt = gen.build_system_prompt_for_location(location)
    print("\n--- SYSTEM PROMPT ---")
    print(system_prompt)

    user_msg = (
        "Which of the defined collections above does this restaurant belong to? "
        "Evaluate it against all 7 collections using the STRONG FIT criteria. "
        "Return only a valid JSON array of collection ID strings. "
        'Example: ["date_night", "grab_a_coffee"]. '
        "Return [] if it fits none. No markdown, no explanation."
    )
    print("\n--- USER MESSAGE ---")
    print(user_msg)

    # Call LLM and capture raw response
    response = await gen.client.chat.completions.create(
        model=gen.model,
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_msg},
        ],
        temperature=0.3,
        max_tokens=100,
    )
    raw_text = response.choices[0].message.content.strip()

    print("\n--- RAW LLM RESPONSE ---")
    print(raw_text)

    # Parse same way as main.py
    content = raw_text
    if content.startswith("```"):
        content = content.split("```")[1]
        if content.startswith("json"):
            content = content[4:]
        content = content.strip()

    try:
        parsed = json.loads(content)
        result_ids = [cid for cid in parsed if cid in COLLECTION_METADATA] if isinstance(parsed, list) else []
    except json.JSONDecodeError as e:
        print(f"\n[ERROR] Failed to parse JSON: {e}")
        result_ids = []

    print("\n--- PARSED COLLECTION IDs ---")
    print(result_ids if result_ids else "[] (no collections matched)")

    print("\n--- COLLECTION LABELS ---")
    if result_ids:
        for cid in result_ids:
            print(f"  {cid}: {COLLECTION_METADATA[cid]}")
    else:
        print("  (none)")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python test_location.py <location_id>")
        sys.exit(1)
    asyncio.run(test_location(int(sys.argv[1])))
