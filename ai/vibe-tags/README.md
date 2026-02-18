# Vibe Tag Generator

Automatically generates vibe tag scores for restaurants using a 3-stage AI analysis pipeline.

## Overview

This pipeline analyzes restaurant data and assigns 0-100 scores for 22 different "vibe" tags:

- `cafe`, `casual`, `cozy`, `coffee_shop`, `bar`
- `elegant`, `fine_dining`, `food_truck`, `hole_in_the_wall`, `late_night`
- `live_music`, `modern`, `fast_food`, `romantic`, `sports_bar`
- `takeout_friendly`, `pub`, `grocery_store`, `brunch`, `outdoor_dining`
- `wavy`, `bossman`

## How It Works

### 3-Stage Pipeline

1. **Stage 1: Tag Identification** (`valid_tag_prompt.md`)
   - Analyzes complete restaurant data
   - Identifies which tags are relevant (with supporting evidence)
   - Identifies which tags are irrelevant (with reasons)

2. **Stage 2: Relevant Tag Scoring** (`valid_tag_scorer.md`)
   - Scores each relevant tag 0-100 based on evidence strength
   - Higher scores = stronger/more central to restaurant identity

3. **Stage 3: Irrelevant Tag Scoring** (`invalid_tag_scorer.md`)
   - Re-examines irrelevant tags to catch missed evidence
   - Most score 0-20, but can catch false negatives

4. **Combination & Update**
   - Combines all scores into a 21-element array
   - Updates `vibe_vector` column in Supabase `locations` table

## Setup

### Prerequisites

```bash
# Install dependencies (from project root)
pip install openai supabase python-dotenv
```

### Environment Variables

Create a `.env` file in the project root or export these variables:

```bash
export SUPABASE_URL="https://yourproject.supabase.co"
export SUPABASE_KEY="your-supabase-service-key"
export XAI_API_KEY="your-xai-api-key"
```

## Usage

The script supports two modes: **test mode** (single restaurant) and **batch mode** (multiple restaurants).

### Test Mode - Single Restaurant

Test the pipeline on a specific restaurant by `location_id`:

```bash
# View results only (no database update)
python ai/vibe-tags/generate_vibe_tags.py --test YOUR_LOCATION_ID

# Test and update the database
python ai/vibe-tags/generate_vibe_tags.py --test YOUR_LOCATION_ID --update
```

**Example:**
```bash
python ai/vibe-tags/generate_vibe_tags.py --test 12345
```

This will:
- Fetch the restaurant with `location_id = 12345`
- Run the 3-stage analysis pipeline
- Show detailed reasoning and scores
- **Not** update the database (unless you add `--update`)

### Multiple Runs - Statistical Analysis

Run the analysis multiple times on the same restaurant to measure consistency and get mean scores:

```bash
# Run 3 times and show mean/std dev
python ai/vibe-tags/generate_vibe_tags.py --test 12345 --runs 3

# Run 10 times and update database with mean scores
python ai/vibe-tags/generate_vibe_tags.py --test 12345 --runs 10 --update
```

This will:
- Run the full analysis N times on the same restaurant
- Calculate mean and standard deviation for each tag
- Show which tags have high variability
- Optionally update database with mean scores (more stable than single run)

### Batch Mode - Multiple Restaurants

Process all restaurants using the smart strategy:

```bash
# Process ALL restaurants (smart strategy)
# - Restaurants WITH generated_summary: 3 runs, use mean scores
# - Restaurants WITHOUT generated_summary: 1 run, use direct scores
python ai/vibe-tags/generate_vibe_tags.py --batch
```

This will:
1. Query all restaurants with `generated_summary` in batches of 1000
2. Run analysis 3 times per restaurant and use mean scores
3. Query all restaurants without `generated_summary` in batches of 1000
4. Run analysis 1 time per restaurant and use direct scores
5. Update `vibe_vector` for all restaurants

**Process specific groups:**

```bash
# Only process restaurants WITH generated_summary (3 runs each)
python ai/vibe-tags/generate_vibe_tags.py --batch-with-summary

# Only process restaurants WITHOUT generated_summary (1 run each)
python ai/vibe-tags/generate_vibe_tags.py --batch-without-summary

# Legacy: Process first N restaurants (for testing)
python ai/vibe-tags/generate_vibe_tags.py --batch --limit 10
```

### Command-Line Options

```
--test LOCATION_ID    Test mode: analyze a single restaurant
--update              Update database when testing (use with --test)
--runs N              Run analysis N times and compute mean scores (use with --test)
--batch               Batch mode: process all/multiple restaurants
--limit N             Limit number of restaurants in batch mode
```

**Tip:** Use `--runs 3` or higher to get more stable scores, especially if you notice high variability in results.

## Output

The script will:

1. Fetch all restaurants from Supabase
2. Analyze each restaurant (shows progress logs)
3. Update `vibe_vector` column with 21 scores
4. Print summary of successes/failures

### Example Output

```
[1/150] Processing: The French Laundry
  Analyzing: The French Laundry (loc_123)
  Stage 1: Identifying relevant/irrelevant tags...
    Found 5 relevant, 16 irrelevant tags
  Stage 2: Scoring relevant tags...
  Stage 3: Scoring irrelevant tags...
  ✓ Analysis complete. Scores: 385 total points
  ✓ Updated vibe_vector for The French Laundry
```

## Vibe Vector Format

The `vibe_vector` column is a `float4[]` PostgreSQL array with 22 values in this order:

```python
[
  cafe, casual, cozy, coffee_shop, bar,
  elegant, fine_dining, food_truck, hole_in_the_wall, late_night,
  live_music, modern, fast_food, romantic, sports_bar,
  takeout_friendly, pub, grocery_store, brunch, outdoor_dining,
  wavy, bossman
]
```

Example: `[20, 80, 20, 20, 70, 10, 10, 10, 20, 20, 20, 20, 10, 20, 20, 20, 90, 10, 20, 20, 20, 20]`

## Customization

### Modify Prompts

Edit the prompt files to change how tags are identified or scored:

- `valid_tag_prompt.md` - Tag identification logic
- `valid_tag_scorer.md` - Scoring criteria for relevant tags
- `invalid_tag_scorer.md` - Scoring criteria for irrelevant tags

### Change Tag Order

Edit `VIBE_TAGS_ORDERED` in `generate_vibe_tags.py` if the database schema changes.

### Adjust Concurrency

Currently processes restaurants sequentially. To add concurrency (like the menus script), modify the `process_restaurants()` function with a semaphore pattern.

## Troubleshooting

### "No restaurants found"
- Check Supabase credentials
- Verify `locations` table exists and has data

### "Failed to parse LLM response"
- Check that prompt files are correctly formatted
- Verify XAI_API_KEY is valid
- Check xAI API status

### Scores seem off
- Review the evidence in Stage 1 by adding debug logging
- Adjust scoring guidelines in the scorer prompts
- Consider re-running with different prompts

## Incremental Batch Processing (Recommended for Large Datasets)

For processing thousands of restaurants, use the incremental batch script:

### batch_vibe_tags.py

Processes restaurants in batches of 1000 and can be run repeatedly:

```bash
# Process 1000 restaurants WITHOUT generated_summary (1 run each)
python ai/vibe-tags/batch_vibe_tags.py --without-summary

# Process 1000 restaurants WITH generated_summary (3 runs each)
python ai/vibe-tags/batch_vibe_tags.py --with-summary
```

**Key Features:**
- Processes up to 1000 restaurants per run (Supabase limit)
- Automatically skips restaurants with existing vibe_vector
- Shows remaining count after each batch
- Can be stopped and resumed at any time

**Run repeatedly until complete:**

```bash
# Make script executable (once)
chmod +x ai/vibe-tags/run_batch_repeatedly.sh

# Run continuously until all processed
./ai/vibe-tags/run_batch_repeatedly.sh --without-summary

# Or for restaurants with summary
./ai/vibe-tags/run_batch_repeatedly.sh --with-summary
```

The helper script will:
- Run the batch script repeatedly
- Add 2-second delays between batches
- Stop automatically when all restaurants are processed
- Can be interrupted with Ctrl+C and resumed later

## Files

- `generate_vibe_tags.py` - Full-featured script with test mode and batch processing
- `batch_vibe_tags.py` - **Incremental batch script (recommended for production)**
- `run_batch_repeatedly.sh` - Helper to run batches continuously
- `valid_tag_prompt.md` - Stage 1: Identify relevant/irrelevant tags
- `valid_tag_scorer.md` - Stage 2: Score relevant tags
- `invalid_tag_scorer.md` - Stage 3: Score irrelevant tags (catch false negatives)
- `README.md` - This file
