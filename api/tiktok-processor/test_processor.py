"""
Evaluator for TikTok processor extraction logic.

Tests _extract_locations, _extract_factual_insights, and _extract_interpretive_signals
against hardcoded video_data payloads (no Apify calls required).

Usage:
    python test_processor.py
    python test_processor.py --cases custom_cases.json --runs 3 --show-output
    python test_processor.py --only locations
"""
import asyncio
import argparse
import json
import os
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from dotenv import load_dotenv
from openai import OpenAI, AsyncOpenAI

load_dotenv()

SCRIPT_DIR = Path(__file__).resolve().parent

# ── Judge prompt ──────────────────────────────────────────────────────────────

JUDGE_SYSTEM_PROMPT = """
You are grading outputs from a TikTok video extraction pipeline against expected answers.

Score each extraction on a 1-3 scale:
- 3: Fully correct or nearly fully correct. Key fields match, no hallucinations.
- 2: Partially correct. Some fields off, missing items, or minor hallucinations.
- 1: Poor. Wrong values, missing required fields, or substantial hallucinations.

Return only valid JSON:
{
  "locations_score": 1|2|3,
  "locations_verdict": "short summary",
  "insights_score": 1|2|3,
  "insights_verdict": "short summary",
  "vibes_score": 1|2|3,
  "vibes_verdict": "short summary"
}

Be strict about hallucinations (inventing content not present in the source data).
Be lenient about minor phrasing differences.
"""


def load_cases(path: Path) -> List[Dict]:
    raw = json.loads(path.read_text())
    if not isinstance(raw, list):
        raise ValueError("Cases file must contain a JSON array")
    return raw


def run_extractions(processor, video_data: Dict) -> Dict:
    """Run all three extraction methods synchronously and return combined output."""
    locations = processor._extract_locations(video_data, True) or []
    factual = processor._extract_factual_insights(video_data)
    interpretive = processor._extract_interpretive_signals(video_data)
    return {
        "locations": locations,
        "key_dishes": factual.get("key_dishes", []),
        "special_offers": factual.get("special_offers", []),
        "vibe_signals": interpretive.get("vibe_signals", {}),
        "sentiment": interpretive.get("sentiment"),
        "creator_notes": interpretive.get("creator_notes"),
    }


async def call_judge(judge_client: AsyncOpenAI, judge_model: str, case: Dict, actual: Dict) -> Dict:
    payload = {
        "video_data": case["video_data"],
        "expected": case["expected"],
        "actual": actual,
    }
    response = await judge_client.chat.completions.create(
        model=judge_model,
        messages=[
            {"role": "system", "content": JUDGE_SYSTEM_PROMPT.strip()},
            {"role": "user", "content": json.dumps(payload, indent=2)},
        ],
        temperature=0,
        max_tokens=300,
    )
    raw = (response.choices[0].message.content or "").strip()
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError:
        return {"locations_score": 1, "locations_verdict": "parse error", "insights_score": 1, "insights_verdict": "parse error", "vibes_score": 1, "vibes_verdict": "parse error"}
    return parsed


def print_result(run: int, case: Dict, actual: Dict, judge: Dict) -> None:
    name = case.get("name", case.get("case_id", "unknown"))
    print("=" * 80)
    print(f"RUN {run} | {name}")
    print(f"\nVideo description: {case['video_data'].get('description', '')[:120]}")
    print(f"\n── Locations ──")
    print(f"  Expected: {[l.get('location_name') for l in case['expected'].get('locations', [])]}")
    print(f"  Actual:   {[l.get('location_name') for l in actual.get('locations', [])]}")
    print(f"  Score: {judge.get('locations_score')}/3 — {judge.get('locations_verdict')}")
    print(f"\n── Key Dishes / Offers ──")
    print(f"  Expected dishes: {[d.get('name') for d in case['expected'].get('key_dishes', [])]}")
    print(f"  Actual dishes:   {[d.get('name') for d in actual.get('key_dishes', [])]}")
    print(f"  Expected offers: {[o.get('offer') for o in case['expected'].get('special_offers', [])]}")
    print(f"  Actual offers:   {[o.get('offer') for o in actual.get('special_offers', [])]}")
    print(f"  Score: {judge.get('insights_score')}/3 — {judge.get('insights_verdict')}")
    print(f"\n── Vibes / Sentiment ──")
    print(f"  Expected vibes: {list(case['expected'].get('vibe_signals', {}).keys())}")
    print(f"  Actual vibes:   {list(actual.get('vibe_signals', {}).keys())}")
    print(f"  Expected sentiment: {case['expected'].get('sentiment')}")
    print(f"  Actual sentiment:   {actual.get('sentiment')}")
    print(f"  Score: {judge.get('vibes_score')}/3 — {judge.get('vibes_verdict')}")


def build_summary(results: List[Dict]) -> Dict:
    if not results:
        return {}
    keys = ["locations_score", "insights_score", "vibes_score"]
    avgs = {k: round(sum(r["judge"][k] for r in results) / len(results), 2) for k in keys}
    return {"n": len(results), **avgs}


async def run_suite(cases: List[Dict], processor, judge_client: AsyncOpenAI, judge_model: str,
                    run_number: int, show_output: bool, only: Optional[str]) -> List[Dict]:
    results = []
    for case in cases:
        video_data = case["video_data"]
        actual = run_extractions(processor, video_data)

        if only == "locations":
            actual = {**actual, "key_dishes": [], "special_offers": [], "vibe_signals": {}}
        elif only == "insights":
            actual = {**actual, "locations": [], "vibe_signals": {}}
        elif only == "vibes":
            actual = {**actual, "locations": [], "key_dishes": [], "special_offers": []}

        judge = await call_judge(judge_client, judge_model, case, actual)
        results.append({"case": case, "actual": actual, "judge": judge})
        print_result(run_number, case, actual, judge)

        if show_output:
            print("\n── Full actual output ──")
            print(json.dumps(actual, indent=2))

    return results


async def main() -> None:
    parser = argparse.ArgumentParser(description="Evaluate TikTok processor extraction.")
    parser.add_argument("--cases", default="test_processor_cases.json")
    parser.add_argument("--runs", type=int, default=1)
    parser.add_argument("--judge-model", default="gpt-4o")
    parser.add_argument("--show-output", action="store_true")
    parser.add_argument("--only", choices=["locations", "insights", "vibes"],
                        help="Only test one extraction type")
    parser.add_argument("--case", help="Run only the case with this case_id")
    parser.add_argument("--output", help="Write full JSON results to this path")
    args = parser.parse_args()

    cases_path = Path(args.cases)
    if not cases_path.is_absolute():
        cases_path = SCRIPT_DIR / cases_path
    if not cases_path.exists():
        print(f"Cases file not found: {cases_path}", file=sys.stderr)
        sys.exit(1)

    cases = load_cases(cases_path)

    if args.case:
        cases = [c for c in cases if c.get("case_id") == args.case]
        if not cases:
            print(f"No case found with case_id={args.case!r}", file=sys.stderr)
            sys.exit(1)

    openai_key = os.environ["OPENAI_API_KEY"]
    gmaps_key = os.environ.get("GOOGLE_PLACES_API_KEY", "dummy")
    apify_key = os.environ.get("APPIFY_KEY", "dummy")

    from processor import TikTokProcessor
    processor = TikTokProcessor(openaiKey=openai_key, gmaps_key=gmaps_key, appify_client=apify_key)

    judge_client = AsyncOpenAI(api_key=openai_key)

    all_runs = []
    for run_number in range(1, args.runs + 1):
        results = await run_suite(cases, processor, judge_client, args.judge_model,
                                  run_number, args.show_output, args.only)
        summary = build_summary(results)
        print("=" * 80)
        print(f"RUN {run_number} SUMMARY")
        print(json.dumps(summary, indent=2))
        all_runs.append({"run": run_number, "summary": summary, "results": [
            {"case_id": r["case"]["case_id"], "actual": r["actual"], "judge": r["judge"]}
            for r in results
        ]})

    if args.output:
        out = Path(args.output)
        if not out.is_absolute():
            out = SCRIPT_DIR / out
        out.write_text(json.dumps(all_runs, indent=2))
        print(f"\nWrote results to {out}")


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
    except Exception as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)
