# Validation log

## October 11, 2026 — visible routine deletion

- Added Delete routine beside the routine editing/duplication actions. Both this action and the existing swipe shortcut show the selected routine name in the confirmation. The detail screen returns only after the existing persistence transaction succeeds; sessions and shared exercises are not removed.
- Native test on the isolated Gym Log Studio QA simulator (iPhone 17e / iOS 27.0): opened the synthetic Push routine, verified the visible button and named confirmation, cancelled and confirmed its six exercises remained, then deleted it. Returned to the list with other routines intact; Recommended displayed Push as available again. Cold launch retained the deletion and the active nine-exercise / 27-set workout. No physical-phone data was changed.
- All **82 core tests**, **29 repository checks**, source parsing and project/plist validation passed. Normal unsigned iOS Simulator build, including the Watch companion, passed. Existing regression coverage includes recommendation deletion/re-import and use of deleted routines; no new tests were added for this UI-only entry point.
- Logs: `/tmp/gymlog-routine-delete-tests.log`, `/tmp/gymlog-routine-delete-verify.log`, `/tmp/gymlog-routine-delete-build.log`.

## October 11, 2026 — recommended routines

- Core suite: **82 tests passed**, including 12 new tests for the original five-day plan, exact provider matching, shared provider identities, historical quick-fill, transactional batch rejection, duplicate/re-add behavior, legacy backups, explicit preview omissions/replacements, optional shrug, cached detail reuse and rate-limit cooldown. Preview readiness is tested directly; unresolved, changed or repeated movements cannot be silently saved.
- Live mapping audit: inspected AscendAPI catalog names, equipment and instructions for all 20 pinned movements. Explicitly differentiated the three row variants and rear-foot-elevated split squat. Free V1 returned no verified exact dumbbell hip-thrust or dumbbell walking-lunge match; both remain visible unresolved choices. Additional detail spot checks encountered HTTP 429 and stopped. No bulk catalog/media download is implemented in the app. See [mapping audit](RECOMMENDED_ROUTINES.md).
- Normal and Local Only unsigned iOS Simulator builds **passed**, including the embedded Watch app. Repository verification **passed 29 core checks**, Swift parsing and project/plist validation. All 12 existing project/phone/Watch build configuration dictionaries remain identical; project changes only register two new Swift files. Signing, schemes and bundle IDs are unchanged.
- Native testing completed in **Gym Log Studio QA**, iPhone 17e / iOS 27.0, using synthetic simulator data. Created Push individually, then the other four routines as a batch. Included the optional shrug, omitted hip thrust explicitly, and explicitly selected `RRWFUcw` (dumbbell lunge) for the unmatched walking-lunge slot. The preview disclosed the replacement; unresolved slots disabled creation. Guide media/instructions opened and returned to the same choices. All five routines displayed Added and duplicate creation was disabled.
- Added six Push exercises to an active session: original three exercises/order retained, session became nine exercises / 27 sets, and the saved source routine stayed at three. Separately appended to that saved routine and confirmed its original order/schedule remained. Search text and a pending manual selection survived navigation through recommendations; no automatic add of the pending selection occurred. Relaunch after an app update retained created routines and the active session.
- Fixed and retested a save-time scroll jump caused by clearing visible matches before revalidation. Rows now remain visible while saving is disabled; results publish together. A gated-request regression verifies this behavior. Batch-save confirmation and Open routine links stayed visible at the footer.
- Inspected Studio light/dark and accessibility-large preview text. Fixed truncated Choose exercise / Guide actions by stacking them vertically at accessibility sizes; both labels were fully readable after rebuilding. Restored standard simulator text size after testing.
- Search observation: the first live “dumbbell lunge” query briefly showed no matches. Changing the query and repeating returned nine relevant records; a subsequent independently typed query also returned nine. This transient result was not reproduced or diagnosed, so search availability is not claimed to be infallible.
- Remaining native scope: fresh-empty-install entry, edited name/schedule save, filter retention, replacement cancellation, network retry screens, exhaustive VoiceOver/small-device combinations, and physical phone/Watch/Health acceptance. Automated coverage of validation, cache and cooldown is distinct from these manual checks.

Local logs: `/tmp/gymlog-recommendations-tests.log`, `/tmp/gymlog-recommendations-verify.log`, `/tmp/gymlog-recommendations-build.log`, `/tmp/gymlog-recommendations-local-build.log`. Test data, downloaded audit responses and logs are not committed.


## October 11, 2026 — Studio native design and user-controlled workouts

- Full Swift core suite: **70 tests passed**, including nine new regressions for optional theme/appearance preferences, unknown/legacy fallback, backup round-trip, stable draft baselines, reorder preservation/rejection, session additions/limits/history fill, deleted routine handling, and explicit lineup save preserving routine metadata changed during a workout.
- Repository verification: **29 core checks passed**, all Swift app/Watch sources parsed, project and all app/Watch plists/entitlements valid. `git diff --check` clean.
- Unsigned **Lift Log / Debug** and **Lift Log Local Only / DebugLocal** generic iOS Simulator builds passed, each including the Watch companion. All 12 existing project/phone/Watch build-setting dictionaries compare exactly equal with the original values. Original shared schemes, icon, bundle IDs and signing team preserved.
- Semantic text contrast calculation: seven foreground/background combinations in each of four theme/appearance combinations all exceed 4.5:1. Minimums: Studio light 4.75:1, Studio dark 7.14:1, Velocity light 5.35:1, Velocity dark 7.98:1. This checks palette values, not a full accessibility audit of every native control.
- After the user unlocked the Mac, installed into a newly created **Gym Log Studio QA** iPhone 17e simulator on iOS 27.0. Existing simulators and physical phone data were not modified. Created only synthetic test workout data through the UI.
- Native smoke test passed: create routine; search the live API for “dumbbell row”; select/add twice without leaving search; start workout; choose the second exercise first; enter 25 lb × 8 and complete; stay in that logger; rest appears and Skip works; return to the full lineup with the correct count.
- Native input/navigation test passed: type invalid reps using the on-screen keyboard, dismiss keyboard, leave and return. Invalid draft remains, both completion controls are disabled, and the saved completed set remains 25 × 8. Switching tabs, Studio/Velocity and light/dark preserves the focused exercise and draft.
- Native session/routine test passed: accessible Move up and native drag change session order; add Cable Crossover to the active session without closing search; Plan still shows the original two exercises/order; explicit Save lineup to routine updates it to three exercises in the session order. The session's completed count stays intact.
- Persistence and completion: update the simulator installation without deleting it and cold launch; saved theme, order, membership and completed values survive, and Train opens fresh. Finish with 1 of 9 completed sets prompts; the saved summary shows 25 lb × 8 and **200 lb volume**, with unchecked sets excluded. History's Edit sets opens correctly. Progress shows 1 workout and 200 lb volume, and the next session displays previous values.
- Visual checks: Studio light/dark and Velocity light/dark, routine overview, search, lineup, logger, reorder, summary, settings and Progress inspected. Accessibility-large text correctly switches numeric inputs to vertical layout. Fixed and rechecked narrow ordinal columns at large sizes, low-contrast secondary text, oversized system secondary buttons and cached system-menu tint after theme changes.
- Remaining: exhaustive VoiceOver/keyboard/small-device combinations, every retained ancillary feature's touch path, real locked-phone notification delivery, physical paired Watch/Health recording/metrics and App Store acceptance. These are not established by simulator builds or this focused smoke test. See [broader checklist](STUDIO_IMPLEMENTATION.md).

Local verification logs: `/tmp/gymlog-studio-tests.log`, `/tmp/gymlog-studio-verify.log`, `/tmp/gymlog-studio-build.log`, `/tmp/gymlog-studio-local-build.log`. Logs and simulator data are not committed.

## October 7, 2026 — easier add-exercise and workout-entry UI

- Replaced bottom system search with a persistent top search field; added All exercises/Saved tabs, a staged filter sheet with active count/summary, reset/cancel/apply actions, and a loading state. API search, matching, debounce, cache and pagination remain in place.
- Added readable Select/Selected/Added row states and separate labeled Guide buttons. The bottom bar shows selected count and routine, opens a pending-selection review/removal sheet, and adds without leaving the browser.
- Set entry now has larger labeled number fields with focus outlines, explicit Complete/Undo actions, completed status and a More menu for confirmed removal. Keyboard controls move between fields. The workout dock hides while numeric editing is active; its deadline-based rest state is unaffected.
- Moved reps-in-reserve under a collapsed optional-effort control, explained its meaning, and replaced Not recorded with Not set · optional. Exercise headers show completed/total sets and direct guide access.
- Unsigned normal iPhone/embedded Watch build passed; repository checks passed (29 core regressions plus Swift parsing/project/plist validation). Logs: `/tmp/gymlog-easier-ui-build.log`, `/tmp/gymlog-easier-ui-verify.log`. No new tests were added for label/layout-only changes; the existing 61-case full core suite from the preceding revision remains the latest full-suite result.
- Visual/touch validation remains **pending**. Computer Use reported the Mac locked; no screenshots, layout approval, physical-phone installation or hands-on success is claimed. Check normal/narrow widths, light/dark appearance, accessibility text, keyboard/dock transitions, filter Cancel/Apply and select/review/add once unlocked. Requirements and setup instructions updated.

## October 7, 2026 — keep search and session navigation in place

- Removed AddExerciseView’s successful-save dismissal. It now retains the browser and its query/filter/model state, clears only completed selections, updates already-added rows, announces/shows a save confirmation and provides an explicit Done exit. Save failure retains selections.
- Made RootView’s selected tab explicit session-only state. Removed Today’s foreground routine reselection and limited initial active/today selection to the view’s first appearance. Existing Watch/rest reconciliation remains active without changing tabs/navigation.
- Added a settled-query guard so returning to the browser does not clear existing results or restart the same completed search. New queries clear the guard so a cancelled intermediate search cannot suppress loading when the user returns to a previous query. Explicit refresh and Load more remain available.
- Latest core regression result remains **61 tests passed** from the same combined search/playback revision; this follow-up changes SwiftUI navigation only. Final unsigned iPhone/embedded Watch build and repository regression/parser/plist checks: `/tmp/gymlog-continuity-build.log`, `/tmp/gymlog-continuity-verify.log`.
- Hands-on continuity checks remain pending: a second Computer Use attempt still reported the Mac locked. No physical phone install or UI verification is claimed. Verify add-and-continue, guide return, background/foreground, selected tab/routine, and fresh launch when the Mac is available. A system-terminated background process also relaunches at Today, with saved data retained.

## October 7, 2026 — slower demonstrations and precise name search

- Replaced the averaged-frame UIImage loop with per-frame timing. Guides start paused at half-speed; quarter/half/normal controls, current-frame pause/resume, slider, previous/next and one-cycle replay are implemented. Preview sizing no longer enlarges 180px media to the old 300pt height. Provider source resolution remains unchanged; no HD claim. Requirements and setup instructions updated.
- Added six playback tests, including decoding a generated three-frame GIF with unequal source delays, retaining the current frame on pause/resume, single-cycle stop/replay, stepping bounds, speed changes and malformed media.
- Reproduced the search defect against the public API: full-phrase `name=dumbbell row` returned 309 fuzzy results; its first page was mostly curls/presses. Added live-taxonomy equipment inference, all-word name matching, exact/phrase/variant ranking, and a three-candidate-page cap per search action. Search totals now describe loaded matching records and disclose more available results. Saved uses the same name matching.
- Added six search regressions for excluding unrelated exercises, exact-name ordering, normalized case/punctuation/plurals/abbreviations, explicit-filter preservation, passing irrelevant pages, cache reuse and bounded requests. **61 XCTest tests passed, zero failures** (`/tmp/gymlog-search-tests.log`).
- Ran the actual `ExerciseCatalog.searchPage` client against the live provider for “dumbbell row”: **14 matching row variants, no remaining cursor**, including dumbbell bent over row, incline row and single-arm variants. No curls/presses passed the name filter. This was an isolated temporary client/cache, without changing user workout data.
- Normal unsigned iPhone/embedded Watch builds passed. The slower-player Local Only simulator build also passed. Repository regression/parser/plist checks passed. Final logs: `/tmp/gymlog-search-build.log`, `/tmp/gymlog-motion-simulator.log`, `/tmp/gymlog-search-verify.log`.
- Visual/touch checks of this revision remain pending: Computer Use reported the Mac was locked. No attempt was made to bypass the lock; no update was installed on the user’s phone. The prior October 6 UI validation does not verify these new controls. High-resolution media selection also remains unresolved because free V1 supplies only 180p GIFs.

## October 6, 2026 — ExerciseDB integration

- Replaced runtime static discovery with ExerciseDB V1 name search, combined live filters, cursor pagination and provider instructions/GIFs. Removed the old two-guide UI. Stopped catalog insertion on fresh install, launch and import; retained legacy fixture code only for sample history/tests and preserved existing saved data.
- **49 XCTest cases passed, zero failures**, including 11 new API/cache tests: encoded search/cursor/filter keys; concurrent request coalescing; disk cache across client relaunch; exact one-hour expiration and refetch; no expired offline fallback; seconds/date/default Retry-After with persisted cooldown; usable fresh cache during cooldown; corrupt/invalid payload handling; no-store and shorter max-age/Age; details/facets/GIF cache and host validation; cache clearing versus user records; distinct page/filter cache keys; stable provider identity and old-backup decoding. `/tmp/gymlog-api-tests.log`.
- Repository verification passed: 29 legacy regression checks, Swift source parsing, and project/plist checks. `/tmp/gymlog-api-verify.log`.
- Normal Health-enabled simulator build passed. Final unsigned iPhone build, including embedded Watch target, passed. Isolated Local Only simulator build passed. Logs: `/tmp/gymlog-api-build.log`, `/tmp/gymlog-api-device-build.log`, `/tmp/gymlog-api-isolated-build.log`. Existing project signing/team and bundle identifiers preserved. No phone installation was attempted.
- Hands-on UI checks used separate persistent simulator app **com.liftlog.apiqa**, iPhone 18 Pro / iOS 27.0. Created an empty routine; live initial page reported 1,500 exercises; searched curl (204 matches); selected an exercise and filtered Biceps without losing selection; loaded a second page; selected another exercise and added both in order. Reopening marked already-added exercises unavailable for duplicate selection. Saved showed the selected records without the old static catalog.
- Opened the live reverse-curl guide: real provider instructions and animated GIF displayed. Pause changed to Play. Corrected inherited button tint in result text/playback controls and inspected the corrected light appearance. Guide also opened through the active-workout options menu after app relaunch.
- Started the API-backed routine, completed a set, terminated/updated/relaunched the isolated QA app, and verified the two exercises plus completed set persisted. Fresh cached guide/search responses loaded again. Network failure/expired cache and rate-limit scenarios were verified with injected test transport/clock, not by deliberately exhausting the public API or changing the Mac’s network.
- Remaining acceptance: physical-phone browsing/media performance, extended accessibility/dark appearance for new screens, and existing physical Watch/Health acceptance. Provider availability/quota and form-instruction accuracy are not guaranteed by these checks. Free service release/commercial-use review is recorded in REQUIREMENTS.md.

## October 5, 2026 — Gym Log branding

- Applied the user-approved coral-on-charcoal kettlebell mascot and Gym Log display name. Preserved the bundle identifier, signing configuration, stored-data conventions, target and scheme names.
- Added an opaque 1024 × 1024 AppIcon catalog and registered it in all configurations and the project generator. Retained the selected original artwork in `output/branding/`.
- The normal HealthKit iPhone Debug build passed with signing disabled (`/tmp/gymlog-device-build.log`); the isolated Local Only simulator build passed (`/tmp/gymlog-simulator-build.log`). This is compile verification, not a signed physical-phone installation.
- Inspected both built plists: display name Gym Log, primary icon AppIcon, and compiled Assets.car present. Project and Info.plist syntax validation passed.
- Launched the updated isolated QA copy: Gym Log heading and the existing QA routine were present. No workout logic changed; the previous 29-case regression result remains the most recent core-test run.
- Visually verified the coral mascot and Gym Log label on the simulator Home Screen after installation.

## October 4, 2026 — hands-on simulator acceptance tests

Tested on iPhone 18 Pro / iOS 27.0 in a separately installed, disk-backed Local Only QA app (`com.liftlog.qa`). The normal app's data was not changed. The QA simulator build succeeded.

Final regression run: **29 XCTest cases passed, zero failures** (17:22 local time). Log: `/tmp/liftlog-ui-final-tests.log`.

Passed through the actual app interface:

- Created an empty, named routine, searched the library, retained selections across searches, and added Goblet squat and Dumbbell curl in order.
- Saved an 8–12 rep target and a superset; both appeared in the workout and its saved history.
- Saved workout and exercise notes. Logged weights and optional effort (2 reps left); history displayed all values correctly.
- Swapped Dumbbell curl to Band curl and used Undo. The original exercise and pair membership returned while the other exercise's note remained intact.
- Completed a set and used Undo: progress returned from 1/4 to 0/4. Completing again advanced the dock to the partner exercise.
- Followed A1, B1, A2, B2. Rest started after B1, not A1, and no timer started after the final set. The completed workout showed 4 sets and the expected 600 lb volume.
- Granted local notification permission, paused rest, added 30 seconds, and force-restarted the QA app. Notes, weights, completion, target, pair and the paused 55-second timer were restored from disk.
- Resumed rest and sent the app to the background. A “Rest complete” notification appeared; tapping it opened the saved workout with the expired timer displayed.
- Searched history using a workout note, checked an unmatched search, cleared it, and combined an exercise filter with the inclusive date range ending on the workout date.
- Deleted the test workout and used Undo; the history entry returned with its 4 sets and 600 lb volume.
- Calculated a 225 lb target with a 45 lb bar: 45 + 45 per side. Reducing the available 45 lb pairs to one invalidated the old result; recalculation returned 45 + 35 + 10 per side. A target below the bar weight showed a validation error.

No app defect was found in these exercised paths. This is a simulator acceptance pass, not exhaustive device certification. Real iPhone/Watch Health data, locked-phone and Focus notification behavior, notification cancellation timing, all Dynamic Type/VoiceOver layouts, and backup share-sheet import/export still require separate acceptance checks. Undo remains intentionally in memory and is not restored after process termination.

## October 4, 2026 — seven additional workout tools

Passed:

- 29 XCTest cases with zero failures (21 retained + 8 new). Added coverage includes alternating supersets and pair-only rest, uneven set counts, swapping pair membership, targeted undo preserving newer notes/timers and rejecting conflicts, deletion restore with Health data and single-draft protection, combined history/date-boundary filters, bounded plate inventories and non-greedy exact solutions, and new metadata round-trip/legacy decoding/validation.
- Demo and standard HealthKit simulator configurations build successfully. Local notification APIs compile in both configurations; no remote push/background entitlement was introduced.

Not yet verified:

- Physical-phone notification permission, locked/background delivery, Focus behavior and real-world cancellation timing. The service serializes request operations and updates timers after committed changes, but these are implementation properties, not proof of device delivery.
- At this checkpoint, new touch flows and disk-backed relaunch were pending. The simulator follow-up above verifies the listed paths; comprehensive accessibility layout and guide rendering remain separate checks.
- Real iPhone Health/Watch remains a device acceptance task.

Undo is intentionally one recent action in memory, not a persistent trash. See the T01–T07 acceptance checklist in REQUIREMENTS.md.

## October 4, 2026 — logging, routines, progress and guide samples

Passed:

- 21 XCTest cases, zero failures. Seven added cases cover rest elapsed time/pause/extension/round-trip; routine copy identity and temporary swap protections; Monday-based weekly goals/streaks; finished/completed-only exercise metrics; preservation of Health summaries after an empty or failed refresh; new/legacy backup fields and persistent routine order; and exact catalog matching for the two guide samples.
- Demo and normal HealthKit simulator configurations compile in Xcode 27.0. Project and entitlement plists validate.
- Updated Demo installed and launched through Simulator services successfully. This confirms process launch, not screen appearance or touch behavior.

Explicitly deferred:

- The Mac was locked when screen inspection was attempted. The user chose “Leave visual checks for later.” No claim is made that the new layout, Dynamic Type rendering, guide illustrations or touch flows have been visually verified.
- No real iPhone Health access, Watch synchronization or denied-permission test has occurred.
- New rest timer and routine-order metadata have Codable/core coverage; actual disk-backed relaunch and backup share-sheet flows remain on the acceptance checklist.
- Guide content is paraphrased from NASM (Goblet squat) and Mayo Clinic (Dumbbell biceps curl). The original schematic artwork is a two-exercise preview, not trainer-reviewed movement instruction. Full-library illustrations and animation are not included.

## October 4, 2026 — exercise library and custom routines

Passed:

- 14 XCTest cases, zero failures: empty routines, catalog identity, search/aliases and combined filters, ordered duplicate-free selection, custom schedules, preserved IDs/edits during migration, version-1 compatibility, version-2 custom-routine round-trip, and the original logging/progress calculations.
- Both Xcode 27.0 iOS Simulator builds: Demo (`DebugLocal`) and normal HealthKit (`Debug`), with signing disabled.
- Simulator first run: no assigned routines; Create routine entry point visible.
- Simulator routine creation: “Full body A”, Monday and Thursday; saved with zero exercises and a Choose exercises action.
- Simulator library: 157 entries; “incline dumbbell bench” resolves to Incline DB press; Chest and Dumbbell filters combine correctly.
- Simulator multi-select: selection retained after clearing filters and searching Goblet squat; two exercises added in selection order. Routine then offers Start and shows 0 of 6 sets.
- Fixed card grouping discovered during the screenshot inspection; both final builds include that fix.

Not verified by these checks: every edit/delete flow under all Dynamic Type sizes; actual on-disk upgrade from a previous installed version (compatibility is covered at the Codable/core level); share-sheet import/export UI end-to-end (the full JSON round-trip is tested).

Real iPhone signing, Watch data matching, and denied permissions remain device acceptance tasks. At that earlier checkpoint, exercise visuals had not been built; the later follow-up adds two samples.

## Previous Phase 1 baseline

Nine core cases passed. Normal and Demo configurations compiled for the iOS Simulator using Xcode 27.0. The user launched and reviewed the Demo app. Real-device HealthKit matching has not been verified.

## October 5, 2026 — automatic Watch recording companion

**Implemented; physical iPhone/Watch acceptance remains pending.** The user approved this phase with “go ahead.” The previous app on the user's phone must be updated; this work did not install or grant Health permissions on either physical device.

### Passed

- Combined normal **Lift Log / Debug** unsigned device build, including **GymLogWatch** for watchOS: `/tmp/gymlog-watch-device-final.log` (`BUILD SUCCEEDED`). No source compiler warnings; Xcode emitted only its unused App Intents metadata notice.
- Normal iPhone/Watch simulator build: `/tmp/gymlog-watch-simulator.log` (`BUILD SUCCEEDED`). Separate isolated QA copy also built and ran using `com.liftlog.qa`, preserving the primary app identity.
- **Lift Log Local Only / DebugLocal** simulator build, including the disabled Watch companion: `/tmp/gymlog-watch-local.log` (`BUILD SUCCEEDED`). Demo shares this compilation configuration; app-level sample guards prevent real Watch communication.
- **38 XCTest cases, zero failures**: `/tmp/gymlog-watch-tests-final.log`. Nine new tests cover fresh/expired start requests, wrong-session and duplicate/out-of-order reports, terminal-state protection, preserving logged sets/notes/finish time, unavailable metrics, sample/unrequested/imported session isolation, bounded chart transport, backward-compatible backups and malformed-report rejection. These test shared logic, not live Watch sensors or delivery.
- The existing dependency-free runner still passes **29 core checks**; all phone/Watch Swift source parses and project/entitlement/plist checks pass: `/tmp/gymlog-watch-verify.log`.
- Compared all four original iPhone target build-setting dictionaries with `/tmp/gymlog-before-watch.pbxproj`: unchanged, including `com.sandeep.gymlog`, signing style and team. Verified the built Watch product is embedded at `LiftLog.app/Watch/GymLogWatch.app`; its bundle ID is the phone ID plus `.watchkitapp`, companion ID matches the phone, minimum watchOS is 10.0, and Workout processing is declared.
- Hands-on iPhone 18 Pro / iOS 27 simulator check in the isolated QA app: existing QA routine/history survived the update; Settings shows Apple Health & Watch and the opt-in toggle; no paired Watch produces an explicit pairing explanation; routine logging still works; completing one 20 lb × 10 set and finishing a partial routine automatically opens its summary with **200 lb volume** and **No saved Watch recording**. No fabricated heart-rate/calorie values appeared. The unsigned simulator Health request reported a missing entitlement, so this checks the failure path rather than successful Health authorization.

### Recovery / data behavior implemented

- A Watch session carries the Gym Log session UUID; shared report sequencing prevents stale transport deliveries from replacing newer data. Metadata and a sync identifier support exact-workout recovery and avoid saving another builder for an ambiguous restart.
- iPhone stores start/finish/discard intent. WatchConnectivity carries durable terminal requests and final reports; HealthKit mirroring carries live snapshots. App relaunch reconciles saved/deleted phone logs with pending commands. The Watch persists recording identity and uses HealthKit active-session recovery.
- An offline Watch may continue recording until it receives Finish or the user ends it on the Watch. This is disclosed, and measurements retain the actual recording interval. Logged sets save before waiting for Watch delivery.
- Import/reset cannot replace an unresolved owned recording. Imported Watch records are snapshots; they do not control sessions. Undo after discarding a draft restores the sets without restarting a discarded Watch recording. Finished-history deletion never deletes Health data.

### Still requires physical-device verification

- New Watch target provisioning and installation with this Personal Team, including any Watch Developer Mode prompt.
- Watch Health authorization, phone-triggered launch, live sensor readings, automatic stop/save, final summary delivery and exactly one Health/Fitness workout.
- Denied/missing measurement permissions; Watch off wrist/locked; another workout active; disconnection/reconnection; phone/Watch process termination and recovery; stop requests arriving late; Health save failures and locked-device save results.
- Watch UI on actual screen sizes and accessibility settings. No Watch simulator runtime is installed on this Mac (only iOS devices are available), so no paired Watch simulator or physical Watch UI test is claimed.

Follow the one-time setup and short acceptance workout in `SETUP.md`. Do not treat passing unsigned builds and shared-logic tests as proof of real Watch behavior.

## October 5, 2026 — physical Watch installation blocker

- The latest signed Debug iPhone build installed successfully on the physical iPhone at 12:52 local time; Mac installation logs report success. The user reports that tapping Install in the iPhone Watch app returns to Install.
- Inspected the actual Xcode DerivedData product: the iPhone app embeds `Watch/GymLogWatch.app`; the Watch companion identifier matches the iPhone, and both code signatures pass `codesign --verify --deep --strict`.
- Decoded both embedded provisioning profiles with `security cms`. Each contains one provisioned device: the user's iPhone. **The Watch app's profile does not contain the physical Watch UDID discovered in pairing logs.** Profiles are unexpired (October 5–12). This is a concrete development-installation authorization blocker, not an app compile failure.
- Earlier Mac logs record two successful manual Watch pairings. The user confirms the Mac remains listed on the Watch. Nevertheless, `devicectl list devices` omits the Watch, and querying its known UDID returns CoreDevice error 1000, “The specified device was not found.” The underlying discovery/reconnection cause remains undetermined.
- Required resolution: register the Watch with the development team and regenerate its development provisioning profile, rebuild, then retry installation. The normal automatic registration route remains blocked by Xcode not discovering the Watch. Installation through the phone does not remove the requirement for Watch authorization.
- No physical Watch installation error log was captured; the missing UDID does not establish whether an additional phone-to-Watch transport failure occurs. Watch Health/sensor acceptance is still pending. No pairing records, certificates, app data, or system permissions were reset.
- Apple references: [device IDs missing from provisioning profiles](https://developer.apple.com/library/archive/technotes/tn2319/) and [Apple engineer on a missing Watch destination preventing provisioning](https://developer.apple.com/forums/thread/769364).

## October 5, 2026 — button readability and layout

- Reproduced the reported visibility problem in the isolated iPhone simulator app: Create routine was a white shape with an unreadable white label in dark appearance. Root `.tint(.primary)` and prominent buttons relied on incompatible system-selected foreground/background colors.
- Added an explicit primary action style with dark text on coral/routine fills, separate legible disabled colors, multiline labels, and a minimum 48-point height. Applied it to Create/Resume, Start/Finish, Complete set and library Add. Replaced the root primary tint with appearance-aware action colors. Calculated unpressed enabled label/fill contrast is at least 4.6:1 across the five routine colors and brand coral.
- Rest controls stack at accessibility Dynamic Type sizes and have a minimum 44-point layout height. Moved status banners above the tab container after observing them overlap the navigation heading. Replaced the oversized empty-routine placeholder with a compact panel to keep Create routine visible at the tested larger text size.
- Final normal simulator build passed: `/tmp/gymlog-buttons-build.log`. Final unsigned iPhone build including embedded Watch target passed: `/tmp/gymlog-buttons-device-build.log`. Only the existing unused App Intents metadata notice remains. No model, persistence, Health or workout-calculation changes; no new logic tests were added for these presentation changes.
- Visual checks through Device Hub used isolated bundle `com.liftlog.qa` with temporary sample data, preserving the physical phone and production simulator app. Verified dark-mode Create, enabled/disabled library Add, Start, multi-line Complete set, rest actions and Finish; light mode at standard and extra-extra-extra-large text; dark mode at accessibility-medium text. Completed three sample sets to verify the dock switches to Finish. Final first-routine panel and banner layout checked at accessibility-medium/dark and standard/light. Simulator text size returned to standard and keyboard capture turned off.
- Real iPhone appearance remains to be checked after the user installs this update with Lift Log → physical iPhone → Command-R. No Watch UI changes or physical Watch visual/Health verification are claimed. These checks do not establish every screen at every accessibility size.

### Subsequent user acceptance

- The user confirmed the updated phone UI works. The reported button readability issue is resolved on their phone; exhaustive accessibility-size coverage is not implied.
- The user retried Watch detection and it still failed. Physical Watch installation and Health acceptance remain blocked. Prepare a local Apple Feedback draft and collect CoreDevice diagnostics; do not submit or upload them without explicit instruction.
- Prepared `output/watch-diagnostics/Apple-Feedback-draft.txt` with identifying account/device values omitted. The fresh device listing still omits the Watch. `devicectl diagnose` with full Mac sysdiagnose excluded failed immediately with `CoreDeviceCLISupport.DiagnoseError error 0`; its 444-byte partial ZIP contains only an error log, not useful full diagnostics. The collection failure is disclosed in the draft. Nothing has been submitted externally.

## October 10, 2026 — UX proposal preview

- Created a separate interactive wireframe with Focused set / Compact table alternatives and documented research in `UX_RESEARCH_AND_WIREFRAMES.md`. App source, storage and signing were not changed.
- Both prototype flows passed automated search/selection/filter and set-entry/undo/finish/history checks. Checked eight top-level screens at three widths in light and dark appearance for each layout (96 states): no horizontal overflow or JavaScript errors detected. Inspected rendered Today, focused logging and narrow dark compact logging images.
- This is prototype verification, not a native app test. User preference, one-handed phone usability, native keyboard, Dynamic Type, VoiceOver, real ExerciseDB calls and physical Watch/Health remain outside this check. Redesign implementation awaits review.

## October 10, 2026 — fresh visual and color directions

Velocity and Studio are separate design previews, with no changes to app implementation. Both passed scripted sample search/select/details/add and workout validation/complete/undo/rest/finish checks. Seven primary screens at three widths in both appearances for each concept (84 layout states) had no detected horizontal overflow; no JavaScript errors. Computed visible enabled text colors at 390 px met the applicable text contrast threshold in checked states. Minimum ratios were 5.35/7.98 for Velocity light/dark and 4.75/7.14 for Studio light/dark. See `UI_COLOR_DIRECTIONS.md` for scope limits. Native iOS accessibility and phone ergonomics remain unverified.

## October 10, 2026 — GitHub baseline

Before the initial GitHub import, the current project passed 61 XCTest cases, 29 core checks, Swift syntax/plist validation and an unsigned generic iOS Simulator build with the embedded Watch app using the installed full Xcode toolchain. Build and test logs remain local in `/tmp/gymlog-github-*.log`. Device diagnostics, caches and signing exports are excluded from version control. Initial sandbox-only attempts could not access compiler/SwiftUI macro services; the permitted full-toolchain reruns passed. GitHub-hosted CI is separately verified after pushing and must not be inferred from this local result.

## October 10, 2026 — selected Studio refinement

The separate Studio preview now uses compact headings/controls, a full workout lineup, arbitrary exercise selection, session/routine reordering, and theme switching on shared layout tokens. Automated preview checks passed for per-exercise draft isolation, completion/undo, preservation of logs during reorder, default session-only ordering, explicit save to the routine, add-to-session without closing search, theme/appearance state preservation and finish totals. Eight main screens across two themes, two appearances and three widths (320/390/736) had no detected horizontal overflow: 96 layout states. Reorder targets measured at least 44 × 44 px. No JavaScript errors. Rendered Train, logger, reorder and dark workout-lineup screens were inspected. Native app source is unchanged; native drag, accessibility and phone ergonomics remain pending.
