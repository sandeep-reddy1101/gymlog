# Recommended routines

Implemented October 11, 2026 on `feature/recommended-routines`. The user requested the original five-day dumbbell plan as optional recommendations. This is not automatic personalization or training advice inferred from Health data. Nothing is seeded on install. The user explicitly confirmed that the two unmatched movements must remain choices in the preview: select an API exercise or omit them, with no automatic custom fallback.

## Provider mapping audit

Source: [ExerciseDB / AscendAPI free V1](https://oss.exercisedb.dev/docs), live catalog responses inspected October 11, 2026. We checked all 320 dumbbell-filtered records and the complete bounded pull-up query, then compared intended movement, equipment and instructions. The table is a curated identity index, not a bundled provider data/animation snapshot. Runtime detail fetching validates each reference before it can be used.

| Planned movement | Provider ID | Actual provider name | Equipment |
| --- | --- | --- | --- |
| Incline DB press | `ns0SIbU` | dumbbell incline bench press | dumbbell |
| Lateral raises | `DsgkuIt` | dumbbell lateral raise | dumbbell |
| Overhead DB extension | `kont8Ut` | dumbbell seated triceps extension | dumbbell |
| Pull-ups | `lBDjFxJ` | pull-up | bodyweight |
| Seated incline curl | `ae9UoXQ` | dumbbell incline curl | dumbbell |
| Goblet squat | `yn8yg1r` | dumbbell goblet squat | dumbbell |
| Single-leg DB RDL | `gKozT8X` | dumbbell single leg deadlift | dumbbell |
| DB step-ups | `aXtJhlg` | dumbbell step-up | dumbbell |
| Single-leg calf raise | `1kB3Wmk` | dumbbell single leg calf raise | dumbbell |
| Flat DB press | `SpYC0Kp` | dumbbell bench press | dumbbell |
| DB shoulder press | `znQUdHY` | dumbbell seated shoulder press | dumbbell |
| DB fly | `yz9nUhF` | dumbbell fly | dumbbell |
| Chest-supported incline row | `7vG5o25` | dumbbell incline row | dumbbell |
| DB row | `C0MA9bC` | Dumbbell Single-Arm Bent-Over Row | dumbbell |
| Rear delt reverse fly | `EAs3xL9` | dumbbell reverse fly | dumbbell |
| Seated incline hammer curl | `ByX0WxV` | dumbbell incline hammer curl | dumbbell |
| DB shrug | `NJzBsGJ` | dumbbell shrug | dumbbell |
| DB Romanian deadlift | `rR0LJzx` | dumbbell romanian deadlift | dumbbell |
| Bulgarian split squat | `qx4fgX7` | dumbbell single leg split squat | dumbbell |
| Bent-over row | `BJ0Hz5L` | dumbbell bent over row | dumbbell |

- The incline row's instructions specify chest support. The split squat's instructions specify the back foot on a bench, matching the requested Bulgarian variant. The single-leg deadlift is the hip-hinge version. Seated shoulder press and seated two-hand overhead triceps extension are made explicit in the preview. Single-arm DB row and two-arm bent-over row keep different IDs.
- DB hip thrust has no verified exact dumbbell match. The fuzzy `hip thrust` query returned thrusters and a band kneeling movement; none is used. `walking lunge` returned a bodyweight record, not a dumbbell record; it is not automatically substituted. Both slots stay unresolved until an explicit API choice or omission. No invented provider IDs or renamed media.
- Pull-up is the unassisted palms-away record. All shared movements use the same provider ID across days. Historical legacy exercises with only a similar name are not silently merged into provider records.
- The provider returned HTTP 429 partway through additional detail-endpoint spot checks. Live requests stopped; automated tests cover cooldown and retry. Catalog audit results are distinct from a claim that every runtime endpoint was exercised live.

## UX and persistence

Recommended appears in Add exercises without changing the query/filter/selection state. It is also available before creating the first routine and in Routines. Each compact list row opens a preview. The full-plan preview uses only recommendations not already created. Names and suggested scheduling can change; all exercise slots can be explicitly excluded or replaced. Optional shrugs start off. Preview labels distinguish the intended movement from the actual API record, and guide access uses the existing player.

Creation is a single validated write. Repeating it is guarded by optional `recommendedTemplateID`; deleting the routine allows re-add, and deliberate duplication creates an ordinary unmarked copy. Old backups decode without this field. Existing provider IDs from the library or historical snapshots are reused, so quick-fill/history continue. Existing active sessions, notes, pairs, logs, Health data and settings are untouched.

The alternative action from a single preview appends exercises to the current routine/session using the existing deduplicating path, preserving its metadata and prior order. Adding recommendations removes any newly-added IDs from pending manual selection when returning to search. The ordinary search and swap browser remain available; swaps do not offer whole routines. Replacement selection uses API records only.

## Requests and failures

Only included movements from opened previews are requested. The same shared actor supplies one-hour disk caching, request coalescing/pacing, provider Cache-Control, and persisted Retry-After. Shared exercises across five days therefore resolve once per fresh cache lifetime (19 unique default included matches, or 20 with the optional shrug). There are two unresolved default slots. No media is downloaded until opening a guide. Creation refreshes selected details through the same cache before committing. No expired fallback or automatic substitute is used. Missing/name/equipment mismatches require a visible choice; network/rate-limit errors stop loading and prevent a partial save. Cancelling replacement search does not apply a delayed response.

## Acceptance scope

Core tests cover plan shape/mappings, exact-match rejection, shared identities, atomic batch validation, duplicates, history reuse, optional metadata/legacy backups, preview omissions/replacements, request reuse and rate limits. See [validation log](VALIDATION.md) for build and UI status. Native checks still needed: create from an empty installation; add a whole plan after explicit omissions/replacements; add to an existing routine/session and return to its unchanged search; inspect light/dark/large text; confirm guide and retry/cancellation screens.
