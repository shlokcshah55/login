# Social Review Multi-Select Design

## Goal

Allow a user reviewing a shared TikTok or Instagram post to select and save more than one restaurant from the existing suggested restaurant list.

## Interaction

- Keep the current review screen and candidate cards.
- Replace the single selected candidate ID with a set of selected candidate IDs.
- Tapping a candidate toggles only that candidate. Selecting one candidate never clears another, including candidates with the same restaurant name.
- Keep the existing selected visual treatment and check indicator on every selected card.
- The primary action remains in the existing sticky action bar. Its label is `Confirm restaurant` for one selection and `Confirm N restaurants` for multiple selections.
- Disable the primary action when nothing is selected.
- A searched place remains an additional selection rather than clearing suggested candidates. The selected searched place can be removed before confirmation.

## Save Behaviour

- Confirm every selected suggested candidate independently using the existing place-saving path. Do not use the single-candidate helper that discards same-name alternatives.
- Save the selected searched place through the existing manual-place path.
- Mark unselected suggested candidates as discarded so the post can leave `Needs checking` after a successful confirmation.
- Preserve the shared post URL and extracted insights on every save.
- Keep successful selections saved if another selection fails. Leave the review actionable and report the failed count so the user can retry.

## Scope

This change is limited to selection state, the candidate-card toggle, confirmation copy, and batch confirmation behaviour. It does not add a separate selection mode, reorder candidates, change extraction logic, or redesign the screen.

## Verification

- Widget test: two suggested candidates can remain selected simultaneously.
- Widget test: the action label reflects the selected count.
- Provider test: selected candidates are saved even when their names match.
- Provider test: unselected candidates are discarded after successful confirmation.
- Regression tests: single selection, processing/read-only states, dismissal, and search remain functional.
