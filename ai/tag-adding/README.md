# AI Tag Matcher for Locations

Intelligently matches locations to relevant tags using OpenAI, optimized for speed with in-memory caching.

## Features

- **Fast Execution**: In-memory tag caching - tags loaded once per session
- **AI-Powered**: Uses GPT-4o-mini for intelligent, context-aware tag matching
- **Batch Processing**: Process multiple locations in one run
- **Auto-Cleanup**: Removes old tags before adding new ones (no duplicates)
- **Detailed Logging**: Track performance and debug issues easily

## Setup

### 1. Install Dependencies

```bash
cd ai/tag-adding
pip install -r requirements.txt
```

### 2. Configure Environment

Create a `.env` file based on `.env.example`:

```bash
cp .env.example .env
```

Edit `.env` with your credentials:

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your-service-role-key-here
OPENAI_API_KEY=sk-your-openai-api-key-here
```

**Important**: Use your Supabase **service role key**, not the anon key, to bypass RLS policies.

## Usage

### Process a Single Location

```bash
python main.py 123
```

### Process Multiple Locations

```bash
python main.py 123 456 789
```

## How It Works

1. **Load Tags** (once per session):
   - Fetches all tags from `tags` table
   - Caches in memory for subsequent calls
   - Includes `tag_id`, `text`, `prompt_description`, and `tag_type`

2. **Fetch Location**:
   - Gets location details (name, vicinity, cuisine, rating, etc.)

3. **AI Matching**:
   - Creates a detailed prompt with location info and tag descriptions
   - Uses GPT-4o-mini for fast, cost-effective matching
   - Returns 3-8 most relevant tags ordered by relevance

4. **Save Results**:
   - Deletes existing tags for the location
   - Batch inserts new matched tags into `location_tags` table
   - Each tag gets a score (default: 1.0)

## Performance

- **First run**: ~2-3 seconds (loads tags + AI call)
- **Subsequent runs**: ~1-2 seconds (cached tags + AI call)
- **Batch processing**: ~1.5s per location average

## Output Example

```json
{
  "success": true,
  "location_id": 123,
  "matched_tags": 5,
  "tag_ids": [
    "uuid-1",
    "uuid-2",
    "uuid-3",
    "uuid-4",
    "uuid-5"
  ],
  "elapsed_seconds": 1.23
}
```

## Database Schema Requirements

### Tags Table
```sql
- tag_id (uuid, primary key)
- text (text) - Display name
- prompt_description (text) - Description for AI matching
- tag_type (enum) - Type of tag (vibe, dietary, etc.)
```

### Location Tags Table
```sql
- id (bigserial, primary key)
- location_id (bigint, foreign key)
- tag_id (uuid, foreign key)
- score (real) - Relevance score
```

## Error Handling

- **Missing environment variables**: Fails fast at startup
- **Location not found**: Returns error in result
- **AI parsing errors**: Logs full response for debugging
- **Database errors**: Detailed error logging with stack traces

## Optimization Tips

1. **Batch Processing**: Process multiple locations to amortize tag loading overhead
2. **Tag Cache**: Tags are cached automatically - no need to restart for new locations
3. **Force Refresh**: Call `matcher.load_tags(force_refresh=True)` if tags changed in DB

## Future Enhancements

- [ ] Parallel processing for batch operations
- [ ] Redis cache for multi-instance deployments
- [ ] Confidence scores per tag
- [ ] Tag type filtering (only match certain tag types)
- [ ] Web API endpoint (Flask/FastAPI)
