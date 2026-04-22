"""
Supabase-backed evaluator for the collections prompt.

Usage:
    python test_location.py --cases test_location_cases.json
    python test_location.py --cases test_location_cases.json --runs 3 --show-prompt

Each case should provide a real Supabase `location_id` plus the expected collections
and reference explanations. The script fetches the live location payload, runs the
classification prompt, and asks a second model to judge the output on a 1-3 scale.
"""
import asyncio
import argparse
import json
import os
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from dotenv import load_dotenv
from openai import AsyncOpenAI

load_dotenv()

from main import CollectionGenerator, COLLECTION_METADATA

SCRIPT_DIR = Path(__file__).resolve().parent


CLASSIFICATION_USER_MESSAGE = (
    "Evaluate this restaurant against all collections defined in the system prompt. "
    "Return only valid JSON that exactly matches the output format described there. "
    "Be conservative and include only strong fits. No markdown."
)

JUDGE_SYSTEM_PROMPT = """
You are grading a restaurant classification output against an expected answer.

Score using this rubric:
- 3: Collection selection is fully correct or nearly fully correct, and the explanations are strong, specific, and grounded.
- 2: Partially correct. Some collection choices or explanations are weak, vague, or slightly off.
- 1: Poor. Wrong collections, missing obvious collections, invalid output, or explanations are unsupported.

Return only valid JSON:
{
  "score": 1,
  "verdict": "short summary",
  "issues": ["issue 1", "issue 2"]
}
"""


def strip_markdown_fences(content: str) -> str:
    normalized = (content or "").strip()
    if normalized.startswith("```"):
        normalized = normalized.split("```")[1]
        if normalized.startswith("json"):
            normalized = normalized[4:]
        normalized = normalized.strip()
    return normalized


def load_cases(path: Path) -> List[Dict]:
    raw = json.loads(path.read_text())
    if not isinstance(raw, list):
        raise ValueError("Cases file must contain a JSON array")
    return raw


def fetch_location_by_id(generator: CollectionGenerator, location_id: int) -> Optional[Dict]:
    result = generator.supabase.table("locations").select("*").eq("location_id", location_id).execute()
    rows = result.data or []
    return rows[0] if rows else None


def normalize_expected_collections(case: Dict) -> List[Dict]:
    expected = case.get("expected_collections")
    if not isinstance(expected, list):
        raise ValueError(f"Case {case.get('case_id', case.get('location_id'))}: expected_collections must be a list")

    normalized = []
    for item in expected:
        if not isinstance(item, dict) or "id" not in item:
            raise ValueError(f"Case {case.get('case_id', case.get('location_id'))}: each expected collection must be an object with id")
        collection_id = item["id"]
        normalized.append({
            "id": collection_id,
            "label": item.get("label", COLLECTION_METADATA.get(collection_id, collection_id)),
            "reason": item.get("reason", ""),
        })
    return normalized


def parse_candidate_output(raw_text: str) -> Tuple[Optional[Dict], Optional[str]]:
    normalized = strip_markdown_fences(raw_text)
    try:
        parsed = json.loads(normalized)
    except json.JSONDecodeError as exc:
        return None, str(exc)

    if not isinstance(parsed, dict):
        return None, f"Expected a JSON object, got {type(parsed).__name__}"

    collections = parsed.get("collections")
    if not isinstance(collections, list):
        return None, "Expected `collections` to be a list"

    normalized_collections = []
    for item in collections:
        if not isinstance(item, dict):
            return None, "Each collection entry must be an object"
        collection_id = item.get("id")
        label = item.get("label")
        reason = item.get("reason")
        if not isinstance(collection_id, str):
            return None, "Each collection entry must include string `id`"
        if not isinstance(label, str):
            return None, "Each collection entry must include string `label`"
        if not isinstance(reason, str):
            return None, "Each collection entry must include string `reason`"
        normalized_collections.append({
            "id": collection_id,
            "label": label,
            "reason": reason,
        })

    parsed["collections"] = normalized_collections
    return parsed, None


def parse_judge_output(raw_text: str) -> Dict:
    normalized = strip_markdown_fences(raw_text)
    parsed = json.loads(normalized)
    if not isinstance(parsed, dict):
        raise ValueError("Judge output must be a JSON object")

    score = parsed.get("score")
    if score not in [1, 2, 3]:
        raise ValueError(f"Judge score must be 1, 2, or 3. Got {score}")

    verdict = parsed.get("verdict", "")
    issues = parsed.get("issues", [])
    if not isinstance(verdict, str):
        raise ValueError("Judge verdict must be a string")
    if not isinstance(issues, list):
        raise ValueError("Judge issues must be a list")

    return {
        "score": score,
        "verdict": verdict,
        "issues": issues,
    }


async def call_candidate(generator: CollectionGenerator, location: Dict) -> Tuple[str, str, str]:
    system_prompt = generator.build_system_prompt_for_location(location)
    user_message = CLASSIFICATION_USER_MESSAGE
    response = await generator.client.chat.completions.create(
        model=generator.model,
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_message},
        ],
        temperature=0.3,
        max_tokens=400,
    )
    raw_text = (response.choices[0].message.content or "").strip()
    return system_prompt, user_message, raw_text


async def call_judge(
    judge_client: AsyncOpenAI,
    judge_model: str,
    case: Dict,
    location: Dict,
    candidate_raw_text: str,
    candidate_parsed: Optional[Dict],
    parse_error: Optional[str],
) -> Dict:
    expected = {
        "location_id": location.get("location_id"),
        "name": location.get("name"),
        "collections": normalize_expected_collections(case),
    }

    judge_payload = {
        "location": location,
        "expected_output": expected,
        "candidate_output_raw": candidate_raw_text,
        "candidate_output_parsed": candidate_parsed,
        "candidate_parse_error": parse_error,
        "grading_focus": [
            "Did the candidate choose the right collections?",
            "Are the explanations aligned with the restaurant evidence?",
            "Are the explanations specific rather than generic?",
        ],
    }

    response = await judge_client.chat.completions.create(
        model=judge_model,
        messages=[
            {"role": "system", "content": JUDGE_SYSTEM_PROMPT.strip()},
            {"role": "user", "content": json.dumps(judge_payload, indent=2, default=str)},
        ],
        temperature=0,
        max_tokens=250,
    )
    return parse_judge_output((response.choices[0].message.content or "").strip())


def build_run_summary(results: List[Dict]) -> Dict:
    if not results:
        return {"average_score": 0, "score_distribution": {}, "exact_id_match_rate": 0}

    distribution = {1: 0, 2: 0, 3: 0}
    exact_matches = 0
    total_score = 0
    for result in results:
        distribution[result["judge"]["score"]] += 1
        total_score += result["judge"]["score"]
        if result["expected_ids"] == result["actual_ids"]:
            exact_matches += 1

    return {
        "average_score": round(total_score / len(results), 2),
        "score_distribution": distribution,
        "exact_id_match_rate": round(exact_matches / len(results), 2),
    }


async def evaluate_case(
    generator: CollectionGenerator,
    judge_client: AsyncOpenAI,
    judge_model: str,
    case: Dict,
    show_prompt: bool,
) -> Dict:
    location_id = case.get("location_id")
    if not isinstance(location_id, int):
        raise ValueError(f"Case {case.get('case_id', 'unknown')}: location_id must be an integer")

    location = fetch_location_by_id(generator, location_id)
    if not location:
        raise ValueError(f"Location not found for location_id={location_id}")

    system_prompt, user_message, candidate_raw_text = await call_candidate(generator, location)
    candidate_parsed, parse_error = parse_candidate_output(candidate_raw_text)

    judge = await call_judge(
        judge_client=judge_client,
        judge_model=judge_model,
        case=case,
        location=location,
        candidate_raw_text=candidate_raw_text,
        candidate_parsed=candidate_parsed,
        parse_error=parse_error,
    )

    expected_collections = normalize_expected_collections(case)
    expected_ids = sorted(item["id"] for item in expected_collections)
    actual_ids = []
    if candidate_parsed:
        actual_ids = sorted(item["id"] for item in candidate_parsed["collections"])

    result = {
        "case_id": case.get("case_id", str(location_id)),
        "location_id": location_id,
        "name": location.get("name"),
        "expected_ids": expected_ids,
        "actual_ids": actual_ids,
        "candidate_raw_text": candidate_raw_text,
        "candidate_parsed": candidate_parsed,
        "candidate_parse_error": parse_error,
        "judge": judge,
    }

    if show_prompt:
        result["system_prompt"] = system_prompt
        result["user_message"] = user_message

    return result


def print_case_result(run_number: int, result: Dict) -> None:
    print("=" * 80)
    print(f"RUN {run_number} | {result['name']} (id={result['location_id']})")
    print(f"Case: {result['case_id']}")
    print(f"Expected IDs: {result['expected_ids']}")
    print(f"Actual IDs:   {result['actual_ids']}")
    if result["candidate_parse_error"]:
        print(f"Parse error: {result['candidate_parse_error']}")
    print(f"Judge score: {result['judge']['score']}/3")
    print(f"Judge verdict: {result['judge']['verdict']}")
    if result["judge"]["issues"]:
        print("Judge issues:")
        for issue in result["judge"]["issues"]:
            print(f"  - {issue}")
    print("\n--- RAW MODEL OUTPUT ---")
    print(result["candidate_raw_text"])

    if result.get("user_message"):
        print("\n--- USER MESSAGE ---")
        print(result["user_message"])
    if result.get("system_prompt"):
        print("\n--- SYSTEM PROMPT ---")
        print(result["system_prompt"])


async def main() -> None:
    parser = argparse.ArgumentParser(description="Evaluate the collections prompt against real Supabase locations.")
    parser.add_argument(
        "--cases",
        default="test_location_cases.json",
        help="JSON file containing the evaluation cases",
    )
    parser.add_argument(
        "--runs",
        type=int,
        default=1,
        help="How many times to run the full suite",
    )
    parser.add_argument(
        "--model",
        help="Override the candidate model",
    )
    parser.add_argument(
        "--judge-model",
        help="Override the judge model. Defaults to EVAL_MODEL or the candidate model.",
    )
    parser.add_argument(
        "--show-prompt",
        action="store_true",
        help="Print the full system prompt and user message for each case",
    )
    parser.add_argument(
        "--output",
        help="Optional path to write the full JSON results",
    )
    args = parser.parse_args()

    if args.runs < 1:
        raise ValueError("--runs must be at least 1")

    cases_path = Path(args.cases)
    if not cases_path.is_absolute():
        cases_path = SCRIPT_DIR / cases_path
    if not cases_path.exists():
        raise FileNotFoundError(
            f"Cases file not found: {cases_path}. Create one from test_location_cases.template.json."
        )
    cases = load_cases(cases_path)

    generator = CollectionGenerator(user_id="test")
    if args.model:
        generator.model = args.model

    judge_client = AsyncOpenAI(
        api_key=os.getenv("EVAL_API_KEY", generator.xai_api_key),
        base_url=os.getenv("EVAL_BASE_URL", "https://api.x.ai/v1"),
    )
    judge_model = args.judge_model or os.getenv("EVAL_MODEL") or generator.model

    all_runs = []
    for run_number in range(1, args.runs + 1):
        run_results = []
        for case in cases:
            result = await evaluate_case(
                generator=generator,
                judge_client=judge_client,
                judge_model=judge_model,
                case=case,
                show_prompt=args.show_prompt,
            )
            run_results.append(result)
            print_case_result(run_number, result)

        run_summary = build_run_summary(run_results)
        print("=" * 80)
        print(f"RUN {run_number} SUMMARY")
        print(json.dumps(run_summary, indent=2))
        all_runs.append({
            "run_number": run_number,
            "summary": run_summary,
            "results": run_results,
        })

    overall_scores = [result["judge"]["score"] for run in all_runs for result in run["results"]]
    overall_summary = {
        "runs": args.runs,
        "cases_per_run": len(cases),
        "candidate_model": generator.model,
        "judge_model": judge_model,
        "average_score": round(sum(overall_scores) / len(overall_scores), 2) if overall_scores else 0,
    }

    final_report = {
        "overall_summary": overall_summary,
        "runs": all_runs,
    }

    print("=" * 80)
    print("OVERALL SUMMARY")
    print(json.dumps(overall_summary, indent=2))

    if args.output:
        output_path = Path(args.output)
        if not output_path.is_absolute():
            output_path = SCRIPT_DIR / output_path
        output_path.write_text(json.dumps(final_report, indent=2))
        print(f"\nWrote results to {output_path}")

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except Exception as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)
