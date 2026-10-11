# Gym Log requirements

Last updated: October 10, 2026. This is the current product agreement. [Original build requirements](docs/ORIGINAL_REQUIREMENTS.md) are preserved verbatim for context. Later confirmed changes in this document take precedence.

## October 10 — GitHub source control and maintenance

The user created [sandeep-reddy1101/gymlog](https://github.com/sandeep-reddy1101/gymlog) and authorized pushing and maintaining project changes there. Initialize the project history, preserve existing app identity, include source/tests/documentation/design proposals, and exclude credentials, personal device diagnostics, workout/Health exports and build artifacts. Commit and push completed work in future project sessions; use reviewable branches for substantial app work. Add automated core checks and an unsigned app build. Do not infer authorization to change visibility, publish an App Store build, merge future PRs or schedule background work. See [workflow](docs/GITHUB_WORKFLOW.md).

## October 10 — new visual direction and explicit rejected treatments

The user requested an entirely fresh, richer UI/UX and deliberate color design, independently of the current screen styling. This supersedes the earlier proposal to constrain wireframe styling to the mascot's coral palette; the approved icon itself remains unchanged.

- Exclude both attached screenshot treatments: colored vertical callout stripes and colored strokes across rounded card tops. Do not reproduce them in the new design.
- Explore new typography, information hierarchy, navigation, controls and adaptive color palettes. Compare Velocity (ink/porcelain/blue) and Studio (stone/olive/citron); do not treat either as approved until reviewed.
- Use color consistently for actions, selection and status, and pair meaningful state with labels/icons. Verify readable foreground/background pairs in light and dark appearance.
- Preserve established workout, search, persistence, API and Health behavior. Prototype simplifications do not authorize removing features.
- Keep this work as a separate interactive preview; record palette values, design rationale, checks and implementation limitations in [Fresh UI and color directions](docs/UI_COLOR_DIRECTIONS.md).

## October 10 — research and wireframes before further UI implementation

The user requested competitive research and UX wireframes before more screen changes, aiming for the quality of leading gym apps. This authorizes research, interactive prototypes and documentation; the proposed redesign remains pending review.

- Benchmark official Hevy, Strong, Fitbod and Ladder flows relevant to routine planning, exercise discovery, set logging and progress. Separate observed features from Gym Log design hypotheses; do not claim superior usability without comparative testing.
- Preview the connected routine → search/select/add → workout → finish/summary flow, plus history, progress and Watch-status placement. Compare Focused set and Compact table logging layouts.
- Keep prototypes separate from app source and real user data. Label fixture content as sample data. The app must retain API discovery, user-defined routines, cache policies, explicit set completion, state continuity and honest Health measurement availability.
- Record findings, proposed screen contracts, scope limits and review tasks in [UX research and wireframes](docs/UX_RESEARCH_AND_WIREFRAMES.md). Review the direction before implementing the proposed redesign.

## October 7 — easier exercise selection and set logging

User requested a simpler, better UI for adding exercises and entering workout logs.

- Keep a visible search field at the top of the exercise browser, with clear-search control and All exercises / Saved tabs. Put muscle/body-part/equipment controls in a dedicated filter sheet; show the active filter count/summary and offer Clear filters. Stage filter changes until Show exercises; Cancel does not apply them. Filter options still come from ExerciseDB.
- Show distinct Select, Selected and Added states with readable names and separate labeled Guide controls. Keep a bottom selection summary and Add action. Review opens the pending selection in add order and lets users remove pending items without losing the search. Add remains in the browser; Done is the explicit exit.
- Give weight and reps larger numeric fields with persistent labels, visible focus outlines, and a labeled Complete control. Show Set number and Completed / Not completed status. Completing remains explicit; typing alone does not count a set toward workout progress. Completed sets can be unchecked with Undo; destructive removal moves into the set’s More menu and keeps confirmation.
- Keyboard navigation offers Next: reps / Back: weight and Done. Hide the bottom workout dock during numeric editing and restore it after editing ends; the rest timer continues using its saved deadline. Preserve current numeric validation, units, precision, autosaving, rest timers and undo behavior. Larger accessibility sizes stack entry controls.
- Remove the confusing “Not recorded” label from set entry. Hide effort behind Add effort · optional after completion, explain reps left, and use Not set · optional for the empty value. It is distinct from weight/reps and completion status.
- Show completed/total sets in each exercise header, expose View form guide directly, and label the extra-row action Add another set. Preserve existing search matching, response cache, in-session navigation and saved workout history.

Acceptance: select across queries, review/remove and add without leaving; stage/cancel/apply filters; enter weight/reps, navigate keyboard fields, complete/undo/remove sets; check optional effort wording, narrow screens, light/dark mode and accessibility text sizes. Visual verification is required before claiming layout acceptance.

## October 7 — stay in the current screen

- Adding selected exercises saves them **without dismissing the exercise browser**. Keep the same query, filters, loaded pages and list context. Mark added rows as already added; clear only the completed selection and show an inline “Added …” confirmation. Use **Done** when the user chooses to leave. Failed saves keep selections available for retry.
- Preserve the selected tab, navigation/sheets, selected routine and search state while the app remains running, including ordinary background/foreground transitions. Do not reselect today’s scheduled routine every time the app becomes active or Today reappears. Refresh background workout/Watch services without resetting navigation.
- Returning from a guide/custom form must not automatically rerun the same settled search and clear loaded results. Explicit refresh, a changed query/filter or Load more may fetch/update results under existing cache rules.
- A fresh process launch (including after the user swipes the app away) opens Today/Home with default transient navigation. Saved exercises, routines, workout history, unfinished workouts and the response cache remain intact. iOS may also terminate a background process for resources; that follows the same fresh-launch behavior, since the app cannot reliably distinguish it from a user force-quit.
- Acceptance: add one or several exercises and keep searching; open/close a guide and custom form without losing results; switch apps and return from search, history detail and Settings; preserve a manually selected non-today routine; force-quit/reopen to Today while retaining saved data.

## October 7 — precise exercise-name search

User feedback: searching “dumbbell row” returned many unrelated exercises and hid the desired movement.

- Require all normalized query words in the exercise name. Ignore case, accents and punctuation; support common DB/BB abbreviations and exercise-word plurals. Do not mix unrelated fuzzy results into a named-exercise search. Apply the same name-matching rule to Saved.
- Infer equipment from the API’s live equipment taxonomy when it appears in the query, without overriding an explicitly chosen equipment filter. Query one meaningful movement/name word plus all selected filters; filter and rank the candidates locally. Exact normalized names rank first among loaded results, followed by phrase matches and named variants. Never invent a generic exercise when the provider only offers specific variants.
- Keep 500 ms debounce, shared requests, one-hour cache and cooldowns. Read at most **three provider pages (25 candidates each)** per search/load-more action, stopping once at least 25 relevant matches are found or results end. No bulk catalog preload. Preserve the next cursor and show “more available” when the search is incomplete; do not present the provider’s broad fuzzy total as the count of matching exercises.
- Counts and ordering describe loaded matches; a name on later pages may appear after Load more. Empty partial results must explicitly offer continuing the search. Exact-name relevance does not promise typo correction, semantic synonyms or complete coverage of movements absent from the provider.
- Regression example: the original full-phrase provider query returned 309 candidates headed by curls/presses. The revised client returned all 14 dumbbell-row variations in a live check, with no remaining pages. Include word order, case/hyphens, DB rows, exact-name priority, explicit filters, pagination bounds and cache reuse in tests.

## October 7 — clearer, slower exercise demonstrations

User feedback: provider GIFs lack clarity and play too quickly to understand. This supersedes autoplay behavior in API08.

- Start guides paused. Default playback speed is **½×**, with **¼× / ½× / 1×** controls. Preserve each GIF frame’s individual delay, including deliberate holds; do not average timing across the frames.
- Play one cycle, stop on the final frame, and offer Replay. Pause preserves the displayed frame; resuming continues from it. Include a frame slider and Previous/Next frame controls for studying positions without animation. Frame controls are not labeled as instruction steps because the provider supplies no frame-to-instruction mapping.
- Pause when leaving the guide, backgrounding the app, or enabling Reduce Motion. Manual play is available; no automatic movement is required to read the guide.
- Avoid stretching low-resolution GIFs into the previous large preview. Show actual source dimensions and clearly disclose limited source detail. Keep provider instructions and attribution.
- The free V1 source is limited to **180p GIFs**, per [provider documentation](https://oss.exercisedb.dev/docs). Slower playback and smaller display do not restore missing image detail. A sharper source remains unresolved and requires a separately chosen provider/media plan; no purchase, provider switch, fabricated in-between frames, or claimed HD upgrade is authorized by this change.
- Retain the existing one-hour cache and saved workout identities. Playback controls make no additional network requests.

## October 6 — ExerciseDB replaces the static exercise browser

The user rejected the generated motion preview and requested the public [ExerciseDB API](https://oss.exercisedb.dev/docs), including response caching and a chosen TTL. These requirements supersede the static library and illustration decisions below. The approved app icon stays unchanged.

| ID | Requirement / implementation decision |
| --- | --- |
| API01 | New discovery, exercise names, filter choices, instructions and animations come from free ExerciseDB V1. No bundled exercise list or generated illustration is a fallback for online search. User-created exercises remain supported. Routines, dates and logged sets are still user-defined. |
| API02 | Search by exercise name with combined target-muscle, body-part and equipment filters. Fetch filter values from the API. Debounce typing by 500 ms; browse in pages of 25. Named search checks up to three candidate pages per user action as specified in the October 7 revision. Keep selected exercises across searches; prevent duplicates in a routine/workout. |
| API03 | Use a shared on-device disk cache for valid successful search pages, filters, details and requested GIFs. TTL is **one hour** from fetch, shortened by provider Cache-Control where supplied. Refetch an expired entry when it is requested again; no background polling or bulk downloads. Pull to refresh uses fresh cache and refetches expired entries. |
| API04 | Coalesce identical in-flight requests, space network starts by at least 600 ms, and respect HTTP 429 Retry-After (seconds or HTTP date; fallback 60 seconds). Persist cooldown across launch/cache clearing. Cache hits remain usable during cooldown. These safeguards reduce calls; they cannot guarantee avoiding the provider’s unpublished quota. |
| API05 | Limit disposable cache to 32 MB / 250 response files, evict old/expired/corrupt entries, and offer Settings → Clear downloaded exercises. Do not store errors as successful results. Expired cache is not an offline fallback. Show explicit loading, no-match, network, missing-exercise and rate-limit states with user-triggered retry. |
| API06 | Keep existing routines, IDs, edits, workout history and backup compatibility intact. Fresh install/reset starts with no exercises or routines; import/launch must not inject the old 157-entry catalog. Keep only selected exercise identity/name/muscle/equipment metadata in user records. Instructions/GIFs are disposable cache. Saved exercises can be selected and logged offline. Legacy fixtures remain solely for sample history/tests. |
| API07 | Derive stable local UUIDs from provider IDs; preserve provider identity in version-2 backups and historical snapshots. Do not guess matches between old exercise names and provider variants. Existing legacy exercises keep their original history; adding an API variant can create a distinct exercise. |
| API08 | Show provider instructions and an on-demand GIF from library play buttons, routine exercise editing, and active-workout options. Include play/pause, respect Reduce Motion, bound decoded image size and show media errors without hiding instructions. Remove the old static guide UI. |
| API09 | Credit AscendAPI in the browser, guide and Settings. Send only search/filter/provider identifiers to the service; do not send Health data, sets, routine titles or workout history. No new account/API key is required for free V1. |
| API10 | The free service’s published documentation limits it to non-commercial use and requires attribution; availability and numeric quotas are not guaranteed. This integration is for the current prototype. Review a commercial provider/plan and its terms before a monetized/App Store release. Paid V2 has a different schema and is not a drop-in URL switch. |

Acceptance: search and combine live filter values; preserve selections across queries; load another page without duplicates; view instructions and play/pause GIF; add an exercise and log it; reopen without losing selected records; reuse fresh disk responses offline; refetch after one hour; honor persisted 429 cooldown; verify old backups and history survive. Physical phone/Watch acceptance remains separate.

## October 5 — approved branding

- Public display name: **Gym Log**.
- Approved app icon: the friendly flexing kettlebell mascot, **coral on charcoal**, with a cream face. The user selected this color variant on October 5.
- Apply the name to the Home Screen, app headings, permission descriptions and notifications. Preserve the existing project/scheme names and app identity so branding does not change storage or signing.
- Keep the selected master artwork at `output/branding/gym-log-mascot-coral-master.png`; the bundled 1024 × 1024 opaque icon is `LiftLog/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png`.
- The icon selection does not authorize a broader screen redesign. App Store name availability remains a release-preparation task.

## October 5 — physical-phone feedback

- Button text must remain visible in light and dark appearance, including enabled, disabled and pressed states. Primary actions use explicit contrasting foreground/background colors, labels wrap at larger text sizes, and controls keep comfortable touch targets. Cover Create/Resume, Start/Finish, Complete set and the exercise-library Add action. Rest controls stack at accessibility sizes. Status banners must not cover navigation headings; the first-routine prompt should keep its action close to its description. This is a readability/layout revision; no exercise artwork changes or data migrations.
- The user confirmed that Gym Log is installed and visible on their iPhone. Successful real Health reads and workout matching still need to be demonstrated on that phone.
- After the readability update, the user confirmed “checked the UI works.” Record the phone UI issue as user-verified resolved; this does not verify Watch installation or Health recording. The user retried Watch detection and it still failed.
- The user does not like the two exercise illustrations (Goblet squat and Dumbbell curl). These samples are **not approved for final use**. Choose a replacement visual style and review a new small sample before any full-library rollout. The existing illustrations have not yet been replaced or removed; this feedback does not change the approved kettlebell app mascot.
- Subsequent visual review: the user approved the new realistic, subtly shaded fitness-illustration direction shown in the two-pose dumbbell curl preview. Preserve that reference at `output/visual-previews/dumbbell-curl-v1/approved-style.png`. They requested an intermediate-frame motion experiment before integration. The first preview uses 12 generated poses, played forward/backward with a slower lowering phase; GIF/MP4 previews are stored alongside the reference. Approval of the still-image style does not approve the motion, exercise-form accuracy, library rollout, or app integration. Keep the existing app untouched until the user approves integration.

## October 5 — approved automatic Watch tracking

Status: **implemented and build-checked; real iPhone/Watch acceptance pending**. The user explicitly approved development with “go ahead.” The installed phone app needs an update and the companion needs installing. This approval supersedes the earlier deferral for the limited purpose of starting, recording and ending a Gym Log workout.

- **W01 — One start:** After one-time installation of a Gym Log watchOS companion and Health authorization, tapping Start on a routine on the iPhone should launch the companion and start a strength-training workout on the paired, worn Apple Watch. The user should not have to start Apple's Workout app separately. Show whether Watch recording actually started; logging remains usable if it cannot start.
- **W02 — Live measurements:** Collect heart rate and active-energy estimates through a Watch workout session and show available measurements in Gym Log while logging sets. Use Apple's recorded/estimated values; do not invent calories from sets, reps or elapsed time. Passive Health reads alone do not guarantee continuous heart-rate samples or session-specific calories.
- **W03 — One finish:** Finishing the routine on the iPhone should stop the linked Watch recording, save a single workout to Apple Health, and attach its summary automatically. No normal-flow manual matching or separate Apple Workout stop is required. Explicitly handle a disconnected Watch, pending finish, delayed results and saving failures.
- **W04 — Summary:** Show session duration, estimated active calories, average and maximum heart rate, a heart-rate chart, and the existing completed sets and volume. Mark unavailable measurements as unavailable rather than zero; retain the routine log when Health recording fails.
- **W05 — Identity and recovery:** Associate the Watch recording with the exact Gym Log session, prevent duplicate starts/saves, and recover connection interruptions without attributing another workout's data to this session. Preserve existing routines, history, bundle identity and user signing settings.
- **W06 — Setup and scope:** Explain the one-time Watch app installation and Health read/write permissions. Recording a workout adds Health writes to the current read-only integration. Demo and Local Only must not start real Watch workouts. Full Watch exercise/set editing and Watch rest haptics remain deferred.
- **W07 — Acceptance on real devices:** With Apple's Workout app closed, start a routine on the phone, verify Watch recording and live readings, log a set, and finish on the phone. Confirm recording stops, an automatic summary appears, and exactly one workout is saved in Health/Fitness. Also test unavailable Watch, denied/missing measurements, disconnect/reconnect, app relaunch and delayed save before calling this complete.

Implementation approach: Apple's [multi-device workout APIs](https://developer.apple.com/videos/play/wwdc2023/10023/) launch the Watch companion from the iPhone and mirror the session; [Watch workout sessions](https://developer.apple.com/documentation/healthkit/running-workout-sessions) collect sensor data. Compatibility and physical-device behavior still need verification during implementation.

### Watch implementation decisions and limitations

- Minimums: iOS 17 and watchOS 10. A single watchOS app target is embedded in the existing iPhone product, with a separate **Gym Log Watch** scheme. Existing iPhone bundle/signing values are preserved; the Watch ID is the phone ID plus `.watchkitapp`.
- Opt in once through **Settings → Use Apple Watch for workouts**. Open Gym Log on the Watch and allow its Health permissions. Start uses `HKHealthStore.startWatchApp`, records `.traditionalStrengthTraining` indoors, and uses `HKWorkoutSession` plus `HKLiveWorkoutBuilder`. The Watch permission request covers writing workouts/heart rate/active energy and reading its workout metrics. Resting-HR/HRV queries on iPhone remain read-only.
- Use HealthKit mirroring for live delivery and WatchConnectivity for the session-ID handshake, durable finish/discard requests and final summaries. Starts require a fresh phone launch/request (expires after two minutes); old background messages cannot start recordings. Terminal results and sequence numbers prevent stale/duplicate deliveries from rolling back state. Save metadata includes the Gym Log session UUID and a HealthKit sync identifier.
- The Watch collects metrics only after actual recording starts. Never fabricate measurements for setup time. A disconnected Watch can continue recording after the phone finishes; show pending status and an End recording fallback on the Watch. On delayed finish, retain and disclose the actual recording interval instead of backdating measurements. Saving errors preserve the local sets and show an explicit failure.
- Finish opens the workout summary immediately. Available readings update it when the Watch reports completion. Missing values display **—**, never fabricated zero. Calories are explicitly estimates. Chart points are bounded/downsampled for transport; average/max come from HealthKit statistics.
- Persist command intent on iPhone and recording identity/state on Watch; reconcile finished/deleted phone sessions on relaunch and use HealthKit active-workout recovery on Watch. An ambiguous recovery never creates another workout. Exact-metadata refresh is available for a delayed saved workout; overlapping third-party workouts are not substituted for a Gym Log recording.
- Import/reset are blocked while an owned recording or stop request is unresolved. Imported recording snapshots cannot start/stop a Watch session or receive live updates. Undo after discarding a tracked draft restores its sets without restarting its discarded sensor recording. Deleting finished local history does not delete Apple Health records.
- No Watch exercise editing, Watch rest haptics, new exercise artwork, new account/backend or App Store submission is included. Real sensors, permissions, pairing, recovery and duplicate-save behavior still require W07 on physical devices.

## Confirmed changes

| ID | Requirement | Decision / acceptance |
| --- | --- | --- |
| R01 | Users choose their exercises; do not assign a preset workout plan. | Fresh installs and reset start with no saved exercises or routines; discovery uses ExerciseDB. Creating a routine assigns zero exercises. No recommendations or selections are applied automatically. Existing saved routines are preserved during upgrades. |
| R02 | Provide a gym exercise library. | ExerciseDB V1 supplies the live catalog. See API01–API10. Old static entries remain only where previously saved or in sample fixtures. |
| R03 | Search and filter exercises. | Provider name search with live muscle, body-part and equipment filters; paginated results, clear controls and no-result/error states. Saved entries use the same strict name matching. |
| R04 | Add chosen exercises to a routine/day. | Select several results across searches/filters; add in selection order. Already-added items are marked and cannot be added twice. Support custom exercise creation, editing, removal from a routine, and reorder. The same exercise shares one history across routines. |
| R05 | Customize routine names and the weekly schedule. | Explicitly confirmed by the user: “Customize names and schedule too.” Create, rename, reorder and delete routines. Assign any combination of weekdays; no selected weekdays means on demand. More than one routine may use the same day. Choose an accent color. No fixed five-tab or Monday–Saturday restriction. |
| R06 | Today follows the chosen schedule. | Open the first routine in user order scheduled today. All routines remain manually selectable. If nothing is scheduled, show a rest/on-demand state. Empty routines lead to the library and cannot start a workout. New users see Create routine. |
| R07 | Preserve existing data. | Upgrades retain routine membership/order, old weekdays, exercise IDs, custom edits, history and the unfinished workout. Library additions do not replace identities. Renaming/deleting a routine does not rename/delete historical workouts or discard an active workout. |
| R08 | Capture requirements and decisions. | Keep this file current, retain the original request, and update setup instructions and validation results when behavior changes. Distinguish implemented source, tested behavior and future scope. |
| R09 | Exercise visuals. | Superseded by API08: use ExerciseDB instructions and GIFs. Generated previews remain outside the app. |
| R10 | Explain Apple Watch / Apple Health connection accurately. | Normal Lift Log includes the Watch companion under W01–W07. iPhone Health queries remain read-only; the Watch records and writes opted-in workouts. Demo uses sample data; Local Only disables HealthKit and Watch communication. Real-device tracking remains unverified until the device acceptance test passes. |

## October 4 follow-up — approved improvements

The user approved all six improvement areas, asked to hear the approach before #3, and then explicitly approved a small visual sample. These October 4 items extended Phase 1. The separate October 5 approval above adds the Watch companion and live measurements.

| ID | Requirement | Decision / acceptance |
| --- | --- | --- |
| I01 | Faster workout logging | Retain previous completed weight/rep suggestions across routines. Add a persistent bottom action showing the next unchecked exercise, set, weight and reps. Disable it while a row is being edited. Checked rows receive a subtle tint; individual completion remains available. |
| I02 | Rest timer | Default 90 seconds, user-configurable 15–600 seconds with optional automatic start. Completing a set starts/restarts rest unless all sets are complete. Support pause/resume, +30 seconds and skip. Store deadline or paused remaining time in the active session; it survives backgrounding, relaunch and backup. Remove it on finish/discard or when its completed set is removed/unchecked. Background local alerts are now approved under T05. Live Activities and a Watch timer remain deferred. |
| I03 | Exercise guidance | Superseded by API08. The two original illustrated samples are no longer reachable in the app. |
| I04 | Routine duplication and ordering | Duplicate opens an editable copy with a new routine ID, same exercise IDs/order and schedule, and “(copy)” name suffix. Save to commit; cancel makes no changes. Existing routine/exercise reorder remains; make the Edit affordance clear. Persist routine order across reloads through optional preference metadata. |
| I05 | Temporary exercise swaps | During an active workout, choose a replacement from the searchable/filterable library and confirm. Only the current session changes; routine/history remain unchanged. Prevent replacement if the original has any completed sets or the replacement is already in the workout. Unchecked entries are discarded as explained before confirmation; fill the replacement from its own prior completed history. |
| I06 | Clearer progress | Configurable goal of 1–7 workouts/week (default 3), weekly counts, goal line, consecutive goal weeks, and comparison with the prior exercise session. Current unfinished week does not break the streak; changing the goal recalculates history against the current goal. Offer estimated 1RM, heaviest weight and best-rep trends plus the last three sessions’ completed sets. Prefer exercises with history in the picker. Show the actual score and date of recent PRs. No physiological or causal recovery claims. |
| I07 | Honest Health feedback | Show last successful trends query and latest readable trend sample, explicitly not the Watch’s actual sync time (not exposed). Save per-workout check time/outcome and last successful match time. Distinguish no readable overlap, failed query and matched workout. Retain a previously attached summary when refresh returns nothing or fails. Disable unavailable access in Demo/Local Only. Do not infer granted/denied read permission. |
| I08 | UI polish | Consistent introductions, card spacing/borders, completed-set styling, clear empty states and a reachable workout action. Use system adaptive colors, native text sizes, multiline labels, VoiceOver labels and vertically stacked guide positions at accessibility text sizes. Preserve the established app navigation and routine accent palette. |

## October 4 follow-up — seven additional workout tools

The user approved all seven suggestions with “Work on all.” Existing guide artwork stays at the two-sample stage. No additional visual assets are part of this revision.

| ID | Requirement | Decision / acceptance |
| --- | --- | --- |
| T01 | Undo mistakes | Provide one visible Undo action for the most recent set completion/uncheck, exercise swap, or workout deletion/discard. Restore only the affected item, preserving other notes, logs and Health data. Refuse to overwrite that item if it has since changed, or to restore a second unfinished workout. A newer undoable action replaces the previous one. Undo is available in this app run until dismissed/replaced; it is not a persistent trash or multilevel history. Import/reset clears it. Undo/rest changes update alerts. |
| T02 | Workout and exercise notes | Add/edit notes on active and saved sessions (4,000 characters per workout; 2,000 per exercise). Explicit Save/Cancel; update the latest session rather than a stale snapshot. Exercise notes from the prior finished performance appear during logging. Notes are local and included in JSON backup; notes are not shared through notifications. |
| T03 | Rep targets and effort | Configure an optional inclusive rep range for an exercise in a particular routine. Valid bounds 1–1,000, minimum ≤ maximum. Copy to the next session as a snapshot; changing the routine does not change history/drafts. Targets do not constrain logged reps. Each completed set may record optional reps in reserve, 0–10 (10 means 10+); blank remains unknown, never zero by default. Show saved effort in History. This is user-reported effort, not an inferred measurement or training recommendation. |
| T04 | Supersets | Pair two distinct exercises within a routine, with one pair per exercise. Snapshot pairs when starting. The bottom action follows A1, B1, A2, B2. Rest starts only when the matching pair’s set is complete; unpaired remaining sets from unequal counts rest normally. All sets complete clears rest. Unchecking a paired set cancels an invalid pair rest. Removing a routine exercise removes its target/pair; duplicating retains both. A temporary swap updates only the current session’s pair, uses replacement exercise history, and clears the original exercise’s target/notes (undo restores them). |
| T05 | Background rest alerts | Off by default. Settings → Background rest alerts asks for Apple notification permission on explicit enable; Demo never requests permission or changes real alert scheduling. Schedule one generic local notification for the active deadline, without exercise or Health details. Pause, skip, finish, discard, undo, reset, replacement import and deadline extension cancel/replace it as needed. Serialize async operations to prevent old requests from reinstating a skipped timer. Reconcile on launch/foreground. A paused/expired timer has no pending alert. No server, remote push entitlement, exact-delivery guarantee or Live Activity. This rest-alert feature does not add Watch haptics. Focus/system notification settings can silence alerts. |
| T06 | Searchable history | Search routine names, exercise names and workout/exercise notes; combine with saved routine-name, exercise-ID and date-range filters. Names are historical snapshots; renamed routines keep past names. Exercise filtering uses identity across routines. Date bounds include both selected days based on local workout start time; internally the end is the next day, exclusive. Show result count, useful empty state and clear action. Unfinished sessions never appear. |
| T07 | Plate calculator | Available from Settings and barbell exercise options. Choose lb/kg, target total including the bar, actual bar weight, and available pairs of each plate size (0–12). Calculate identical per-side loading using bounded inventory and minimum plate count for the highest achievable load at/below target. State the actual total and any shortfall; never silently round up. Default bar/inventory are editable examples, not detected equipment. Changing units resets examples. Collars excluded. Calculation does not change logged weights. Accept targets 0–2,000 and bars 0–200, reject target below bar and non-finite inputs. |

### Additional acceptance checks

1. Routines → an exercise: set an 8–12 target and pair with a second exercise. Duplicate the routine, verify copied configuration, then start. Complete A1: next is B1, no rest. Complete B1: rest starts, next is A2. Try unequal set counts and unchecking a paired set.
2. Complete a set, undo it; swap an unstarted exercise, undo it; delete a finished workout, undo it. Other edited notes and Health summaries must survive. Try undo after editing the affected item: show a conflict instead of overwriting it. Try restoring a discarded draft while another workout is active: block restoration.
3. Add a workout note and exercise note, finish, and inspect History. Set reps left to 2, then clear it back to unknown. Export/import and verify all notes, targets, effort and pairs survive.
4. Search History by a note and combine routine/exercise/date filters. Include workouts exactly on both selected date boundaries; exclude drafts and the day after the range.
5. Plate calculator: 225 lb total, 45 lb bar → two 45 lb plates per side. Remove plate availability and verify an exact alternative or an explicitly lower result. A target below the bar must show an error.
6. On the phone, enable local alerts and allow permission. Start rest, background/lock, verify delivery. Repeat with pause/skip/+30 seconds/finish/undo to ensure no stale alert. Deny permission and verify logging/timer remain usable. This is pending physical-device verification.

Local notification implementation follows [Apple’s authorization guidance](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications) and [local scheduling guidance](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app).

## Retained Phase 1 requirements

| ID | Requirement | Acceptance |
| --- | --- | --- |
| B01 | Personal native iPhone app | Swift/SwiftUI, iOS 17+, SwiftData persistence, Swift Charts, HealthKit; no third-party dependencies. Install with Xcode and a free Personal Team. No App Store work. |
| B02 | Offline and private | No backend, login, accounts, analytics, subscriptions, ads, cloud sync, remote push notifications or paid-only capabilities. Opt-in local rest alerts are allowed under T05. The user chooses any system share-sheet export destination. |
| B03 | Fast set logging | Weight, reps and completion control per set; large numeric inputs; default three sets, configurable; add/remove rows. Previous-session values prefill; checking an untouched row accepts them. Light completion haptic and stronger finish feedback. Target: under one minute of interaction beyond lifting for an 18-set workout; not yet timed on device. |
| B04 | Resume and finish | Explicit Start records session start. Save valid edits immediately. One unfinished workout at a time, restored after termination. Finish requires at least one checked set; confirm partial completion. Discard requires confirmation. |
| B05 | Weight semantics | Pounds by default; lb/kg changes preserve canonical kg values. Bodyweight allows zero added weight. Dumbbells record one dumbbell consistently; barbell/machine entries use indicated total load. Volume is entered weight × reps, without doubling. |
| B06 | Progress | Total workouts, this-week count, total volume; four-week heat map; eight-week volume bars; per-exercise Epley 1RM trend or best reps for bodyweight; badges for beating prior completed performance. Only checked sets in finished workouts count. Weeks begin Monday. |
| B07 | History | List full workout/set details, show historical routine name and color, edit sets, and confirm local deletion. Derived totals and records update. Deleting locally never changes Apple Health. |
| B08 | Health read types | Workouts, heart rate, active energy burned, resting heart rate and HRV SDNN. Correct entitlement and usage descriptions. Phase 1 was read-only; W01–W07 now allow the Watch companion to save workouts, heart rate and active energy. |
| B09 | Watch matching | Find Watch-sourced traditional/functional strength workouts overlapping the log; choose greatest overlap. Attach workout duration, sample-average/max HR, active calories and HR chart. Retry from History after delayed sync. Show resting-HR/HRV trends when readable. |
| B10 | Missing Health data | App remains fully usable without Health. Empty state covers missing samples and denied access; do not claim read permission was granted or denied because HealthKit hides that distinction. |
| B11 | Backup/import/reset | JSON share-sheet export includes routines, schedules, exercise metadata, preferences, full history, active session and attached health. Validate imports before confirmed replacement. Failed import retains existing data. Reset is confirmed and now restores an empty routine collection plus library, not the old fixed plan. |
| B12 | Reinstall limits | Rebuild over the same installation/team/bundle ID where possible; deletion removes local storage. External JSON backup is required for reliable recovery. Free signing expiry and HealthKit fallback must remain documented. |
| B13 | Accessible UI | Light/dark mode, Dynamic Type, readable large numbers, generous controls and accessible labels. Signature progress ring and heat map remain. The original coral/blue/green/purple/amber palette is now selected per routine rather than tied to a fixed split. |
| B14 | Sample experience | Clearly marked in-memory sample mode and SwiftUI preview, no Watch needed. Sample History/Progress may contain fixture workouts; sample routines also begin unassigned. Sample data never mixes automatically into the real database. |
| B15 | Practical documentation | Complete source/project, short Xcode steps, free-signing setup, mock-data path and acceptance checklist. Do not represent simulator checks as proof of real-device HealthKit behavior. |

## Data and compatibility decisions

- `DayRecord` represents a user-created routine. Optional `name` and `weekdays` decode old records using their former split name and weekday. Its existing day type is retained as a color token and compatibility field.
- Sessions carry optional routine ID/name snapshots. Old sessions continue to display their original split name. Renames affect future sessions only.
- Exercise metadata adds optional equipment, alternate names and a stable catalog key. The original 22 exercises match by known names during migration, keeping their IDs and all history.
- Notes, targets, effort, superset pairs and rest-alert preference are also optional, preserving prior backups. Existing files do not acquire a target, effort rating, note or pair automatically.
- New timer, Health-check and preference metadata are optional so earlier version-1/2 payloads still decode. Old preference defaults resolve to 90-second automatic rest and a three-workout weekly goal. Exports include routine order.
- JSON exports now use version 2. Imports accept versions 1 and 2; old exports gain the current catalog without changing their chosen routine contents. New version-2 files require this updated app.
- Current bounded limits: 100 routines, 100 exercises per routine, 1,000 library entries, 100 sets per exercise, 50,000 sessions, and a 50 MB import file. Inputs outside limits are rejected before persistence.
- The catalog currently supports rep-based strength logging. Time/distance tracking, assisted-load calculations, and a dedicated cardio/timer model are not implemented by this request.

## Deferred scope

The October 5 automatic-tracking request brings the limited Watch companion, `HKWorkoutSession` and live heart-rate collection into approved scope (W01–W07); implementation builds, while real-device acceptance is pending. Full Watch set sync/editing and optional Watch haptic rest timers remain deferred. Full-library exercise visuals and animations are deferred pending review of the two I03 samples. The phone rest timer is approved under I02; Watch haptics remain deferred. Nutrition, social features, AI workout planning, cloud services and App Store distribution remain out of scope.

## Acceptance walkthrough for this revision

1. Fresh install or Demo → Today: no assigned routines. Create “Full body A”, choose Monday/Thursday and Blue; confirm it appears with that schedule.
2. Choose exercises → search “incline dumbbell bench”, filter Chest + Dumbbell; find Incline DB press. Select it, change filters and select another exercise. Add both; order matches selection.
3. Reopen the library: chosen exercises say Added. Try a nonexistent name: clear filters or create a custom exercise with muscle and equipment.
4. Create another routine, reuse an existing exercise, log and finish both. Shared last-session data and progress must connect by exercise ID.
5. Rename a routine, change its days and color; old workout names/colors stay as logged. Delete the routine after confirmation; history and any draft remain.
6. Export and reimport: verify custom names, multiple weekdays, unscheduled routines, custom exercise metadata, order and unfinished sets. Import a version-1 backup: old IDs/history remain connected and the library is available.
7. Open an ExerciseDB result’s guide, verify instructions and animation, then pause playback. Demo still labels health data as sample.
8. On a real iPhone, separately verify Health authorization, denied/missing cases, and actual Watch overlap. Simulator success does not satisfy that check.

## Acceptance walkthrough for the follow-up

1. Create a routine with Goblet squat and Dumbbell curl. Duplicate it, rename the copy, reorder routines and exercises; verify independent routine membership and shared exercise history. Reload a persistent Local Only build to check ordering.
2. Start a workout. Confirm prefilled values and last-time text. Edit a field: the bottom completion button must disable until keyboard Done. Complete a set; rest appears and the next set is offered.
3. Pause, resume, add 30 seconds and skip rest. Background and return; countdown must use elapsed wall time. Relaunch a persistent build: active session and timer survive. Finish/discard clears the timer. When local alerts are enabled and permission is allowed, a pending alert is updated with the timer; delivery can be affected by system notification settings.
4. Swap an unstarted exercise; confirm only this workout changes and the new exercise receives its own previous values. Try swapping an exercise with completed sets or choosing a duplicate: blocked.
5. Inspect Progress: weekly goal/streak, chart counts, history-first exercise picker, three metric choices, last-session difference and recent set values. Drafts/unchecked sets are excluded.
6. On a real iPhone later: grant/decline Health, finish overlapping Watch/Lift Log workouts, retry after delayed sync and inspect per-workout timestamps. A failed or empty refresh must retain a prior summary.
7. Open an ExerciseDB guide from the library and exercise options; check light/dark mode, larger text and Reduce Motion.

Validation results are recorded in [docs/VALIDATION.md](docs/VALIDATION.md).
