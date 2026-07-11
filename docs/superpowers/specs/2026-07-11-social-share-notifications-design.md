# Social Share Notifications Design

Date: 2026-07-11
Status: Approved design

## Objective

Replace the persistent Home `Review shares` pill with a robust notification flow that celebrates successful TikTok and Instagram saves without interrupting normal app use. Review remains prominent only when Pinit needs help resolving a share.

## Product principles

- Successful extraction should feel automatic, trustworthy, and rewarding.
- Review is an exception state, not a required step after every share.
- A user who shares frequently should see at most one consolidated in-app signal when returning to Pinit.
- Every result remains discoverable in Profile notifications even after its in-app signal disappears.
- Realtime, push, and database delivery must converge on one deduplicated notification record.

## Outcome classification

The processor classifies each completed share before creating or updating its notification.

### Successful

A share is successful when every auto-saved place meets the configured good-confidence threshold and no unresolved candidate remains. The notification uses saved-state copy and does not create a Home review prompt.

### Needs checking

A share needs checking when it contains a low-confidence match, multiple plausible matches, or a candidate without a resolved location. The notification presents a corrective action and remains unread until opened or explicitly dismissed.

### Failed

A share has failed when processing completes without a usable candidate. The notification explains the failure and links to manual place search.

Threshold values remain processor-owned configuration. The client consumes outcome and confidence metadata rather than reproducing threshold logic.

## In-app signal

After app startup or foreground resume has settled, a coordinator checks for unpresented social-share notifications. It renders one floating card above the bottom navigation without moving Home content or blocking interaction.

### Single successful share

Example:

> Saved from TikTok
> Dishoom and 2 more places
> Review

- Cream surface, aubergine border and shadow, teal success accent.
- Restaurant thumbnail in a circular medallion; use the TikTok mark when no image exists.
- Rova is not used inside the compact card. Title and metadata use DM Sans for fast scanning.
- The card auto-dismisses after six seconds.
- The user can swipe it away immediately.
- Tapping the card or `Review` opens that social post's result in the review inbox.

### Multiple successful shares

Unpresented successful results are consolidated into a single signal rather than played sequentially.

Example:

> 4 TikToks processed
> 7 places saved
> View saves

Tapping opens the inbox filtered to the included recent results. The coordinator marks every included record as presented.

### Needs-checking or failed share

Use a restrained amber accent for uncertain results and the existing error colour for genuine processing failures. Do not use a blocking dialog. The card remains on screen until the user opens or dismisses it, or until the current app session ends. It must not replay on a later launch once marked presented.

## Notification state model

Each processed share creates one logical notification keyed by user, social post, and outcome. Its persisted metadata includes:

- notification ID;
- user ID;
- social post ID;
- platform;
- outcome: `saved`, `needs_checking`, or `failed`;
- related restaurant/location IDs;
- primary restaurant name and place count;
- confidence tier and score when provided;
- creation time;
- in-app presented time;
- read time;
- dismissed time.

The states have separate meanings:

- **Stored:** the item exists in notification history.
- **Presented:** an in-app signal has already been shown and must not replay.
- **Read:** the user opened the associated result or marked the notification read.
- **Dismissed:** the user removed the item from the visible feed without deleting the underlying share or saved locations.

When a successful signal auto-dismisses, it becomes presented and read so frequent sharers do not accumulate a misleading unread badge. It remains stored in Profile history. Needs-checking and failed items become presented but remain unread until opened, marked read, or dismissed.

## Profile notification feed

The Profile notification page adopts the supplied visual reference as structural inspiration while remaining recognisably Pinit.

### Page structure

- Warm Pinit background with a clear Rova `Notifications` title.
- DM Sans for all card content and controls.
- Notifications grouped under compact date pills such as `Today`, `Yesterday`, and formatted calendar dates.
- `Mark all read` remains available; avoid a global destructive trash button.
- Pull to refresh remains supported.

### Notification card

Each card uses a generous cream surface, rounded corners, an aubergine outline, and Pinit's offset shadow. The layout contains:

- circular restaurant thumbnail or platform/status artwork;
- small unread dot beside the title;
- strong outcome-led title;
- subdued body copy with restaurant names and counts;
- timestamp aligned without competing with the title;
- contextual action label: `View`, `Check`, or `Add place`.

Cards use outcome accents sparingly:

- teal for saved;
- amber for needs checking;
- error coral for failed;
- aubergine for neutral system notifications.

A left swipe reveals a single dismiss action. Dismissal removes the notification from the visible feed, not the saved restaurant or social post. A short undo affordance protects against accidental swipes.

### Routing

- Saved notification: open the review inbox focused on the source post or its extracted places.
- Needs-checking notification: open the unresolved result and its corrective actions.
- Failed notification: open manual place search associated with the source post.
- Consolidated in-app signal: open the inbox filtered to the included notification IDs or recent time window.

## Reliability and deduplication

- The backend owns idempotent creation using user ID, social post ID, and outcome.
- FCM data carries the canonical notification ID.
- Database refresh and realtime events merge by notification ID instead of appending duplicates.
- Repeated processor retries update the existing record.
- Routing validates that the social review and locations still exist, then falls back to the inbox with a recoverable message.
- Presentation state is persisted before or atomically with showing the card so terminated/resumed app cycles cannot replay it indefinitely.
- The coordinator limits presentation to one signal at a time and coalesces successful notifications received within the startup window.

## Analytics

Track:

- in-app signal shown, aggregated count, and outcome;
- signal tapped, auto-dismissed, or swiped away;
- Profile notification opened, dismissed, or restored by undo;
- destination successfully opened or failed;
- time from notification creation to first view;
- uncertain-share correction completion.

Do not treat successful auto-dismissal as negative engagement.

## Accessibility

- Announce outcome, restaurant name, place count, and action as one coherent semantic label.
- Do not encode outcome with colour alone.
- Support dynamic text without clipping card actions.
- Provide an accessible alternative to swipe dismissal through an overflow action.
- Pause auto-dismiss while screen-reader focus is inside the in-app signal.

## Verification

- Model parsing for FCM and Supabase records, including missing optional metadata.
- Deduplication across FCM, database refresh, and realtime delivery.
- Successful single and aggregate signal rendering.
- Presented/read/dismissed state transitions.
- No replay after app restart or foreground resume.
- Profile date grouping, unread styling, contextual actions, swipe dismissal, and undo.
- Correct routing for saved, uncertain, failed, missing-post, and missing-location states.
- Dynamic text and semantics checks.

## Out of scope

- Notification preference settings.
- Changes to processor extraction quality.
- Deleting social posts or saved restaurants from the notification feed.
- Rebuilding the review inbox; that work is specified separately.
