# Social Share Review Workflow Redesign

Date: 2026-07-20
Status: Delegated approval — implement now and iterate after review

## Objective

Rebuild the TikTok/Instagram sharing inbox around the post the user shared, the evidence Pinit extracted, and the next action required. Replace the restaurant-first fallback cards and empty search sheet with a post-first inbox and a context-rich review screen backed by the existing social post, candidate, review, and location records.

## Current-state findings

The production project currently contains:

- 24 `social_posts`, 24 `social_post_reviews`, 37 `social_post_places`, and 29 `social_post_place_reviews`;
- 16 processed posts, 6 failed posts, and 2 posts still marked processing;
- creator handles on 15 processed posts, titles/captions on 15, post-level vibes on 14, sentiment on all 16, and evidence flags on all 16;
- per-candidate names, areas, confidence, reasoning, dishes, offers, creator notes, vibe signals, and sentiment on 36 of 37 candidate rows;
- resolved `locations` rows for every pipeline-extracted candidate, which can supply cuisine, area, price, rating, and imagery;
- six failed posts with the same backend exception, `name 'cheap_ocr' is not defined`;
- two processing rows whose leases have been stale for days rather than representing active work.

The current Flutter query omits `social_posts.error`, `evidence_flags`, timestamps, and thumbnail/caption fields. The inbox then flattens each post into restaurant-shaped rows and falls back to `Restaurant not identified`, hiding creator, caption, candidate, evidence, insights, and the failure reason. It also excludes dismissed reviews and hides processing posts from the default attention filter.

The processor already fetches a caption/description and thumbnail URL in memory, but does not persist them. Medium-confidence candidates are auto-saved, so the data cannot distinguish an automatic uncertain save from a user-confirmed save.

## Considered approaches

### 1. Enrich the existing restaurant-first cards

This is the smallest change, but it continues to split one post across several rows, cannot explain post-level processing/failure cleanly, and keeps the review interaction detached from the shared post. It does not meet the request.

### 2. Post-first inbox with the existing place-search sheet

This fixes inbox context and state modelling, but the critical correction step would still open an empty sheet that loses the creator, caption, evidence, and candidate ranking. It only partially meets the request.

### 3. Post-first inbox and dedicated review screen

This is the selected approach. One card represents one shared post. Tapping it preserves context into a full review screen that ranks extracted candidates, exposes post and place insights, embeds restaurant search, and makes confirmation or dismissal explicit. Existing place saving and location catalogue infrastructure is reused.

## State model

The UI exposes exactly five user-facing states:

1. **Still processing** — the post was updated recently and the processor is actively analysing it.
2. **Needs checking** — processing completed, but one or more candidates still require a user decision, or no place was confidently matched despite usable metadata.
3. **Failed** — the processor failed, or a processing lease is stale enough that the item is no longer honestly “active.”
4. **Resolved** — all relevant candidates were confidently auto-saved or explicitly confirmed/corrected by the user. Copy distinguishes automatic saves from user confirmation.
5. **Dismissed** — the user chose not to save the post.

`social_post_reviews.status = later` remains readable for backward compatibility and maps to `Needs checking`; no new “review later” action is added.

The derived state is calculated in one model layer and shared by inbox filters, cards, review copy, actions, notifications, and tests. A candidate requires user confirmation when it is medium/low confidence, unresolved, or was not successfully auto-saved. A `confirmed_by_user` flag on the per-user place review distinguishes a processor save from explicit confirmation.

## Data model and processor changes

Add the following fields:

- `social_posts.caption text`
- `social_posts.thumbnail_url text`
- `social_post_place_reviews.confirmed_by_user boolean not null default false`

Backfill `confirmed_by_user = true` for corrected, manually added, and discarded actions. Existing plain `saved` actions remain unconfirmed because they were predominantly created by processor auto-save and cannot be proven to be user decisions.

The processor will:

- fix the transcript/frame fallback variable error by consistently passing `thumb_ocr_text`;
- retain `URLMetadata` on failure so partial creator/caption/thumbnail data survives;
- persist caption, thumbnail, creator, evidence, and user-safe processing metadata whenever available;
- auto-save high-confidence candidates only; medium-confidence candidates remain reviewable;
- write processor actions with `confirmed_by_user = false`.

The Flutter client will fetch every review status, all post context fields, candidates, per-user actions, and confirmation flags. Location IDs are batch-hydrated once and held by the provider so cards and the review screen can show real cuisine, price, area, and imagery without N+1 requests.

Raw backend exception strings are never shown directly to users. They are used only to select safe, specific copy such as “Pinit couldn’t finish analysing this post” or “Analysis stopped before a restaurant could be matched.”

## Inbox information architecture

The page remains `Shared saves`, but each row is a social-post card rather than a restaurant card.

Filters:

- **Needs checking** — actionable uncertain and failed posts;
- **Processing** — actively processing posts;
- **Recently saved** — resolved posts;
- **All** — resolved, dismissed, failed, processing, and actionable history.

The initial filter is `Needs checking` when action is required, otherwise `Processing` when active work exists, otherwise `Recently saved`.

Search matches creator, caption/title, platform, candidate names, candidate areas, addresses, dishes, creator notes, post/place vibes, hydrated cuisine, hydrated location name, and hydrated area.

## Post card design

Cards use Pinit’s cream surface, aubergine structure, soft corners, restrained depth, and DM Sans utility typography. Bright red borders and offset red shadows are removed.

Each card contains, when available:

- TikTok or Instagram icon and label;
- creator handle;
- compact status badge with icon and text;
- persisted post thumbnail, otherwise a quiet platform illustration;
- caption or short title;
- a one-sentence explanation of the state and required action;
- best candidate name/area and confidence;
- up to three high-value insight chips chosen from cuisine, dishes, vibe, area, and price;
- `Open post`;
- one state-specific action: `Review match`, `Find restaurant`, or `View saved`.

Processing cards have no destructive action. Failed and uncertain cards expose `Dismiss` as a secondary text action. Dismissed cards are visually quiet and appear only in `All`.

Cards animate with a subtle press scale and state-change cross-fade. Status is always communicated with text and icon, not colour alone.

## Review screen

The existing per-post route becomes the canonical review experience. It is a full screen so post context remains visible while the keyboard and search results are present.

Hierarchy:

1. Header with back action and current state.
2. Post hero containing platform, creator, thumbnail fallback, caption, and `Open original post`.
3. Status explanation telling the user why review is required.
4. Extracted insight section showing available dishes, cuisine, area, vibe, price, creator notes, and evidence sources.
5. Ranked candidate selector showing name, address, confidence, and the processor’s reasoning.
6. Embedded restaurant search for correcting a match or manually attaching a place.
7. Sticky thumb-zone actions: `Confirm restaurant` and `Dismiss post`.

Selecting a suggested candidate or a search result enables the primary action. Confirmation preserves the original post and all extracted context:

- existing candidate: save/confirm its location and mark `confirmed_by_user = true`;
- corrected candidate: retain the original global candidate, store the per-user corrected place, save it, and mark it confirmed;
- manual place: insert a user-added `social_post_places` row, record the user action, save the location, and complete the review.

For alternative Google matches derived from the same extracted candidate, confirming one discards only its competing alternatives. Distinct restaurants in a genuine listicle remain independent. Once no candidate requires a decision, the review becomes `reviewed` and leaves `Needs checking`.

Resolved screens remain inspectable and show what was saved. Dismissed screens are read-only except for opening the original post.

## Missing data and recovery

- Missing thumbnail: render the platform fallback without reserving a broken image.
- Missing creator: show the platform name only.
- Missing caption: use the strongest candidate/reason summary, then neutral “Shared post.”
- Missing URL: disable `Open post` and explain that the original link is unavailable.
- No insights: omit the insight section instead of showing placeholder chips.
- Stale processing: present `Failed` with “Analysis didn’t finish” rather than an indefinite spinner.
- Failed mutation: keep the selection and card in place, restore enabled actions, and show retryable feedback.
- Realtime update: merge new records without clearing the active filter, query, scroll position, or review selection.

## Accessibility

- Card semantics include platform, creator when present, state, summary, best candidate, and required action.
- Dynamic text can increase without clipping status or actions.
- Every gesture has a visible button alternative.
- Search results and candidate selection use explicit selected semantics.
- Confidence is announced as match confidence, never restaurant quality.
- Minimum tap targets and logical focus order are preserved.

## Verification

Processor:

- regression coverage for transcript and frame OCR fallbacks;
- metadata retention on failed results;
- high-only auto-save behaviour;
- persisted caption/thumbnail/confirmation source.

Flutter:

- parsing every optional field and confirmation flag;
- derived state for active, stale, uncertain, failed, resolved, and dismissed records;
- post-first filtering and search across post, candidate, insight, and location data;
- informative cards for missing thumbnail/creator/caption/URL;
- ranked candidates and embedded search;
- confirm, correct, manual add, dismiss, and automatic inbox removal;
- mixed-candidate/listicle behaviour;
- realtime state preservation;
- semantics, dynamic text, loading, empty, and mutation-error states.

Database:

- migration applies cleanly;
- RLS and grants continue to restrict review/post data to the owning user;
- authenticated update policies include both `USING` and `WITH CHECK`;
- post, place, review, and user action relationships remain intact after confirmation and dismissal.

## Out of scope

- Storing raw video, audio, OCR text, screenshots, or comments.
- Replacing Google Places search or the locations catalogue.
- Recalibrating the confidence scoring algorithm.
- Redesigning unrelated notification or home-map surfaces.
