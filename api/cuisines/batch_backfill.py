"""
Cuisine Classification Batch Backfill Job
==========================================
Iterates all locations and populates cuisine fields using the multi-label classifier.

Features:
- Processes locations where cuisine_primary is null OR cuisine_version != current
- Idempotent: safe to run multiple times
- Progress logging with statistics
- Batch processing to handle large datasets

Usage:
    python batch_backfill.py                    # Process all unprocessed locations
    python batch_backfill.py --batch-size 500  # Custom batch size
    python batch_backfill.py --dry-run         # Test without writing to DB
    python batch_backfill.py --reprocess       # Force reprocess all locations
"""

import argparse
import asyncio
import json
import logging
import os
import sys
import time
from collections import Counter
from datetime import datetime
from pathlib import Path
from typing import Optional

from dotenv import load_dotenv
from supabase import create_client, Client

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent))
from classifier import detect_cuisine, get_cuisine_version, CuisineResult

# Load environment variables
load_dotenv()

# ── Configuration ────────────────────────────────────────────────────────────

SUPABASE_URL = os.getenv("SUPABASE_URL", "")
SUPABASE_KEY = os.getenv("SUPABASE_KEY", "")

DEFAULT_BATCH_SIZE = 1000
CURRENT_VERSION = get_cuisine_version()

# Logging setup
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.StreamHandler(),
    ]
)
logger = logging.getLogger(__name__)


# ── Statistics Tracker ───────────────────────────────────────────────────────

class Stats:
    """Track processing statistics."""
    
    def __init__(self):
        self.total_processed = 0
        self.success_count = 0
        self.failed_count = 0
        self.skipped_count = 0
        self.cuisine_counts = Counter()     # cuisine -> count
        self.no_cuisine_count = 0
        self.errors: list[dict] = []
        self.start_time = datetime.now()
    
    def record_success(self, result: CuisineResult):
        """Record a successful classification."""
        self.total_processed += 1
        self.success_count += 1
        
        if result.primary:
            self.cuisine_counts[result.primary] += 1
        else:
            self.no_cuisine_count += 1
    
    def record_failure(self, location_id: int, name: str, error: str):
        """Record a failed classification."""
        self.total_processed += 1
        self.failed_count += 1
        self.errors.append({
            "location_id": location_id,
            "name": name,
            "error": error,
        })
    
    def record_skip(self):
        """Record a skipped location."""
        self.skipped_count += 1
    
    def get_summary(self) -> dict:
        """Get summary statistics."""
        elapsed = (datetime.now() - self.start_time).total_seconds()
        rate = self.total_processed / elapsed if elapsed > 0 else 0
        
        return {
            "total_processed": self.total_processed,
            "success_count": self.success_count,
            "failed_count": self.failed_count,
            "skipped_count": self.skipped_count,
            "no_cuisine_count": self.no_cuisine_count,
            "top_cuisines": dict(self.cuisine_counts.most_common(20)),
            "elapsed_seconds": round(elapsed, 2),
            "rate_per_second": round(rate, 2),
            "error_count": len(self.errors),
        }
    
    def print_summary(self):
        """Print formatted summary to console."""
        summary = self.get_summary()
        
        logger.info("=" * 70)
        logger.info("BATCH BACKFILL COMPLETE")
        logger.info("=" * 70)
        logger.info(f"Total Processed: {summary['total_processed']}")
        logger.info(f"  ✓ Success: {summary['success_count']}")
        logger.info(f"  ✗ Failed: {summary['failed_count']}")
        logger.info(f"  ⊘ Skipped: {summary['skipped_count']}")
        logger.info("")
        logger.info(f"No Cuisine Detected: {summary['no_cuisine_count']}")
        logger.info("")
        logger.info(f"Top Cuisines:")
        for cuisine, count in list(summary['top_cuisines'].items())[:10]:
            logger.info(f"  {cuisine}: {count}")
        logger.info("")
        logger.info(f"Elapsed: {summary['elapsed_seconds']}s ({summary['rate_per_second']}/s)")
        logger.info("=" * 70)


# ── Database Operations ──────────────────────────────────────────────────────

def get_supabase_client() -> Client:
    """Create and return Supabase client."""
    if not SUPABASE_URL or not SUPABASE_KEY:
        raise ValueError("SUPABASE_URL and SUPABASE_KEY must be set in environment")
    return create_client(SUPABASE_URL, SUPABASE_KEY)


def fetch_unprocessed_locations(
    client: Client,
    batch_size: int,
    offset: int = 0,
    reprocess: bool = False,
    max_retries: int = 3,
) -> list[dict]:
    """
    Fetch locations that need cuisine classification with retry logic.
    
    Args:
        client: Supabase client
        batch_size: Maximum number of locations to fetch
        offset: Pagination offset
        reprocess: If True, fetch all locations regardless of version
        max_retries: Maximum retry attempts for timeouts
    
    Returns:
        List of location dicts
    """
    for attempt in range(max_retries):
        try:
            query = client.table("locations").select(
                "location_id, name, types, website, reviews, review_summary, "
                "generated_summary, cuisine_primary, cuisine_scores_json"
            )
            
            if not reprocess:
                # Use partial index idx_locations_cuisine_primary_null for efficiency
                query = query.is_("cuisine_primary", None)
            
            query = query.offset(offset).limit(batch_size)
            
            response = query.execute()
            return response.data or []
        except Exception as e:
            if "timeout" in str(e).lower() and attempt < max_retries - 1:
                wait_time = 2 ** attempt  # Exponential backoff: 1s, 2s, 4s
                logger.warning(f"Query timeout (attempt {attempt + 1}/{max_retries}), retrying in {wait_time}s...")
                time.sleep(wait_time)
            else:
                raise


def count_remaining_locations(
    client: Client,
    reprocess: bool = False,
    max_retries: int = 3,
) -> int:
    """Count locations that still need processing with retry logic."""
    for attempt in range(max_retries):
        try:
            query = client.table("locations").select("location_id", count="exact")
            
            if not reprocess:
                query = query.is_("cuisine_primary", None)
            
            response = query.execute()
            return response.count if hasattr(response, 'count') else 0
        except Exception as e:
            if "timeout" in str(e).lower() and attempt < max_retries - 1:
                wait_time = 2 ** attempt
                logger.warning(f"Count query timeout (attempt {attempt + 1}/{max_retries}), retrying in {wait_time}s...")
                time.sleep(wait_time)
            else:
                raise


def batch_update_locations(
    client: Client,
    updates: list[dict],
    dry_run: bool = False,
) -> tuple[int, int]:
    """
    Batch update multiple locations with cuisine classification results.
    
    Args:
        client: Supabase client
        updates: List of dicts with location_id and update data
        dry_run: If True, don't actually write to DB
    
    Returns:
        Tuple of (success_count, failed_count)
    """
    if not updates:
        return 0, 0
    
    if dry_run:
        logger.debug(f"[DRY RUN] Would batch update {len(updates)} locations")
        return len(updates), 0
    
    try:
        response = client.table("locations").upsert(updates).execute()
        return len(updates), 0
    except Exception as e:
        logger.error(f"Failed to batch update {len(updates)} locations: {e}")
        return 0, len(updates)


# ── Main Processing Loop ─────────────────────────────────────────────────────

def process_batch(
    client: Client,
    batch: list[dict],
    stats: Stats,
    dry_run: bool = False,
):
    """Process a batch of locations with batch updates."""
    updates = []
    results_by_location = {}
    
    # Step 1: Classify all locations
    for idx, location in enumerate(batch, 1):
        location_id = location.get("location_id")
        name = location.get("name", "Unknown")
        
        try:
            # Run classifier
            result = detect_cuisine(location)
            results_by_location[location_id] = (result, name, idx)
            
            # Prepare update
            update_data = result.to_db_update()
            update_data["location_id"] = location_id
            updates.append(update_data)
            
        except Exception as e:
            stats.record_failure(location_id, name, str(e))
            logger.error(f"[{idx}/{len(batch)}] {name}: Classification Error - {e}")
    
    # Step 2: Batch update all successfully classified locations
    if updates:
        success_count, failed_count = batch_update_locations(client, updates, dry_run)
        
        # Step 3: Record statistics
        for location_id, (result, name, idx) in results_by_location.items():
            stats.record_success(result)
            if result.primary:
                logger.info(
                    f"[{idx}/{len(batch)}] {name[:40]:<40} → {result.primary}, {result.scores_json}"
                )
            else:
                logger.info(f"[{idx}/{len(batch)}] {name[:40]:<40} → No cuisine detected")


def run_backfill(
    batch_size: int = DEFAULT_BATCH_SIZE,
    dry_run: bool = False,
    reprocess: bool = False,
    max_batches: Optional[int] = None,
    start_offset: int = 0,
):
    """
    Run the cuisine classification backfill.
    
    Args:
        batch_size: Number of locations per batch
        dry_run: If True, don't write to database
        reprocess: If True, process all locations regardless of version
        max_batches: Maximum number of batches to process (None = all)
        start_offset: Starting offset for pagination (useful for resuming)
    """
    logger.info("=" * 70)
    logger.info(f"CUISINE CLASSIFICATION BACKFILL")
    logger.info(f"Version: {CURRENT_VERSION}")
    logger.info(f"Batch Size: {batch_size}")
    logger.info(f"Dry Run: {dry_run}")
    logger.info(f"Reprocess All: {reprocess}")
    if start_offset > 0:
        logger.info(f"Starting Offset: {start_offset}")
    logger.info("=" * 70)
    
    client = get_supabase_client()
    stats = Stats()
    
    # Count total remaining
    total_remaining = count_remaining_locations(client, reprocess)
    logger.info(f"Total locations to process: {total_remaining}")
    
    if total_remaining == 0:
        logger.info("✓ All locations are already processed!")
        return stats
    
    batch_num = 0
    offset = start_offset
    
    while True:
        batch_num += 1
        
        if max_batches and batch_num > max_batches:
            logger.info(f"Reached max batches limit ({max_batches})")
            break
        
        # Fetch next batch with retry logic
        logger.info(f"\n--- Batch {batch_num} (offset: {offset}) ---")
        try:
            batch = fetch_unprocessed_locations(client, batch_size, offset, reprocess)
        except Exception as e:
            logger.error(f"Failed to fetch batch after retries: {e}")
            logger.info(f"To resume, run with: --start-offset {offset}")
            raise
        
        if not batch:
            logger.info("No more locations to process")
            break
        
        logger.info(f"Processing {len(batch)} locations...")
        process_batch(client, batch, stats, dry_run)
        
        # Update offset for next batch
        offset += len(batch)
        
        # Progress update
        remaining = total_remaining - stats.total_processed
        logger.info(f"Progress: {stats.total_processed}/{total_remaining} ({remaining} remaining)")
    
    # Print final summary
    stats.print_summary()
    
    # Save detailed report
    report_path = Path(__file__).parent / f"backfill_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    with open(report_path, 'w') as f:
        json.dump({
            "summary": stats.get_summary(),
            "errors": stats.errors,
            "config": {
                "version": CURRENT_VERSION,
                "batch_size": batch_size,
                "dry_run": dry_run,
                "reprocess": reprocess,
                "start_offset": start_offset,
            }
        }, f, indent=2)
    logger.info(f"Detailed report saved to: {report_path}")
    
    return stats


# ── CLI Entry Point ──────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Cuisine Classification Batch Backfill",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    python batch_backfill.py                    # Process all unprocessed locations
    python batch_backfill.py --batch-size 500  # Custom batch size
    python batch_backfill.py --dry-run         # Test without writing to DB
    python batch_backfill.py --reprocess       # Force reprocess all locations
    python batch_backfill.py --max-batches 5   # Process only 5 batches
        """
    )
    
    parser.add_argument(
        "--batch-size",
        type=int,
        default=DEFAULT_BATCH_SIZE,
        help=f"Number of locations per batch (default: {DEFAULT_BATCH_SIZE})"
    )
    
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Run without writing to database"
    )
    
    parser.add_argument(
        "--reprocess",
        action="store_true",
        help="Force reprocess all locations regardless of version"
    )
    
    parser.add_argument(
        "--max-batches",
        type=int,
        default=None,
        help="Maximum number of batches to process (default: all)"
    )
    
    parser.add_argument(
        "--start-offset",
        type=int,
        default=0,
        help="Starting offset for pagination (useful for resuming)"
    )
    
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Enable verbose logging"
    )
    
    args = parser.parse_args()
    
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    try:
        run_backfill(
            batch_size=args.batch_size,
            dry_run=args.dry_run,
            reprocess=args.reprocess,
            max_batches=args.max_batches,
            start_offset=args.start_offset,
        )
    except KeyboardInterrupt:
        logger.info("\nInterrupted by user")
        sys.exit(1)
    except Exception as e:
        logger.error(f"Fatal error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
