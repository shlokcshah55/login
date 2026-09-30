# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

**Pinit** — a consumer mobile app for place discovery, recommendations, maps, saving, and social context. The Flutter package is named `login` (legacy name), so all internal imports are `package:login/...`. The repo is a monorepo: a Flutter client (`lib/`), Python backend services (`api/`, `ai/`), and a Supabase project (`supabase/`).

## Commands

### Flutter client
```bash
flutter run                              # run on default device
flutter run -d iPhone                    # run on a specific device
flutter analyze                          # lint (uses flutter_lints via analysis_options.yaml)
flutter test                             # all unit/widget tests in test/
flutter test test/path/to/file_test.dart # single test file
flutter test integration_test/           # integration tests (needs a running device/simulator)
flutter test integration_test/recommendations_test.dart -d iPhone
```
Requires a `.env` file at the repo root — copy `.env.template` and fill in keys (`GOOGLE_PLACE_API_KEY`, `MAPBOX_ACCESS_TOKEN`, Firebase keys, `API_SECRET_KEY`, etc.). It is loaded at startup via `flutter_dotenv`.

### Python backend (`api/*`, `ai/*`)
Each service is self-contained with its own `venv/`, `requirements.txt`, `Dockerfile`, and `deploy.sh`. They deploy to **GCP Cloud Run** (project `pinit-10b36`, region `europe-west1`) using `functions-framework` / `gunicorn`.
```bash
cd api/<service> && ./deploy.sh          # build + deploy that service
cd api/<service> && python -m pytest     # tests live alongside code (test_*.py)
```

### Supabase
```bash
supabase start                           # local stack (project_id "login", Postgres 15 like prod)
supabase db reset                        # rebuild local DB from migrations + seed.sql
supabase migration new <name>            # create a migration file
supabase db diff --linked --schema public,rewards   # compare prod with local migrations (expect only pg_net noise)
supabase migration list                  # local vs remote history must match
supabase db push                         # apply pending migrations to production
```
- **`supabase/migrations/` is the single source of truth for the production schema, including SQL the recommender repo needs.** It starts at `20261001000000_baseline.sql`, a dump of production, plus storage policies, pg_cron jobs and privilege revokes. Older history is archived in `supabase/_archive/migrations/`, which is not replayed.
- Never change production schema through the SQL editor. MCP `apply_migration` is only for urgent fixes, and only if you commit the same SQL as a file named with the version the MCP returns (check `supabase migration list`).
- `seed.sql` holds the curated Pinit collections (stable UUIDs the onboarding wizard uses).
- CI (`supabase-replay` job) runs `supabase db reset` on every PR.

## Client architecture

Startup is a deliberate pipeline — do not add init logic directly to `main.dart`:

1. **`main.dart`** → calls `bootstrap()` and then `runApp(AppRoot(...))`.
2. **`lib/bootstrap/app_bootstrap.dart`** → `bootstrap()` does *essential* init synchronously (Firebase, dotenv, Mapbox token, Supabase). Non-critical work (notification permissions, LocationService, FCM, custom markers) is wrapped in a **`DeferredAppInitializer`** and only started after the first frame renders. Returns an **`AppDependencies`** bundle.
3. **`lib/app/app_root.dart`** → `AppRoot` wraps everything in `AppProviders`, then `MyApp` (a `MaterialApp`). `MyApp` owns the auth-state subscription, analytics session lifecycle, and the global `navigatorKey` (used by services like FCM to navigate without a `BuildContext`). Home is `AuthHandler`; named routes are declared here.
4. **`lib/app/app_providers.dart`** → the single `MultiProvider`. All app-wide state lives here.

### State management
`provider` package with `ChangeNotifier`. State is split between:
- **`lib/providers/`** — UI/app state (`UserDataProvider`, `MapStateProvider`, `LocationListManager`, `ShortlistProvider`, nav providers, etc.). `LocationListManager` is a `ChangeNotifierProxyProvider` that depends on `MapStateProvider`.
- **`lib/services/`** — stateless-ish singletons wrapping external systems (analytics, FCM, location, Google Places, recommendations API, natural-language search, plus many small `*_service.dart` feature/preference stores).

### Data layer (Supabase)
`lib/supabase/service.dart` — `SupabaseService` is a `ChangeNotifier` that is the app's data entry point. It **composes feature helpers** from `lib/supabase/helpers/` (auth, bubbles, collections, location, location_reviews, messaging, notifications, rewards, tags). When adding a data capability, add/extend a helper and expose it through `SupabaseService`; don't scatter raw client calls across the UI. `supabase_client.dart` owns the singleton client (`SupabaseClientManager`). Auth failure/signout policy lives in `auth_failure.dart`, `auth_signout_reason.dart`, `auth_stream_error_policy.dart` — session resilience is intentionally subtle (see recent git history).

### Recommendation layer
The bulk of the recommendation layer lives in /Users/sriharshavitta/Projects/pinit-recommendations
- **Service:** `pinit-recommendations-api` on Cloud Run (`europe-west2`), a FastAPI app (`start_api.py`, `src/pinit/api/routers/proximal.py`) plus a Pub/Sub worker (`src/pinit/worker/main.py`). The client calls it through `lib/services/recommendations_api.dart` (`/recommendations/proximal`, `/recommendations/bubble`, location processing).
- **Pipeline:** see its `recommedation.md`. The flow is Redis grid cache → `get_locations_with_pillars` (PostGIS KNN over `location_popularity_app` + `locations`) with `get_fill_locations` as the top-up → per-user scoring in `src/pinit/core/recommendation/`.
- **DB access:** always the **service role** (`src/pinit/integrations/supabase.py` rejects non-service keys), so RLS doesn't apply to it. It reads and writes `locations`, `location_popularity_app`, `user_location_actions`, `users`, `user_friends`, `bubble_locations`, `video_insights`, `location_similarities` (collaborative scoring plus its nightly builder), `user_recommendations` (recently-seen decay), `recommendation_candidates`, `tags` / `user_tag_affinities` (legacy pipeline) and `location_photos`. It also calls `refresh_location_quality_scores`.
- **Schema changes it needs go in this repo's `supabase/migrations/`.** Its old migrations are archived in `supabase/_archive/` in that repo. **Before dropping or changing any table, column or RPC here, grep that repo too.**

### Startup cache
`lib/services/startup_cache/` — `StartupCacheCoordinator` persists a per-user snapshot (`JsonStartupSnapshotStore`) so the home screen can paint from cache before the network resolves. It is cleared on user switch. `startup_timing.dart` records launch milestones.

### iOS share extension
The app receives shared TikTok/Instagram links via a native share extension. `MyApp` uses a `MethodChannel('com.example.srishlok.pinit/share')` to sync the current user ID into an **App Group** so the extension can attribute saves. Shared links flow into the social review pipeline (`api/social-free-processor`, `api/tiktok-processor`).

## Backend services (`api/`)
Independent Cloud Run services, each an HTTP function. Notable ones:
- **`tiktok-processor`** / **`social-free-processor`** — extract restaurant/place data from shared social posts (Playwright scraping, OCR/ffmpeg, LLM extraction via Gemini). `social-free-processor` is the newer privacy-first pipeline.
- **`process-locations`**, **`cuisines`**, **`menus`**, **`vibe-tags`**, **`collections`**, **`send-notification`**, **`notes-import`** — supporting enrichment and notification services.

## Design system (important for any UI work)
`Style.MD` is the canonical design spec and the `pinit_flutter_ui` skill (in `.agents/skills/`) defines the interaction philosophy. Key hard rules:
- **Palette:** cream backgrounds, `aubergine` (`#41133d`) replaces black, `mute` warm neutrals replace grey, single `accent` (`#ec3d2c`) used sparingly (<10% of a screen). Never pure black/white/grey. Max three colour families per screen. Use `PinitColors` / `PinitTheme` (`lib/themes/`), not raw hex.
- **Type:** Rova (display/headings, w800 for heavy), Manrope (body), DM Sans (labels/tags, uppercase). Strict role separation.
- **Feel:** gesture-first, map-native, animation-restrained, editorial. Avoid generic "AI-generated dashboard" layouts (uniform card grids, random gradients, excessive glassmorphism, borders on everything).

## Testing conventions
- `test/` mirrors `lib/` structure for unit + widget tests.
- `integration_test/` — end-to-end flows on a real device/simulator; the network is stubbed with `mocktail` + `package:http/testing` `MockClient`. Shared factories live in `integration_test/_helpers/test_fixtures.dart` (`buildLocation`, `buildUser`, `buildBubble`, ...). See `integration_test/README.md` for the per-file coverage map.

## Planning docs
`docs/superpowers/plans/` contains dated design/implementation plans (e.g. auth session resilience, social share flow). Check here for the intent behind recent multi-step features before refactoring them.
