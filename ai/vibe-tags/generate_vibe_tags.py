"""
Restaurant Vibe Tag Generator
==============================
Uses xAI Grok to analyze restaurant data and generate vibe tag scores.

This script:
1. Fetches all restaurants from Supabase
2. Analyzes each restaurant using a 3-stage LLM pipeline:
   - Stage 1: Identify relevant and irrelevant tags with evidence
   - Stage 2: Score relevant tags (0-100) based on evidence strength
   - Stage 3: Score irrelevant tags (0-100) to catch any missed evidence
3. Combines scores and updates vibe_vector in Supabase

Usage:
    python generate_vibe_tags.py
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

# Vibe tags in predetermined order for vibe_vector array
VIBE_TAGS_ORDERED = [
    "cafe", "casual", "cozy", "coffee_shop", "bar",
    "elegant", "fine_dining", "food_truck", "hole_in_the_wall", "late_night",
    "live_music", "modern", "fast_food", "romantic", "sports_bar",
    "takeout_friendly", "pub", "grocery_store", "brunch", "outdoor_dining",
    "wavy", "bossman"
]

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


# ── Supabase Functions ───────────────────────────────────────────────────────

def fetch_all_restaurants(
    supabase_url: str,
    supabase_key: str,
    limit: Optional[int] = None,
) -> list[dict]:
    """
    Fetch all restaurants from the locations table.

    Args:
        supabase_url: Supabase project URL
        supabase_key: Supabase service key
        limit: Optional limit on number of restaurants to fetch

    Returns:
        List of restaurant records (all columns)
    """
    supabase: Client = create_client(supabase_url, supabase_key)

    all_results = []
    batch_size = 1000
    offset = 0

    logger.info(f"Fetching restaurants from Supabase...")

    for i in range(1):
        query = supabase.table("locations").select("*").limit(2)

        # Add limit if specified
        if limit is not None and offset + batch_size > limit:
            batch_size = limit - offset

        query = query.limit(batch_size).range(offset, offset + batch_size - 1)

        response = query.execute()
        batch = response.data

        if not batch:
            break

        all_results.extend(batch)
        logger.info(f"Fetched batch: {len(batch)} restaurants (total: {len(all_results)})")

        if limit is not None and len(all_results) >= limit:
            all_results = all_results[:limit]
            break

        if len(batch) < batch_size:
            break

        offset += batch_size

    logger.info(f"Total restaurants fetched: {len(all_results)}")
    return all_results


def update_vibe_vector(
    supabase_url: str,
    supabase_key: str,
    location_id: str,
    vibe_vector: list[float],
) -> dict:
    """
    Update the vibe_vector and mark updated_vibe as true.

    Args:
        supabase_url: Supabase project URL
        supabase_key: Supabase service key
        location_id: The location_id to update
        vibe_vector: Array of 22 float scores in predetermined order

    Returns:
        Dict with success status
    """
    supabase: Client = create_client(supabase_url, supabase_key)

    try:
        response = supabase.table("locations").update({
            "vibe_vector": vibe_vector,
            "updated_vibe": True
        }).eq("location_id", location_id).execute()

        logger.debug(f"✓ Updated vibe_vector for location {location_id}")
        return {"success": True, "data": response.data}

    except Exception as e:
        logger.error(f"✗ Failed to update location {location_id}: {e}")
        return {"success": False, "error": str(e)}


# ── LLM Analysis Pipeline ────────────────────────────────────────────────────

async def call_llm(
    client: AsyncOpenAI,
    prompt: str,
    data: dict,
) -> dict:
    """
    Call the xAI Grok model with a prompt and data.

    Args:
        client: AsyncOpenAI client
        prompt: The prompt template
        data: Data to include in the prompt

    Returns:
        Parsed JSON response
    """
    # Format prompt with data
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
    """
    Complete 3-stage analysis pipeline for a single restaurant.

    Args:
        restaurant: Complete restaurant record from Supabase
        client: AsyncOpenAI client

    Returns:
        Dict mapping tag names to scores (0-100)
    """
    logger.info(f"Analyzing: {restaurant.get('name', 'Unknown')} ({restaurant.get('location_id', 'no-id')})")

    # Stage 1: Identify relevant and irrelevant tags
    logger.info("  Stage 1: Identifying relevant/irrelevant tags...")
    stage1_result = await call_llm(client, VALID_TAG_PROMPT, restaurant)

    relevant_tags = stage1_result.get("relevant_tags", [])
    irrelevant_tags = stage1_result.get("irrelevant_tags", [])

    logger.info(f"    Found {len(relevant_tags)} relevant, {len(irrelevant_tags)} irrelevant tags")

    # Log relevant tags with their evidence
    if relevant_tags:
        logger.info("    Relevant tags:")
        for item in relevant_tags:
            tag = item.get("tag", "unknown")
            evidence = item.get("evidence", "no evidence provided")
            logger.info(f"      • {tag:20s} → {evidence}")

    # Log irrelevant tags with their reasons
    if irrelevant_tags:
        logger.info("    Irrelevant tags (sample):")
        # Show first 5 to avoid too much output, or all if debug mode
        sample_size = 5 if logger.level == logging.INFO else len(irrelevant_tags)
        for item in irrelevant_tags[:sample_size]:
            tag = item.get("tag", "unknown")
            reason = item.get("reason", "no reason provided")
            logger.info(f"      • {tag:20s} → {reason}")
        if len(irrelevant_tags) > sample_size:
            logger.info(f"      ... and {len(irrelevant_tags) - sample_size} more")

    # Stage 2: Score relevant tags
    logger.info("  Stage 2: Scoring relevant tags...")
    stage2_input = {
        "restaurant_data": restaurant,
        "relevant_tags": relevant_tags,
    }
    relevant_scores = await call_llm(client, VALID_TAG_SCORER, stage2_input)
    logger.info(f"    Scored {len(relevant_scores)} relevant tags")

    # Stage 3: Score irrelevant tags
    logger.info("  Stage 3: Scoring irrelevant tags...")
    stage3_input = {
        "restaurant_data": restaurant,
        "irrelevant_tags": irrelevant_tags,
    }
    irrelevant_scores = await call_llm(client, INVALID_TAG_SCORER, stage3_input)
    logger.info(f"    Scored {len(irrelevant_scores)} irrelevant tags")

    # Combine scores
    combined_scores = {**relevant_scores, **irrelevant_scores}

    # Ensure all 21 tags are present (fill missing with 0)
    for tag in VIBE_TAGS_ORDERED:
        if tag not in combined_scores:
            combined_scores[tag] = 0.0

    # Log individual tag scores
    logger.info(f"  ✓ Analysis complete. Total points: {sum(combined_scores.values()):.0f}")
    logger.info(f"  Tag scores:")

    # Show scores sorted by value (highest first) for readability
    sorted_scores = sorted(combined_scores.items(), key=lambda x: -x[1])
    for tag, score in sorted_scores:
        if score > 0:  # Only show non-zero scores
            logger.info(f"    {tag:20s} = {score:3.0f}")

    return combined_scores


def scores_to_vibe_vector(scores: dict[str, float]) -> list[float]:
    """
    Convert score dict to ordered vibe_vector array.

    Args:
        scores: Dict mapping tag names to scores

    Returns:
        List of 21 floats in predetermined order
    """
    return [float(scores.get(tag, 0.0)) for tag in VIBE_TAGS_ORDERED]


def format_vibe_vector_readable(vibe_vector: list[float]) -> str:
    """
    Format vibe_vector as a readable string with tag names.

    Args:
        vibe_vector: List of 21 scores

    Returns:
        Formatted string showing tag=score pairs
    """
    pairs = [f"{tag}={score:.0f}" for tag, score in zip(VIBE_TAGS_ORDERED, vibe_vector) if score > 0]
    return "[" + ", ".join(pairs) + "]"


# ── Batch Processing Functions ──────────────────────────────────────────────

async def process_with_multiple_runs(
    restaurant: dict,
    client: AsyncOpenAI,
    num_runs: int = 3,
) -> tuple[dict[str, float], list[float]]:
    """
    Process a restaurant with multiple runs and return mean scores.

    Args:
        restaurant: Restaurant data from Supabase
        client: AsyncOpenAI client
        num_runs: Number of runs to average

    Returns:
        Tuple of (mean_scores_dict, mean_vibe_vector)
    """
    all_scores = []

    for run_num in range(num_runs):
        try:
            scores = await analyze_restaurant_vibes(restaurant, client)
            all_scores.append(scores)
        except Exception as e:
            logger.warning(f"    Run {run_num + 1}/{num_runs} failed: {e}")
            continue

    if not all_scores:
        raise Exception("All runs failed")

    # Calculate mean scores
    mean_scores = {}
    for tag in VIBE_TAGS_ORDERED:
        tag_values = [scores.get(tag, 0.0) for scores in all_scores]
        mean_scores[tag] = statistics.mean(tag_values)

    mean_vibe_vector = scores_to_vibe_vector(mean_scores)

    logger.info(f"    ✓ Completed {len(all_scores)}/{num_runs} runs, using mean scores")
    return mean_scores, mean_vibe_vector


async def process_restaurants_with_summary(
    supabase_url: str,
    supabase_key: str,
    xai_api_key: str,
    batch_size: int = 1000,
) -> dict:
    """
    Process all restaurants that HAVE generated_summary with 3 runs (mean scores).

    Args:
        supabase_url: Supabase project URL
        supabase_key: Supabase service key
        xai_api_key: xAI API key
        batch_size: Number of restaurants per batch

    Returns:
        Summary dict with processing stats
    """
    logger.info("=" * 70)
    logger.info("PROCESSING RESTAURANTS WITH GENERATED_SUMMARY (3 runs each)")
    logger.info("=" * 70)

    supabase: Client = create_client(supabase_url, supabase_key)
    client = AsyncOpenAI(api_key=xai_api_key, base_url=XAI_BASE_URL)

    # Count total restaurants with generated_summary and not yet processed
    count_query = (supabase.table("locations").select("location_id", count="exact")
                   .not_.is_("generated_summary", "null")
                   .or_("updated_vibe.is.null,updated_vibe.eq.false"))
    count_response = count_query.execute()
    total_count = count_response.count if hasattr(count_response, 'count') else 0
    logger.info(f"Total restaurants with generated_summary (not yet processed): {total_count}")

    success_count = 0
    failed_count = 0
    errors = []
    processed_count = 0
    offset = 0

    while True:
        # Fetch batch (only unprocessed restaurants)
        logger.info(f"\nFetching batch {offset // batch_size + 1} (offset: {offset})...")
        query = (supabase.table("locations").select("*")
                 .not_.is_("generated_summary", "null")
                 .or_("updated_vibe.is.null,updated_vibe.eq.false"))
        query = query.limit(batch_size).range(offset, offset + batch_size - 1)

        response = query.execute()
        batch = response.data

        if not batch:
            logger.info("No more restaurants to process")
            break

        logger.info(f"Processing batch of {len(batch)} restaurants...")

        # Process each restaurant in the batch
        for idx, restaurant in enumerate(batch, 1):
            location_id = restaurant.get("location_id")
            name = restaurant.get("name", "Unknown")

            processed_count += 1
            logger.info(f"[{processed_count}/{total_count}] {name} (3 runs)")

            try:
                # Run 3 times and get mean scores
                mean_scores, mean_vibe_vector = await process_with_multiple_runs(
                    restaurant, client, num_runs=3
                )

                # Update database with mean scores
                result = update_vibe_vector(supabase_url, supabase_key, location_id, mean_vibe_vector)

                if result["success"]:
                    success_count += 1
                    logger.info(f"    ✓ Updated vibe_vector (mean of 3 runs)")
                else:
                    failed_count += 1
                    errors.append({"location_id": location_id, "name": name, "error": result.get("error")})
                    logger.error(f"    ✗ Failed to update: {result.get('error')}")

            except Exception as e:
                failed_count += 1
                errors.append({"location_id": location_id, "name": name, "error": str(e)})
                logger.error(f"    ✗ Error: {e}")

        # Move to next batch
        if len(batch) < batch_size:
            break
        offset += batch_size

    logger.info("=" * 70)
    logger.info(f"WITH SUMMARY COMPLETE: {success_count} succeeded, {failed_count} failed")
    logger.info("=" * 70)

    return {
        "category": "with_summary",
        "total": processed_count,
        "success_count": success_count,
        "failed_count": failed_count,
        "errors": errors,
    }


async def process_restaurants_without_summary(
    supabase_url: str,
    supabase_key: str,
    xai_api_key: str,
    batch_size: int = 1000,
) -> dict:
    """
    Process all restaurants that DON'T HAVE generated_summary with 1 run.

    Args:
        supabase_url: Supabase project URL
        supabase_key: Supabase service key
        xai_api_key: xAI API key
        batch_size: Number of restaurants per batch

    Returns:
        Summary dict with processing stats
    """
    logger.info("=" * 70)
    logger.info("PROCESSING RESTAURANTS WITHOUT GENERATED_SUMMARY (1 run each)")
    logger.info("=" * 70)

    supabase: Client = create_client(supabase_url, supabase_key)
    client = AsyncOpenAI(api_key=xai_api_key, base_url=XAI_BASE_URL)

    # Count total restaurants without generated_summary and not yet processed
    count_query = (supabase.table("locations").select("location_id", count="exact")
                   .is_("generated_summary", "null")
                   .or_("updated_vibe.is.null,updated_vibe.eq.false"))
    count_response = count_query.execute()
    total_count = count_response.count if hasattr(count_response, 'count') else 0
    logger.info(f"Total restaurants without generated_summary (not yet processed): {total_count}")

    success_count = 0
    failed_count = 0
    errors = []
    processed_count = 0
    offset = 0

    while True:
        # Fetch batch (only unprocessed restaurants)
        logger.info(f"\nFetching batch {offset // batch_size + 1} (offset: {offset})...")
        query = (supabase.table("locations").select("*")
                 .is_("generated_summary", "null")
                 .or_("updated_vibe.is.null,updated_vibe.eq.false"))
        query = query.limit(batch_size).range(offset, offset + batch_size - 1)

        response = query.execute()
        batch = response.data

        if not batch:
            logger.info("No more restaurants to process")
            break

        logger.info(f"Processing batch of {len(batch)} restaurants...")

        # Process each restaurant in the batch
        for idx, restaurant in enumerate(batch, 1):
            location_id = restaurant.get("location_id")
            name = restaurant.get("name", "Unknown")

            processed_count += 1
            logger.info(f"[{processed_count}/{total_count}] {name} (1 run)")

            try:
                # Run once
                scores = await analyze_restaurant_vibes(restaurant, client)
                vibe_vector = scores_to_vibe_vector(scores)

                # Update database
                result = update_vibe_vector(supabase_url, supabase_key, location_id, vibe_vector)

                if result["success"]:
                    success_count += 1
                    logger.info(f"    ✓ Updated vibe_vector (single run)")
                else:
                    failed_count += 1
                    errors.append({"location_id": location_id, "name": name, "error": result.get("error")})
                    logger.error(f"    ✗ Failed to update: {result.get('error')}")

            except Exception as e:
                failed_count += 1
                errors.append({"location_id": location_id, "name": name, "error": str(e)})
                logger.error(f"    ✗ Error: {e}")

        # Move to next batch
        if len(batch) < batch_size:
            break
        offset += batch_size

    logger.info("=" * 70)
    logger.info(f"WITHOUT SUMMARY COMPLETE: {success_count} succeeded, {failed_count} failed")
    logger.info("=" * 70)

    return {
        "category": "without_summary",
        "total": processed_count,
        "success_count": success_count,
        "failed_count": failed_count,
        "errors": errors,
    }


async def process_all_restaurants(
    supabase_url: str,
    supabase_key: str,
    xai_api_key: str,
) -> dict:
    """
    Process ALL restaurants with the appropriate strategy:
    - Restaurants WITH generated_summary: 3 runs, use mean scores
    - Restaurants WITHOUT generated_summary: 1 run, use single scores

    Args:
        supabase_url: Supabase project URL
        supabase_key: Supabase service key
        xai_api_key: xAI API key

    Returns:
        Combined summary dict
    """
    logger.info("=" * 70)
    logger.info("COMPLETE VIBE TAG GENERATION PIPELINE")
    logger.info("=" * 70)
    logger.info("Strategy:")
    logger.info("  • WITH generated_summary → 3 runs, mean scores")
    logger.info("  • WITHOUT generated_summary → 1 run, direct scores")
    logger.info("=" * 70)

    # Process restaurants with summary (5 runs)
    with_summary_result = await process_restaurants_with_summary(
        supabase_url=supabase_url,
        supabase_key=supabase_key,
        xai_api_key=xai_api_key,
    )

    # Process restaurants without summary (1 run)
    without_summary_result = await process_restaurants_without_summary(
        supabase_url=supabase_url,
        supabase_key=supabase_key,
        xai_api_key=xai_api_key,
    )

    # Combined summary
    total_processed = with_summary_result["total"] + without_summary_result["total"]
    total_success = with_summary_result["success_count"] + without_summary_result["success_count"]
    total_failed = with_summary_result["failed_count"] + without_summary_result["failed_count"]
    all_errors = with_summary_result["errors"] + without_summary_result["errors"]

    logger.info("\n" + "=" * 70)
    logger.info("FINAL SUMMARY")
    logger.info("=" * 70)
    logger.info(f"Restaurants with summary:    {with_summary_result['total']:4d} "
                f"({with_summary_result['success_count']} ✓, {with_summary_result['failed_count']} ✗)")
    logger.info(f"Restaurants without summary: {without_summary_result['total']:4d} "
                f"({without_summary_result['success_count']} ✓, {without_summary_result['failed_count']} ✗)")
    logger.info("─" * 70)
    logger.info(f"TOTAL:                       {total_processed:4d} "
                f"({total_success} ✓, {total_failed} ✗)")
    logger.info("=" * 70)

    return {
        "with_summary": with_summary_result,
        "without_summary": without_summary_result,
        "total_processed": total_processed,
        "total_success": total_success,
        "total_failed": total_failed,
        "all_errors": all_errors,
    }


# ── Main Pipeline (Legacy - for limited batches) ─────────────────────────────

async def process_restaurants(
    supabase_url: str,
    supabase_key: str,
    xai_api_key: str,
    limit: Optional[int] = None,
) -> dict:
    """
    Main pipeline: fetch restaurants, analyze, and update vibe vectors.

    Args:
        supabase_url: Supabase project URL
        supabase_key: Supabase service key
        xai_api_key: xAI API key
        limit: Optional limit on number of restaurants to process

    Returns:
        Summary dict with processing stats
    """
    logger.info("=" * 70)
    logger.info("VIBE TAG GENERATION PIPELINE")
    logger.info("=" * 70)

    # Fetch restaurants
    restaurants = fetch_all_restaurants(supabase_url, supabase_key, limit)

    if not restaurants:
        logger.error("No restaurants found!")
        return {"error": "No restaurants found"}

    # Initialize OpenAI client
    client = AsyncOpenAI(api_key=xai_api_key, base_url=XAI_BASE_URL)

    # Process each restaurant
    success_count = 0
    failed_count = 0
    errors = []

    for idx, restaurant in enumerate(restaurants, 1):
        location_id = restaurant.get("location_id")
        name = restaurant.get("name", "Unknown")

        logger.info(f"[{idx}/{len(restaurants)}] Processing: {name}")

        try:
            # Analyze and get scores
            scores = await analyze_restaurant_vibes(restaurant, client)

            # Convert to vibe_vector array
            vibe_vector = scores_to_vibe_vector(scores)

            # Log the final vibe_vector array in both formats
            logger.info(f"  Vibe vector (readable): {format_vibe_vector_readable(vibe_vector)}")
            logger.debug(f"  Vibe vector (raw array): {vibe_vector}")

            # Update Supabase
            result = update_vibe_vector(supabase_url, supabase_key, location_id, vibe_vector)

            if result["success"]:
                success_count += 1
                logger.info(f"  ✓ Updated vibe_vector for {name}")
            else:
                failed_count += 1
                errors.append({"location_id": location_id, "name": name, "error": result.get("error")})
                logger.error(f"  ✗ Failed to update {name}: {result.get('error')}")

        except Exception as e:
            failed_count += 1
            errors.append({"location_id": location_id, "name": name, "error": str(e)})
            logger.error(f"  ✗ Error processing {name}: {e}")

    # Summary
    logger.info("=" * 70)
    logger.info("PIPELINE COMPLETE")
    logger.info("=" * 70)
    logger.info(f"Total restaurants: {len(restaurants)}")
    logger.info(f"Successfully updated: {success_count}")
    logger.info(f"Failed: {failed_count}")
    logger.info("=" * 70)

    return {
        "total": len(restaurants),
        "success_count": success_count,
        "failed_count": failed_count,
        "errors": errors,
    }


# ── Multiple Runs Analysis ──────────────────────────────────────────────────

async def test_multiple_runs(
    supabase_url: str,
    supabase_key: str,
    xai_api_key: str,
    location_id: str,
    num_runs: int,
    update_db: bool = False,
) -> dict:
    """
    Run the analysis multiple times on the same restaurant and compute statistics.

    Args:
        supabase_url: Supabase project URL
        supabase_key: Supabase service key
        xai_api_key: xAI API key
        location_id: The location_id to analyze
        num_runs: Number of times to run the analysis
        update_db: Whether to update the database with mean scores (default: False)

    Returns:
        Dict with aggregated results and statistics
    """
    logger.info("=" * 70)
    logger.info(f"TESTING WITH {num_runs} RUNS")
    logger.info("=" * 70)
    logger.info(f"Location ID: {location_id}")
    logger.info(f"Number of runs: {num_runs}")
    logger.info(f"Update database: {update_db}")
    logger.info("=" * 70)

    # Fetch the restaurant once
    supabase: Client = create_client(supabase_url, supabase_key)

    try:
        response = supabase.table("locations").select("*").eq("location_id", location_id).execute()

        if not response.data or len(response.data) == 0:
            logger.error(f"Restaurant with location_id '{location_id}' not found!")
            return {"error": "Restaurant not found"}

        restaurant = response.data[0]
        restaurant_name = restaurant.get('name', 'Unknown')
        logger.info(f"Found restaurant: {restaurant_name}\n")

    except Exception as e:
        logger.error(f"Failed to fetch restaurant: {e}")
        return {"error": str(e)}

    # Initialize OpenAI client
    client = AsyncOpenAI(api_key=xai_api_key, base_url=XAI_BASE_URL)

    # Run analysis multiple times
    all_scores = []
    all_vectors = []

    for run_num in range(1, num_runs + 1):
        logger.info(f"\n{'─' * 70}")
        logger.info(f"RUN {run_num}/{num_runs}")
        logger.info(f"{'─' * 70}")

        try:
            scores = await analyze_restaurant_vibes(restaurant, client)
            vibe_vector = scores_to_vibe_vector(scores)

            all_scores.append(scores)
            all_vectors.append(vibe_vector)

        except Exception as e:
            logger.error(f"Run {run_num} failed: {e}")
            continue

    if not all_scores:
        logger.error("All runs failed!")
        return {"error": "All runs failed", "success": False}

    # Compute statistics
    logger.info(f"\n{'=' * 70}")
    logger.info("STATISTICAL ANALYSIS")
    logger.info("=" * 70)

    # Calculate mean and std dev for each tag
    mean_scores = {}
    std_scores = {}

    for tag in VIBE_TAGS_ORDERED:
        tag_values = [scores.get(tag, 0.0) for scores in all_scores]
        mean_scores[tag] = statistics.mean(tag_values)
        std_scores[tag] = statistics.stdev(tag_values) if len(tag_values) > 1 else 0.0

    # Sort by mean score for display
    sorted_tags = sorted(mean_scores.items(), key=lambda x: -x[1])

    logger.info(f"\nRestaurant: {restaurant_name}")
    logger.info(f"Runs completed: {len(all_scores)}/{num_runs}")
    logger.info(f"\nMean scores across {len(all_scores)} runs:")
    logger.info(f"{'Tag':20s} {'Mean':>8s} {'StdDev':>8s} {'Range':>12s}")
    logger.info("─" * 50)

    for tag, mean_score in sorted_tags:
        # Show tag if it had any non-zero score in any run
        tag_values = [scores.get(tag, 0.0) for scores in all_scores]
        max_val = max(tag_values)

        if max_val > 0:  # Show if any run had a non-zero score
            min_val = min(tag_values)
            std_val = std_scores[tag]

            logger.info(
                f"{tag:20s} {mean_score:8.1f} {std_val:8.1f} "
                f"[{min_val:.0f}-{max_val:.0f}]"
            )

    # Create mean vibe vector
    mean_vibe_vector = [mean_scores.get(tag, 0.0) for tag in VIBE_TAGS_ORDERED]

    logger.info(f"\nMean vibe vector: {format_vibe_vector_readable(mean_vibe_vector)}")

    # Show individual run comparison for high-variance tags
    logger.info(f"\n{'=' * 70}")
    logger.info("VARIABILITY ANALYSIS")
    logger.info("=" * 70)

    high_variance_tags = [(tag, std_scores[tag]) for tag in VIBE_TAGS_ORDERED
                          if std_scores[tag] > 5.0 and mean_scores[tag] > 0]

    if high_variance_tags:
        high_variance_tags.sort(key=lambda x: -x[1])
        logger.info("\nTags with high variability (std dev > 5):")

        for tag, std_val in high_variance_tags[:5]:  # Show top 5
            tag_values = [scores.get(tag, 0.0) for scores in all_scores]
            logger.info(f"\n  {tag} (std dev: {std_val:.1f}):")
            for i, val in enumerate(tag_values, 1):
                logger.info(f"    Run {i}: {val:.0f}")
    else:
        logger.info("\nNo tags with high variability - results are consistent!")

    # Optionally update database with mean scores
    result = {
        "location_id": location_id,
        "name": restaurant_name,
        "num_runs": len(all_scores),
        "mean_scores": mean_scores,
        "std_scores": std_scores,
        "mean_vibe_vector": mean_vibe_vector,
        "all_runs": all_scores,
        "success": True,
    }

    if update_db:
        logger.info(f"\n{'=' * 70}")
        logger.info("UPDATING DATABASE")
        logger.info("=" * 70)
        logger.info("Updating with MEAN scores from all runs...")

        update_result = update_vibe_vector(supabase_url, supabase_key, location_id, mean_vibe_vector)

        if update_result["success"]:
            logger.info(f"✓ Successfully updated vibe_vector with mean scores")
            result["updated"] = True
        else:
            logger.error(f"✗ Failed to update database: {update_result.get('error')}")
            result["updated"] = False
            result["update_error"] = update_result.get("error")
    else:
        logger.info(f"\n(Skipping database update - set --update to save mean scores)")
        result["updated"] = False

    logger.info("=" * 70)

    return result


# ── Single Restaurant Testing ───────────────────────────────────────────────

async def test_single_restaurant(
    supabase_url: str,
    supabase_key: str,
    xai_api_key: str,
    location_id: str,
    update_db: bool = False,
) -> dict:
    """
    Test the vibe tag pipeline on a single restaurant.

    Args:
        supabase_url: Supabase project URL
        supabase_key: Supabase service key
        xai_api_key: xAI API key
        location_id: The location_id to analyze
        update_db: Whether to update the database (default: False for testing)

    Returns:
        Dict with analysis results
    """
    logger.info("=" * 70)
    logger.info("TESTING SINGLE RESTAURANT")
    logger.info("=" * 70)
    logger.info(f"Location ID: {location_id}")
    logger.info(f"Update database: {update_db}")
    logger.info("=" * 70)

    # Fetch the specific restaurant
    supabase: Client = create_client(supabase_url, supabase_key)

    try:
        response = supabase.table("locations").select("*").eq("location_id", location_id).execute()

        if not response.data or len(response.data) == 0:
            logger.error(f"Restaurant with location_id '{location_id}' not found!")
            return {"error": "Restaurant not found"}

        restaurant = response.data[0]
        logger.info(f"Found restaurant: {restaurant.get('name', 'Unknown')}")

    except Exception as e:
        logger.error(f"Failed to fetch restaurant: {e}")
        return {"error": str(e)}

    # Initialize OpenAI client
    client = AsyncOpenAI(api_key=xai_api_key, base_url=XAI_BASE_URL)

    # Analyze the restaurant
    try:
        scores = await analyze_restaurant_vibes(restaurant, client)
        vibe_vector = scores_to_vibe_vector(scores)

        result = {
            "location_id": location_id,
            "name": restaurant.get("name"),
            "scores": scores,
            "vibe_vector": vibe_vector,
            "success": True,
        }

        # Optionally update the database
        if update_db:
            logger.info("\nUpdating database...")
            update_result = update_vibe_vector(supabase_url, supabase_key, location_id, vibe_vector)

            if update_result["success"]:
                logger.info(f"✓ Successfully updated vibe_vector in database")
                result["updated"] = True
            else:
                logger.error(f"✗ Failed to update database: {update_result.get('error')}")
                result["updated"] = False
                result["update_error"] = update_result.get("error")
        else:
            logger.info("\n(Skipping database update - set update_db=True to save)")
            result["updated"] = False

        # Print summary
        logger.info("\n" + "=" * 70)
        logger.info("ANALYSIS SUMMARY")
        logger.info("=" * 70)
        logger.info(f"Restaurant: {restaurant.get('name')}")
        logger.info(f"Location ID: {location_id}")
        logger.info(f"Total score: {sum(scores.values()):.0f}")
        logger.info(f"\nTop tags:")

        sorted_scores = sorted(scores.items(), key=lambda x: -x[1])
        for tag, score in sorted_scores[:10]:  # Show top 10
            if score > 0:
                logger.info(f"  {tag:20s} = {score:3.0f}")

        logger.info(f"\nVibe vector: {format_vibe_vector_readable(vibe_vector)}")
        logger.info("=" * 70)

        return result

    except Exception as e:
        logger.error(f"Analysis failed: {e}")
        return {"error": str(e), "success": False}


# ── Entry Point ──────────────────────────────────────────────────────────────

async def main():
    """Main entry point for the vibe tag generation pipeline."""

    # Parse command-line arguments
    parser = argparse.ArgumentParser(
        description="Generate vibe tags for restaurants using AI analysis",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Test a single restaurant (view only, no database update)
  python generate_vibe_tags.py --test 123

  # Test a single restaurant and update database
  python generate_vibe_tags.py --test 123 --update

  # Run analysis 5 times and show mean scores
  python generate_vibe_tags.py --test 123 --runs 5

  # Process ALL restaurants (smart strategy: 3 runs for WITH summary, 1 run for WITHOUT)
  python generate_vibe_tags.py --batch

  # Process only restaurants WITH generated_summary (3 runs each)
  python generate_vibe_tags.py --batch-with-summary

  # Process only restaurants WITHOUT generated_summary (1 run each)
  python generate_vibe_tags.py --batch-without-summary

  # Legacy: Process first 10 restaurants (testing)
  python generate_vibe_tags.py --batch --limit 10
        """
    )

    parser.add_argument(
        "--test",
        type=str,
        metavar="LOCATION_ID",
        help="Test mode: analyze a single restaurant by location_id"
    )

    parser.add_argument(
        "--update",
        action="store_true",
        help="Update database when testing (only used with --test)"
    )

    parser.add_argument(
        "--runs",
        type=int,
        metavar="N",
        default=1,
        help="Number of times to run analysis (use with --test to compute mean scores)"
    )

    parser.add_argument(
        "--batch",
        action="store_true",
        help="Batch mode: process all restaurants (with/without summary using appropriate strategy)"
    )

    parser.add_argument(
        "--batch-with-summary",
        action="store_true",
        help="Batch mode: only process restaurants WITH generated_summary (5 runs each)"
    )

    parser.add_argument(
        "--batch-without-summary",
        action="store_true",
        help="Batch mode: only process restaurants WITHOUT generated_summary (1 run each)"
    )

    parser.add_argument(
        "--limit",
        type=int,
        metavar="N",
        help="Limit number of restaurants (only for legacy --batch with --limit)"
    )

    args = parser.parse_args()

    # Get configuration from environment
    supabase_url = os.environ.get("SUPABASE_URL")
    supabase_key = os.environ.get("SUPABASE_KEY")
    xai_api_key = os.environ.get("XAI_API_KEY")

    # Validate configuration
    if not supabase_url or not supabase_key:
        print("Error: SUPABASE_URL and SUPABASE_KEY must be set")
        print('  export SUPABASE_URL="https://yourproject.supabase.co"')
        print('  export SUPABASE_KEY="your-key"')
        return

    if not xai_api_key:
        print("Error: XAI_API_KEY must be set")
        print('  export XAI_API_KEY="your-xai-api-key"')
        return

    # Determine mode
    if args.test:
        # ── TEST MODE: Analyze a single restaurant ──
        if args.runs > 1:
            # Multiple runs with statistical analysis
            result = await test_multiple_runs(
                supabase_url=supabase_url,
                supabase_key=supabase_key,
                xai_api_key=xai_api_key,
                location_id=args.test,
                num_runs=args.runs,
                update_db=args.update,
            )
        else:
            # Single run
            result = await test_single_restaurant(
                supabase_url=supabase_url,
                supabase_key=supabase_key,
                xai_api_key=xai_api_key,
                location_id=args.test,
                update_db=args.update,
            )
        return

    elif args.batch_with_summary:
        # ── BATCH MODE: Only restaurants WITH summary (3 runs) ──
        summary = await process_restaurants_with_summary(
            supabase_url=supabase_url,
            supabase_key=supabase_key,
            xai_api_key=xai_api_key,
        )

        # Print errors if any
        if summary.get("errors"):
            logger.error("\nErrors encountered:")
            for error in summary["errors"]:
                logger.error(f"  - {error['name']} ({error['location_id']}): {error['error']}")

    elif args.batch_without_summary:
        # ── BATCH MODE: Only restaurants WITHOUT summary (1 run) ──
        summary = await process_restaurants_without_summary(
            supabase_url=supabase_url,
            supabase_key=supabase_key,
            xai_api_key=xai_api_key,
        )

        # Print errors if any
        if summary.get("errors"):
            logger.error("\nErrors encountered:")
            for error in summary["errors"]:
                logger.error(f"  - {error['name']} ({error['location_id']}): {error['error']}")

    elif args.batch:
        if args.limit:
            # Legacy mode: process limited number of restaurants
            logger.warning("Using legacy batch mode with --limit")
            summary = await process_restaurants(
                supabase_url=supabase_url,
                supabase_key=supabase_key,
                xai_api_key=xai_api_key,
                limit=args.limit,
            )

            # Print errors if any
            if summary.get("errors"):
                logger.error("\nErrors encountered:")
                for error in summary["errors"]:
                    logger.error(f"  - {error['name']} ({error['location_id']}): {error['error']}")
        else:
            # New mode: process ALL restaurants with appropriate strategy
            summary = await process_all_restaurants(
                supabase_url=supabase_url,
                supabase_key=supabase_key,
                xai_api_key=xai_api_key,
            )

            # Print errors if any
            if summary.get("all_errors"):
                logger.error("\nErrors encountered:")
                for error in summary["all_errors"]:
                    logger.error(f"  - {error['name']} ({error['location_id']}): {error['error']}")

    else:
        # No mode specified - show help
        parser.print_help()
        print("\nError: You must specify either --test or --batch mode")
        return


if __name__ == "__main__":
    asyncio.run(main())
