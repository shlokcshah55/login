"""
Incremental Batch Vibe Tag Generator
=====================================
Processes restaurants in batches of 1000, designed to be run repeatedly.

Usage:
    # Process 1000 restaurants WITHOUT generated_summary (1 run each)
    python batch_vibe_tags.py --without-summary

    # Process 1000 restaurants WITH generated_summary (5 runs each)
    python batch_vibe_tags.py --with-summary

Run repeatedly until all restaurants are processed. The script automatically
skips restaurants that already have vibe_vector populated.
"""

import asyncio
import json
import os
import logging
import argparse
from pathlib import Path
from typing import Optional
from dotenv import load_dotenv
import statistics

from supabase import create_client, Client
from openai import AsyncOpenAI

# Load environment variables
load_dotenv()

# ── Configuration ────────────────────────────────────────────────────────────

XAI_API_KEY = os.getenv("XAI_API_KEY", "your-xai-api-key")
SUPABASE_URL = os.getenv("SUPABASE_URL", "https://your-supabase-url.supabase.co")
SUPABASE_KEY = os.getenv("SUPABASE_KEY", "your-supabase-key")
XAI_BASE_URL = "https://api.x.ai/v1"
MODEL = "grok-4-fast-non-reasoning"

# Vibe tags in predetermined order for vibe_vector array (matches valid_tag_prompt.md)
VIBE_TAGS_ORDERED = [
    "cafe", "casual", "cozy", "coffee_shop", "bar",
    "elegant", "fine_dining", "food_truck", "hole_in_the_wall", "late_night",
    "live_music", "modern", "fast_food", "romantic", "sports_bar",
    "takeout_friendly", "pub", "grocery_store", "brunch", "outdoor_dining",
    "wavy", "bossman"
]

BATCH_SIZE = 1000  # Supabase max per query

# Logging setup
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger(__name__)

# Get directory containing this script
SCRIPT_DIR = Path(__file__).parent

# ── Load Prompts ─────────────────────────────────────────────────────────────

def load_prompt(filename: str) -> str:
    """Load a prompt file from the vibe-tags directory."""
    prompt_path = SCRIPT_DIR / filename
    if not prompt_path.exists():
        raise FileNotFoundError(f"Prompt file not found: {prompt_path}")
    return prompt_path.read_text()

VALID_TAG_PROMPT = load_prompt("valid_tag_prompt.md")
VALID_TAG_SCORER = load_prompt("valid_tag_scorer.md")
INVALID_TAG_SCORER = load_prompt("invalid_tag_scorer.md")


# ── Helper Functions ─────────────────────────────────────────────────────────

async def call_llm(
    client: AsyncOpenAI,
    prompt: str,
    data: dict,
) -> dict:
    """Call the xAI Grok model with a prompt and data."""
    full_prompt = f"{prompt}\n\n# Input Data\n\n```json\n{json.dumps(data, indent=2)}\n```"

    response = await client.chat.completions.create(
        model=MODEL,
        max_tokens=2000,
        response_format={"type": "json_object"},
        messages=[
            {"role": "system", "content": "You are a restaurant analysis assistant. Always respond with valid JSON."},
            {"role": "user", "content": full_prompt},
        ],
    )

    raw = response.choices[0].message.content.strip()

    # Strip markdown fences if present
    import re
    raw = re.sub(r"^```(?:json)?\s*", "", raw)
    raw = re.sub(r"\s*```$", "", raw)

    try:
        return json.loads(raw)
    except json.JSONDecodeError as e:
        logger.error(f"Failed to parse LLM response: {raw[:200]}")
        raise e


async def analyze_restaurant_vibes(
    restaurant: dict,
    client: AsyncOpenAI,
) -> dict[str, float]:
    """Complete 3-stage analysis pipeline for a single restaurant."""
    # Stage 1: Identify relevant and irrelevant tags
    stage1_result = await call_llm(client, VALID_TAG_PROMPT, restaurant)
    relevant_tags = stage1_result.get("relevant_tags", [])
    irrelevant_tags = stage1_result.get("irrelevant_tags", [])

    # Stage 2: Score relevant tags
    stage2_input = {"restaurant_data": restaurant, "relevant_tags": relevant_tags}
    relevant_scores = await call_llm(client, VALID_TAG_SCORER, stage2_input)

    # Stage 3: Score irrelevant tags
    stage3_input = {"restaurant_data": restaurant, "irrelevant_tags": irrelevant_tags}
    irrelevant_scores = await call_llm(client, INVALID_TAG_SCORER, stage3_input)

    # Combine scores
    combined_scores = {**relevant_scores, **irrelevant_scores}

    # Ensure all tags are present (fill missing with 0)
    for tag in VIBE_TAGS_ORDERED:
        if tag not in combined_scores:
            combined_scores[tag] = 0.0

    return combined_scores


def scores_to_vibe_vector(scores: dict[str, float]) -> list[float]:
    """Convert score dict to ordered vibe_vector array."""
    return [float(scores.get(tag, 0.0)) for tag in VIBE_TAGS_ORDERED]


def update_vibe_vector(
    supabase_url: str,
    supabase_key: str,
    location_id: str,
    vibe_vector: list[float],
) -> dict:
    """Update the vibe_vector and mark updated_vibe as true."""
    supabase: Client = create_client(supabase_url, supabase_key)

    try:
        response = supabase.table("locations").update({
            "vibe_vector": vibe_vector,
            "updated_vibe": True
        }).eq("location_id", location_id).execute()

        return {"success": True, "data": response.data}

    except Exception as e:
        logger.error(f"✗ Failed to update location {location_id}: {e}")
        return {"success": False, "error": str(e)}


# ── Batch Processing Functions ──────────────────────────────────────────────

async def process_batch_without_summary(
    supabase_url: str,
    supabase_key: str,
    xai_api_key: str,
) -> dict:
    """
    Process one batch (up to 1000) of restaurants WITHOUT generated_summary.
    Runs analysis once per restaurant.

    Returns:
        Summary dict with stats
    """
    logger.info("=" * 70)
    logger.info("BATCH: Restaurants WITHOUT generated_summary (1 run each)")
    logger.info("=" * 70)

    supabase: Client = create_client(supabase_url, supabase_key)
    client = AsyncOpenAI(api_key=xai_api_key, base_url=XAI_BASE_URL)

    # Count total remaining (where updated_vibe is false or null)
    count_query = (supabase.table("locations").select("location_id", count="exact")
                   .is_("generated_summary", "null")
                   .or_("updated_vibe.is.null,updated_vibe.eq.false"))
    count_response = count_query.execute()
    total_remaining = count_response.count if hasattr(count_response, 'count') else 0

    logger.info(f"Total remaining restaurants: {total_remaining}")

    if total_remaining == 0:
        logger.info("✓ All restaurants without summary have been processed!")
        return {"total": 0, "success_count": 0, "failed_count": 0, "errors": [], "completed": True}

    # Fetch one batch (where updated_vibe is false or null)
    query = (supabase.table("locations").select("*")
             .is_("generated_summary", "null")
             .or_("updated_vibe.is.null,updated_vibe.eq.false")
             .limit(BATCH_SIZE))

    response = query.execute()
    batch = response.data

    logger.info(f"Processing batch of {len(batch)} restaurants...")

    success_count = 0
    failed_count = 0
    errors = []

    for idx, restaurant in enumerate(batch, 1):
        location_id = restaurant.get("location_id")
        name = restaurant.get("name", "Unknown")

        logger.info(f"[{idx}/{len(batch)}] {name}")

        try:
            # Run once
            scores = await analyze_restaurant_vibes(restaurant, client)
            vibe_vector = scores_to_vibe_vector(scores)

            # Update database
            result = update_vibe_vector(supabase_url, supabase_key, location_id, vibe_vector)

            if result["success"]:
                success_count += 1
                logger.info(f"  ✓ Updated")
            else:
                failed_count += 1
                errors.append({"location_id": location_id, "name": name, "error": result.get("error")})
                logger.error(f"  ✗ Failed: {result.get('error')}")

        except Exception as e:
            failed_count += 1
            errors.append({"location_id": location_id, "name": name, "error": str(e)})
            logger.error(f"  ✗ Error: {e}")

    remaining_after = total_remaining - success_count

    logger.info("=" * 70)
    logger.info(f"BATCH COMPLETE: {success_count} ✓, {failed_count} ✗")
    logger.info(f"Remaining: {remaining_after}")
    logger.info("=" * 70)

    return {
        "total": len(batch),
        "success_count": success_count,
        "failed_count": failed_count,
        "errors": errors,
        "remaining": remaining_after,
        "completed": remaining_after == 0,
    }


async def process_batch_with_summary(
    supabase_url: str,
    supabase_key: str,
    xai_api_key: str,
) -> dict:
    """
    Process one batch (up to 1000) of restaurants WITH generated_summary.
    Runs analysis 5 times per restaurant and uses mean scores.

    Returns:
        Summary dict with stats
    """
    logger.info("=" * 70)
    logger.info("BATCH: Restaurants WITH generated_summary (5 runs each)")
    logger.info("=" * 70)

    supabase: Client = create_client(supabase_url, supabase_key)
    client = AsyncOpenAI(api_key=xai_api_key, base_url=XAI_BASE_URL)

    # Count total remaining (where updated_vibe is false or null)
    count_query = (supabase.table("locations").select("location_id", count="exact")
                   .not_.is_("generated_summary", "null")
                   .or_("updated_vibe.is.null,updated_vibe.eq.false"))
    count_response = count_query.execute()
    total_remaining = count_response.count if hasattr(count_response, 'count') else 0

    logger.info(f"Total remaining restaurants: {total_remaining}")

    if total_remaining == 0:
        logger.info("✓ All restaurants with summary have been processed!")
        return {"total": 0, "success_count": 0, "failed_count": 0, "errors": [], "completed": True}

    # Fetch one batch (where updated_vibe is false or null)
    query = (supabase.table("locations").select("*")
             .not_.is_("generated_summary", "null")
             .or_("updated_vibe.is.null,updated_vibe.eq.false")
             .limit(BATCH_SIZE))

    response = query.execute()
    batch = response.data

    logger.info(f"Processing batch of {len(batch)} restaurants...")

    success_count = 0
    failed_count = 0
    errors = []

    for idx, restaurant in enumerate(batch, 1):
        location_id = restaurant.get("location_id")
        name = restaurant.get("name", "Unknown")

        logger.info(f"[{idx}/{len(batch)}] {name} (5 runs)")

        try:
            # Run 5 times and calculate mean
            all_scores = []

            for run_num in range(5):
                try:
                    scores = await analyze_restaurant_vibes(restaurant, client)
                    all_scores.append(scores)
                except Exception as e:
                    logger.warning(f"    Run {run_num + 1}/5 failed: {e}")
                    continue

            if not all_scores:
                raise Exception("All 5 runs failed")

            # Calculate mean scores
            mean_scores = {}
            for tag in VIBE_TAGS_ORDERED:
                tag_values = [scores.get(tag, 0.0) for scores in all_scores]
                mean_scores[tag] = statistics.mean(tag_values)

            mean_vibe_vector = scores_to_vibe_vector(mean_scores)

            # Update database
            result = update_vibe_vector(supabase_url, supabase_key, location_id, mean_vibe_vector)

            if result["success"]:
                success_count += 1
                logger.info(f"  ✓ Updated (mean of {len(all_scores)} runs)")
            else:
                failed_count += 1
                errors.append({"location_id": location_id, "name": name, "error": result.get("error")})
                logger.error(f"  ✗ Failed: {result.get('error')}")

        except Exception as e:
            failed_count += 1
            errors.append({"location_id": location_id, "name": name, "error": str(e)})
            logger.error(f"  ✗ Error: {e}")

    remaining_after = total_remaining - success_count

    logger.info("=" * 70)
    logger.info(f"BATCH COMPLETE: {success_count} ✓, {failed_count} ✗")
    logger.info(f"Remaining: {remaining_after}")
    logger.info("=" * 70)

    return {
        "total": len(batch),
        "success_count": success_count,
        "failed_count": failed_count,
        "errors": errors,
        "remaining": remaining_after,
        "completed": remaining_after == 0,
    }


# ── Main ─────────────────────────────────────────────────────────────────────

async def main():
    """Main entry point."""

    parser = argparse.ArgumentParser(
        description="Incremental batch vibe tag generator (processes 1000 at a time)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Process 1000 restaurants without summary (run repeatedly)
  python batch_vibe_tags.py --without-summary

  # Process 1000 restaurants with summary (run repeatedly)
  python batch_vibe_tags.py --with-summary

Run the script repeatedly until it reports all restaurants are processed.
The script automatically skips restaurants that already have vibe_vector.
        """
    )

    parser.add_argument(
        "--without-summary",
        action="store_true",
        help="Process restaurants WITHOUT generated_summary (1 run each)"
    )

    parser.add_argument(
        "--with-summary",
        action="store_true",
        help="Process restaurants WITH generated_summary (5 runs each)"
    )

    args = parser.parse_args()

    # Validate configuration
    supabase_url = os.environ.get("SUPABASE_URL")
    supabase_key = os.environ.get("SUPABASE_KEY")
    xai_api_key = os.environ.get("XAI_API_KEY")

    if not supabase_url or not supabase_key:
        print("Error: SUPABASE_URL and SUPABASE_KEY must be set")
        return

    if not xai_api_key:
        print("Error: XAI_API_KEY must be set")
        return

    # Determine mode
    if args.without_summary:
        summary = await process_batch_without_summary(
            supabase_url=supabase_url,
            supabase_key=supabase_key,
            xai_api_key=xai_api_key,
        )

        if summary.get("errors"):
            logger.error("\nErrors in this batch:")
            for error in summary["errors"]:
                logger.error(f"  - {error['name']} ({error['location_id']}): {error['error']}")

        if not summary.get("completed"):
            logger.info("\n⚠ More restaurants remaining. Run this script again to process next batch.")

    elif args.with_summary:
        summary = await process_batch_with_summary(
            supabase_url=supabase_url,
            supabase_key=supabase_key,
            xai_api_key=xai_api_key,
        )

        if summary.get("errors"):
            logger.error("\nErrors in this batch:")
            for error in summary["errors"]:
                logger.error(f"  - {error['name']} ({error['location_id']}): {error['error']}")

        if not summary.get("completed"):
            logger.info("\n⚠ More restaurants remaining. Run this script again to process next batch.")

    else:
        parser.print_help()
        print("\nError: You must specify either --without-summary or --with-summary")


if __name__ == "__main__":
    asyncio.run(main())
