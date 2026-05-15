"""
Broadcast a push notification to every user with an FCM token.

Fetches all (user_id, fcm_token) pairs from public.users and POSTs each one
to the deployed send-notification endpoint with the given title and body.

Usage:
    python broadcast_notification.py \
        --title "Hello" \
        --body "Something new is live" \
        [--type new_message] \
        [--endpoint https://send-push-notifications-jkqbw4i75a-ew.a.run.app] \
        [--dry-run] \
        [--concurrency 10] \
        [--metadata '{"key":"value"}']

Required env (loaded from api/send-notification/.env, repo-root .env, or shell):
    SUPABASE_URL
    SUPABASE_SERVICE_KEY
    API_SECRET_KEY
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

import requests
from supabase import Client, create_client


DEFAULT_ENDPOINT = "https://send-push-notifications-jkqbw4i75a-ew.a.run.app"
DEFAULT_TYPE = "blast"
PAGE_SIZE = 1000

TEST_USER_IDS = (
    "cb9c8a52-581b-466f-9a76-588532c4b5e9",
    "4b4538bf-b0dd-4533-ae88-0762e28e8281",
)


def load_dotenv_file(path: Path) -> None:
    if not path.is_file():
        return
    for raw in path.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        key = key.strip()
        value = value.strip()
        if (value.startswith('"') and value.endswith('"')) or (
            value.startswith("'") and value.endswith("'")
        ):
            value = value[1:-1]
        os.environ.setdefault(key, value)


def require_env(name: str) -> str:
    value = os.environ.get(name)
    if not value:
        sys.exit(f"Error: missing required env var: {name}")
    return value


def fetch_all_users(supabase: Client) -> list[dict]:
    rows: list[dict] = []
    offset = 0
    while True:
        resp = (
            supabase.table("users")
            .select("supabase_id, fcm_token")
            .not_.is_("fcm_token", "null")
            .neq("fcm_token", "")
            .range(offset, offset + PAGE_SIZE - 1)
            .execute()
        )
        batch = resp.data or []
        rows.extend(batch)
        if len(batch) < PAGE_SIZE:
            break
        offset += PAGE_SIZE
    return rows


def fetch_users_by_id(supabase: Client, user_ids: list[str]) -> list[dict]:
    resp = (
        supabase.table("users")
        .select("supabase_id, fcm_token")
        .in_("supabase_id", user_ids)
        .not_.is_("fcm_token", "null")
        .neq("fcm_token", "")
        .execute()
    )
    return resp.data or []


def send_one(
    endpoint: str,
    secret: str,
    user_id: str,
    fcm_token: str,
    title: str,
    body: str,
    notif_type: str,
    metadata: dict,
) -> tuple[str, bool, str]:
    payload = {
        "fcm_token": fcm_token,
        "user_id": user_id,
        "type": notif_type,
        "title": title,
        "body": body,
        "metadata": metadata,
    }
    try:
        r = requests.post(
            endpoint,
            json=payload,
            headers={
                "Authorization": f"Bearer {secret}",
                "Content-Type": "application/json",
            },
            timeout=30,
        )
        if r.status_code == 200:
            return (user_id, True, "ok")
        return (user_id, False, f"{r.status_code}: {r.text[:200]}")
    except requests.RequestException as e:
        return (user_id, False, f"exception: {e}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--title", help="Notification title (or use --title-file)")
    parser.add_argument("--body", help="Notification body / description (or use --body-file)")
    parser.add_argument("--title-file", help="Read title from file (avoids shell quoting issues)")
    parser.add_argument("--body-file", help="Read body from file (avoids shell quoting issues)")
    parser.add_argument("--type", default=DEFAULT_TYPE, help=f"Notification type (default: {DEFAULT_TYPE})")
    parser.add_argument("--endpoint", default=os.environ.get("SEND_NOTIFICATION_URL", DEFAULT_ENDPOINT))
    parser.add_argument("--metadata", default="{}", help="JSON object for metadata field")
    parser.add_argument("--concurrency", type=int, default=10)
    parser.add_argument("--dry-run", action="store_true", help="Fetch tokens and print counts, do not send")
    parser.add_argument(
        "--test",
        action="store_true",
        help=f"Only send to hardcoded test user ids: {', '.join(TEST_USER_IDS)}",
    )
    parser.add_argument(
        "--user-ids",
        default=None,
        help="Comma-separated supabase_id values to target (overrides full broadcast). "
             "Example: --user-ids id1,id2,id3",
    )
    parser.add_argument("-y", "--yes", action="store_true", help="Skip confirmation prompt")
    args = parser.parse_args()

    def _resolve_text(value: str | None, file_path: str | None, flag_name: str) -> str:
        if value and file_path:
            sys.exit(f"Error: provide only one of --{flag_name} or --{flag_name}-file")
        if file_path:
            p = Path(file_path)
            if not p.is_file():
                sys.exit(f"Error: --{flag_name}-file not found: {file_path}")
            return p.read_text().rstrip("\n")
        if value is None:
            sys.exit(f"Error: --{flag_name} (or --{flag_name}-file) is required")
        return value

    title = _resolve_text(args.title, args.title_file, "title")
    body = _resolve_text(args.body, args.body_file, "body")

    try:
        metadata = json.loads(args.metadata)
        if not isinstance(metadata, dict):
            raise ValueError("metadata must be a JSON object")
    except (json.JSONDecodeError, ValueError) as e:
        sys.exit(f"Error: invalid --metadata: {e}")

    script_dir = Path(__file__).resolve().parent
    load_dotenv_file(script_dir / ".env")
    load_dotenv_file(script_dir.parent.parent / ".env")

    supabase_url = require_env("SUPABASE_URL")
    supabase_key = require_env("SUPABASE_SERVICE_KEY")
    api_secret = require_env("API_SECRET_KEY")

    supabase = create_client(supabase_url, supabase_key)

    if args.test and args.user_ids:
        sys.exit("Error: --test and --user-ids are mutually exclusive")

    if args.test:
        target_ids = list(TEST_USER_IDS)
        print(f"TEST MODE — restricted to user ids: {', '.join(target_ids)}")
        users = fetch_users_by_id(supabase, target_ids)
    elif args.user_ids:
        target_ids = [uid.strip() for uid in args.user_ids.split(",") if uid.strip()]
        if not target_ids:
            sys.exit("Error: --user-ids was empty after parsing")
        print(f"TARGETED MODE — restricted to user ids: {', '.join(target_ids)}")
        users = fetch_users_by_id(supabase, target_ids)
    else:
        target_ids = None
        print(f"Fetching users with fcm_token from {supabase_url} ...")
        users = fetch_all_users(supabase)

    if target_ids is not None:
        found_ids = {u["supabase_id"] for u in users}
        missing = [uid for uid in target_ids if uid not in found_ids]
        if missing:
            print(f"Warning: no fcm_token for: {', '.join(missing)}")
    print(f"Found {len(users)} users with an fcm_token")

    if args.dry_run:
        for u in users[:5]:
            print(f"  - {u['supabase_id']} -> {u['fcm_token'][:24]}...")
        if len(users) > 5:
            print(f"  ... and {len(users) - 5} more")
        return 0

    if not users:
        print("Nothing to send.")
        return 0

    print()
    print(f"Endpoint : {args.endpoint}")
    print(f"Type     : {args.type}")
    print(f"Title    : {title}")
    print(f"Body     : {body}")
    print(f"Metadata : {metadata}")
    print(f"Target   : {len(users)} users  (concurrency={args.concurrency})")
    print()

    if not args.yes:
        confirm = input("Send broadcast? [y/N]: ").strip().lower()
        if confirm not in ("y", "yes"):
            print("Aborted.")
            return 1

    started = time.time()
    successes = 0
    failures: list[tuple[str, str]] = []

    with ThreadPoolExecutor(max_workers=args.concurrency) as pool:
        futures = [
            pool.submit(
                send_one,
                args.endpoint,
                api_secret,
                u["supabase_id"],
                u["fcm_token"],
                title,
                body,
                args.type,
                metadata,
            )
            for u in users
        ]
        for i, fut in enumerate(as_completed(futures), 1):
            user_id, ok, msg = fut.result()
            if ok:
                successes += 1
            else:
                failures.append((user_id, msg))
            if i % 25 == 0 or i == len(futures):
                print(f"  progress: {i}/{len(futures)}  ok={successes}  failed={len(failures)}")

    elapsed = time.time() - started
    print()
    print(f"Done in {elapsed:.1f}s — sent: {successes}, failed: {len(failures)}")
    if failures:
        print("\nFailures (first 20):")
        for user_id, msg in failures[:20]:
            print(f"  - {user_id}: {msg}")

    return 0 if not failures else 2


if __name__ == "__main__":
    sys.exit(main())
