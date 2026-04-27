# Multi-Label Cuisine Classifier

A deterministic cuisine detection pipeline for restaurant locations using multiple signals with provenance tracking and confidence scoring.

## Overview

This module classifies restaurants into cuisines using:
- **Google Place types** (high precision, e.g., `chinese_restaurant`, `indian_restaurant`)
- **Name/website/menu URL tokens** (medium weight)
- **Reviews + review_summary** (medium weight, also detects fusion phrases)
- **generated_summary** (low weight, never overrides strong signals)

### Output Fields

| Field | Type | Description |
|-------|------|-------------|
| `cuisine_primary` | `text` | Single best label for UI display |
| `cuisine_detected` | `text[]` | Array of all detected cuisine labels |
| `cuisine_scores_json` | `jsonb` | Map of cuisine → confidence score (0-1) |
| `cuisine_source_json` | `jsonb` | Map of cuisine → list of evidence sources |
| `cuisine_detected_at` | `timestamptz` | When classification was performed |
| `cuisine_version` | `text` | Algorithm version (e.g., `cuisine_v1`) |
| `cuisine_confidence` | `text` | Overall confidence: `low`, `medium`, `high` |

## Quick Start

### 1. Install Dependencies

```bash
cd ai/cuisines
pip install -r requirements.txt
```

### 2. Set Environment Variables

Create a `.env` file or set:
```bash
export SUPABASE_URL="https://your-project.supabase.co"
export SUPABASE_KEY="your-service-role-key"
```

### 3. Run Database Migration

```bash
# Apply the migration using Supabase CLI or your migration tool
supabase db push < migrations/001_add_cuisine_columns.sql
```

### 4. Run Batch Backfill

```bash
# Process all unprocessed locations
python batch_backfill.py

# Dry run (test without writing)
python batch_backfill.py --dry-run

# Process with custom batch size
python batch_backfill.py --batch-size 500

# Force reprocess all locations
python batch_backfill.py --reprocess
```

## Usage

### Python API

```python
from cuisines import detect_cuisine

# Example location data
location = {
    "name": "Xi'an Impression",
    "types": "chinese_restaurant,restaurant,food,point_of_interest",
    "website": "https://xianimpression.co.uk",
    "reviews": [
        {"text": "Amazing biang biang noodles!"},
        {"text": "Authentic Xi'an cuisine. Try the roujiamo!"},
    ],
    "review_summary": "Xi'an and Shaanxi cuisine with hand-pulled noodles",
    "generated_summary": "A Chinese restaurant",
}

result = detect_cuisine(location)

print(result.primary)      # "Chinese (Xi'an/Shaanxi)"
print(result.labels)       # ["Chinese", "Chinese (Xi'an/Shaanxi)"]
print(result.scores_json)  # {"Chinese": 0.85, "Chinese (Xi'an/Shaanxi)": 0.75}
print(result.sources_json) # {"Chinese": ["google_types", "reviews"], ...}
print(result.confidence)   # "high"
print(result.is_fusion)    # False
```

### Database Update

```python
# Get database-ready dict
db_update = result.to_db_update()
# Returns:
# {
#     "cuisine_primary": "Chinese (Xi'an/Shaanxi)",
#     "cuisine_detected": ["Chinese", "Chinese (Xi'an/Shaanxi)"],
#     "cuisine_scores_json": {"Chinese": 0.85, ...},
#     "cuisine_source_json": {"Chinese": ["google_types", "reviews"], ...},
#     "cuisine_confidence": "high",
#     "cuisine_version": "cuisine_v1",
#     "cuisine_detected_at": "2026-02-17T10:30:00+00:00",
# }
```

## Scoring Algorithm

### Signal Weights

| Source | Weight | Notes |
|--------|--------|-------|
| Google types | +0.85 | High precision, e.g., `afghani_restaurant` |
| Name keywords | +0.50 | Restaurant name tokens |
| Website/menu URL | +0.45 | Domain and path tokens |
| Reviews (high signal) | +0.40 | High-confidence keywords |
| Reviews (medium signal) | +0.30 | Medium-confidence keywords |
| Review summary | +0.35 | Summary text tokens |
| Generated summary | +0.15 | Weak, never overrides |

### Fusion Detection Rules

1. **Numeric Rule**:
   - If `top1 ≥ 0.65` AND `top2 ≤ 0.35` → Single cuisine
   - If `top1 ≥ 0.45` AND `top2 ≥ 0.40` → Both cuisines + "Fusion" label

2. **Phrase Rule**:
   - If reviews/summary contain explicit fusion language ("fusion", "mix of X and Y", "influenced by", etc.) → Add "Fusion" label

### Confidence Levels

| Level | Criteria |
|-------|----------|
| **high** | Top score ≥ 0.70 AND 2+ evidence sources |
| **medium** | Top score ≥ 0.45 OR 2+ evidence sources |
| **low** | Otherwise |

## Extending Mappings

### Adding New Google Type Mappings

Edit `mappings/type_to_cuisine.json`:

```json
{
  "type_to_cuisine": {
    "new_cuisine_restaurant": "New Cuisine",
    ...
  }
}
```

### Adding New Keywords

Edit `mappings/keyword_to_cuisine.json`:

```json
{
  "keyword_to_cuisine": {
    "New Cuisine": {
      "high_signal": ["specific_dish", "unique_ingredient"],
      "medium_signal": ["general_term", "region_name"]
    }
  }
}
```

### Adding Fusion Phrases

```json
{
  "fusion_phrases": [
    "new fusion phrase",
    ...
  ]
}
```

## Example Outputs

### Xi'an Impression (Regional Chinese)

```json
{
  "cuisine_primary": "Chinese (Xi'an/Shaanxi)",
  "cuisine_detected": ["Chinese", "Chinese (Xi'an/Shaanxi)"],
  "cuisine_scores_json": {
    "Chinese": 0.85,
    "Chinese (Xi'an/Shaanxi)": 0.75
  },
  "cuisine_source_json": {
    "Chinese": ["google_types", "reviews", "review_summary"],
    "Chinese (Xi'an/Shaanxi)": ["name", "reviews", "hierarchy"]
  },
  "cuisine_confidence": "high",
  "cuisine_version": "cuisine_v1"
}
```

### Yadgar (Afghan + Somali Fusion)

```json
{
  "cuisine_primary": "Afghan",
  "cuisine_detected": ["Afghan", "Somali", "Fusion"],
  "cuisine_scores_json": {
    "Afghan": 0.85,
    "Somali": 0.65,
    "Fusion": 0.5
  },
  "cuisine_source_json": {
    "Afghan": ["google_types", "reviews", "review_summary"],
    "Somali": ["reviews", "review_summary"],
    "Fusion": ["fusion_detection"]
  },
  "cuisine_confidence": "high",
  "cuisine_version": "cuisine_v1"
}
```

### Generic Restaurant (No Cuisine)

```json
{
  "cuisine_primary": null,
  "cuisine_detected": [],
  "cuisine_scores_json": {},
  "cuisine_source_json": {},
  "cuisine_confidence": "low",
  "cuisine_version": "cuisine_v1"
}
```

## Testing

```bash
# Run all tests
pytest test_classifier.py -v

# Run specific test class
pytest test_classifier.py::TestXianImpression -v

# Run with coverage
pytest test_classifier.py --cov=classifier --cov-report=html
```

## File Structure

```
ai/cuisines/
├── main.py                 # Module entry point
├── classifier.py           # Core classification logic
├── batch_backfill.py       # Batch processing script
├── test_classifier.py      # Test suite
├── requirements.txt        # Dependencies
├── README.md               # This file
├── mappings/
│   ├── type_to_cuisine.json    # Google type → cuisine mapping
│   └── keyword_to_cuisine.json # Keyword → cuisine lexicon
└── migrations/
    └── 001_add_cuisine_columns.sql  # Database migration
```

## Design Decisions

### Hierarchy Handling

Child cuisines (e.g., "Chinese (Xi'an/Shaanxi)") automatically include their parent ("Chinese") unless the parent is already present. This ensures:
- Filtering by "Chinese" includes all regional variants
- Regional specificity is preserved for display

### Weak Signal Handling

`generated_summary` is treated as weak and:
- Never overrides existing strong signals
- Only adds new cuisines if none detected from other sources
- Boosts existing low-confidence detections slightly

### Score Capping

All scores are capped at 1.0 to prevent runaway accumulation from multiple matches.

## Versioning

The `cuisine_version` field tracks which algorithm version produced the classification. To update all locations with a new version:

1. Update `CUISINE_VERSION` in `classifier.py`
2. Run `python batch_backfill.py` (will only process locations with old version)

Or to force reprocess all:
```bash
python batch_backfill.py --reprocess
```
