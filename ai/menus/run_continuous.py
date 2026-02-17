#!/usr/bin/env python3
"""
Continuous Menu Analysis Runner
================================
Runs the menu analysis pipeline continuously until all locations are processed.

This script will:
- Run main.py repeatedly in batches of 1000 (up to 20 iterations by default)
- Skip already-processed locations
- Continue until no more unprocessed locations remain or max iterations reached
- Show progress statistics between runs
- Handle interrupts gracefully

Usage:
    # Run with default settings (DESC order - top down, max 20 iterations)
    python run_continuous.py

    # Run with ASC order (bottom up - for second machine)
    python run_continuous.py --ascending

    # Custom batch size, concurrency, and max iterations
    python run_continuous.py --limit 500 --concurrency 5 --max-iterations 50
"""

import asyncio
import os
import sys
import time
from datetime import datetime
from pathlib import Path

# Add the parent directory to path so we can import main
sys.path.insert(0, str(Path(__file__).parent))

from main import process_and_update_locations
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

class ContinuousRunner:
    def __init__(self, limit=1000, ascending=False, concurrency=3, max_iterations=20):
        self.limit = limit
        self.ascending = ascending
        self.concurrency = concurrency
        self.max_iterations = max_iterations

        # Statistics
        self.total_processed = 0
        self.total_successful = 0
        self.total_failed = 0
        self.iteration_count = 0
        self.start_time = None

        # Configuration
        self.supabase_url = os.environ.get("SUPABASE_URL")
        self.supabase_key = os.environ.get("SUPABASE_KEY")
        self.xai_api_key = os.environ.get("XAI_API_KEY", "")

    def validate_config(self):
        """Check that required environment variables are set."""
        if not self.supabase_url or not self.supabase_key:
            print("❌ Error: SUPABASE_URL and SUPABASE_KEY must be set")
            print('  export SUPABASE_URL="https://yourproject.supabase.co"')
            print('  export SUPABASE_KEY="your-key"')
            return False
        return True

    def print_header(self):
        """Print startup banner."""
        order = "ASC (bottom-up)" if self.ascending else "DESC (top-down)"
        print("=" * 80)
        print("🚀 CONTINUOUS MENU ANALYSIS RUNNER")
        print("=" * 80)
        print(f"Configuration:")
        print(f"  • Batch size: {self.limit} locations per iteration")
        print(f"  • Order: {order}")
        print(f"  • Concurrency: {self.concurrency} parallel crawls")
        print(f"  • Max iterations: {self.max_iterations}")
        print(f"  • Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print("=" * 80)
        print()

    def print_iteration_header(self):
        """Print header for each iteration."""
        elapsed = time.time() - self.start_time
        elapsed_str = f"{int(elapsed // 60)}m {int(elapsed % 60)}s"

        print()
        print("─" * 80)
        print(f"📊 ITERATION #{self.iteration_count + 1}")
        print(f"   Time elapsed: {elapsed_str}")
        print(f"   Total processed so far: {self.total_processed}")
        print("─" * 80)
        print()

    def print_iteration_summary(self, summary):
        """Print summary after each iteration."""
        processed = summary.get("menus_analyzed", 0)
        successful = summary.get("successful_analyses", 0)

        print()
        print("─" * 80)
        print(f"✅ ITERATION #{self.iteration_count} COMPLETE")
        print("─" * 80)
        print(f"This iteration:")
        print(f"  • Analyzed: {processed} locations")
        print(f"  • Successful: {successful} menus found")
        print(f"  • Failed/No menu: {processed - successful}")
        print()
        print(f"Overall totals:")
        print(f"  • Total processed: {self.total_processed}")
        print(f"  • Total successful: {self.total_successful}")
        print(f"  • Total failed: {self.total_failed}")

        if self.total_processed > 0:
            success_rate = (self.total_successful / self.total_processed) * 100
            print(f"  • Success rate: {success_rate:.1f}%")

        elapsed = time.time() - self.start_time
        if elapsed > 0:
            rate = self.total_processed / (elapsed / 60)
            print(f"  • Processing rate: {rate:.1f} locations/minute")

        print("─" * 80)
        print()

    async def run_iteration(self):
        """Run one iteration of the pipeline."""
        self.print_iteration_header()

        try:
            summary = await process_and_update_locations(
                supabase_url=self.supabase_url,
                supabase_key=self.supabase_key,
                xai_api_key=self.xai_api_key,
                limit=self.limit,
                order_by="user_ratings_total",
                ascending=self.ascending,
                concurrency=self.concurrency,
                skip_processed=True,
            )

            # Update statistics
            self.iteration_count += 1
            processed = summary.get("menus_analyzed", 0)
            successful = summary.get("successful_analyses", 0)

            self.total_processed += processed
            self.total_successful += successful
            self.total_failed += (processed - successful)

            self.print_iteration_summary(summary)

            # Return number of locations processed
            return processed

        except Exception as e:
            print(f"❌ Error in iteration {self.iteration_count + 1}: {e}")
            import traceback
            traceback.print_exc()
            return -1  # Error indicator

    async def run(self):
        """Main run loop."""
        if not self.validate_config():
            return

        self.print_header()
        self.start_time = time.time()

        try:
            while True:
                # Check if we've hit max iterations
                if self.max_iterations and self.iteration_count >= self.max_iterations:
                    print(f"🏁 Reached maximum iterations ({self.max_iterations}). Stopping.")
                    break

                # Run one iteration
                processed = await self.run_iteration()

                # Check for errors
                if processed < 0:
                    print("⚠️  Error occurred. Waiting 30 seconds before retry...")
                    await asyncio.sleep(30)
                    continue

                # Check if we're done (no more locations to process)
                if processed == 0:
                    print("🎉 ALL DONE! No more unprocessed locations found.")
                    break

                # Brief pause between iterations
                if processed > 0:
                    print("⏸️  Waiting 10 seconds before next iteration...")
                    await asyncio.sleep(10)

        except KeyboardInterrupt:
            print("\n\n🛑 Interrupted by user")

        finally:
            self.print_final_summary()

    def print_final_summary(self):
        """Print final statistics."""
        elapsed = time.time() - self.start_time
        hours = int(elapsed // 3600)
        minutes = int((elapsed % 3600) // 60)
        seconds = int(elapsed % 60)

        print()
        print("=" * 80)
        print("🏁 FINAL SUMMARY")
        print("=" * 80)
        print(f"Total iterations: {self.iteration_count}")
        print(f"Total locations processed: {self.total_processed}")
        print(f"Total successful analyses: {self.total_successful}")
        print(f"Total failed/no menu: {self.total_failed}")

        if self.total_processed > 0:
            success_rate = (self.total_successful / self.total_processed) * 100
            print(f"Overall success rate: {success_rate:.1f}%")

        print(f"Total time: {hours}h {minutes}m {seconds}s")

        if elapsed > 0:
            rate = self.total_processed / (elapsed / 60)
            print(f"Average processing rate: {rate:.1f} locations/minute")

        print(f"Finished: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print("=" * 80)


def main():
    """Entry point with argument parsing."""
    import argparse

    parser = argparse.ArgumentParser(
        description="Continuously run menu analysis until all locations are processed"
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=1000,
        help="Number of locations to process per iteration (default: 1000)"
    )
    parser.add_argument(
        "--ascending",
        action="store_true",
        help="Process in ascending order (bottom-up). Use this on a second machine."
    )
    parser.add_argument(
        "--concurrency",
        type=int,
        default=3,
        help="Number of parallel crawls (default: 3)"
    )
    parser.add_argument(
        "--max-iterations",
        type=int,
        default=20,
        help="Maximum number of iterations (default: 20)"
    )

    args = parser.parse_args()

    runner = ContinuousRunner(
        limit=args.limit,
        ascending=args.ascending,
        concurrency=args.concurrency,
        max_iterations=args.max_iterations,
    )

    asyncio.run(runner.run())


if __name__ == "__main__":
    main()
