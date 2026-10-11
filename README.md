# Gym Log

Recommended routines now offer the original five-day dumbbell plan through **Add exercises → Recommended → Ready-made routines**, **Routines → Recommended routines**, and the first-routine screen. Preview one or all remaining routines, resolve any missing API matches, and create them together. See [mapping and behavior](docs/RECOMMENDED_ROUTINES.md).

Native iPhone workout tracker with offline logging and ExerciseDB discovery with your own routines, names and weekly schedule. Previously named Lift Log. The coral kettlebell mascot is the approved icon. The Xcode project and schemes retain their original Lift Log names. Real-device Health acceptance is still pending. No user accounts or analytics. ExerciseDB supplies the exercise catalog and GIFs; no third-party SDK is required.

Source and ongoing development: [GitHub repository](https://github.com/sandeep-reddy1101/gymlog). See [repository workflow](docs/GITHUB_WORKFLOW.md) and [design previews](docs/designs/README.md).

The current product agreement is [REQUIREMENTS.md](REQUIREMENTS.md); it supersedes the original fixed-plan requirement.

Open **LiftLog.xcodeproj**, then follow [SETUP.md](SETUP.md) for signing, simulator previews, HealthKit, and the acceptance walkthrough.

## Included

- Train: compact Studio design, routine selection, full workout lineup, choose any exercise, session reorder with explicit save-to-routine, previous sets, quick-fill, numeric entry, haptics, add/remove sets, retained drafts and finish confirmation.
- Progress: total/weekly workouts, volume, four-week heat map, eight-week volume chart, exercise trends, PR badges, resting heart rate and HRV.
- History: full set details, immediate editing, confirmed deletion, Watch matching/retry and heart-rate chart.
- Routines: create, rename, reorder, delete, assign any weekdays or leave unscheduled, and choose a color. Add exercises without leaving search; tab/routine/search context stays in place across ordinary backgrounding. Fresh launches open Train.
- Library: live ExerciseDB search requiring all name words, with exact names ranked first among loaded matches, muscle/body-part/equipment filters, 25-item pages, multi-select, custom entries, instructions and GIF demonstrations with half-speed default, tap-to-play, pause and frame stepping. Fresh/reset installs have no saved exercises or routines. Selected exercise records remain usable offline.
- Caching: one-hour disk cache (32 MB / 250 files), 500 ms search debounce, shared requests and persisted rate-limit cooldowns. Expired/uncached searches need internet. Settings can clear downloads without deleting workouts.
- Provider: free V1 is for non-commercial use, with AscendAPI attribution. Review licensing and a commercial plan before release; see [requirements](REQUIREMENTS.md#october-6--exercisedb-replaces-the-static-exercise-browser).
- Settings: Studio/Velocity themes, System/Light/Dark appearance, pounds/kilograms, default set count, version-2 JSON share-sheet backup, validated version-1/2 replacement import, confirmed reset, isolated sample mode.
- Apple Watch: opt-in Start/Finish from iPhone, a Gym Log Watch companion, live heart rate and estimated active energy, automatic summary and Health workout saving. Older logs retain manual matching; missing measurements stay unavailable.

Studio implementation and feature-preservation walkthrough: [docs/STUDIO_IMPLEMENTATION.md](docs/STUDIO_IMPLEMENTATION.md).

## Project structure

```text
LiftLog.xcodeproj/        Ready-to-open Xcode project and four shared schemes
LiftLog/
  LiftLogApp.swift        Launch and store recovery state
  Core/                  Records, exercise catalog, sample fixtures, calculations, validation
  Models/                SwiftData persistence; atomic saves and rollback
  Services/              App state, HealthKit queries, JSON/share-sheet support
  Views/                 Today, Progress, History, plan editor, Settings, previews
  Resources/             Info.plist, HealthKit and Local Only entitlements
GymLogWatch/             Watch workout recording, recovery, live metrics and setup UI
Tests/LiftLogCoreTests/   Core behavior, Watch protocol and compatibility tests
Scripts/                 Dependency-free project generator and core check runner
Package.swift            Core library and XCTest target (open separately in Xcode)
SETUP.md                 Practical Xcode steps and acceptance checklist
```

## Schemes

| Scheme | Data | HealthKit |
| --- | --- | --- |
| Lift Log | Persistent SwiftData | Read trends; control Watch recording and saving |
| Lift Log Local Only | Same persistent store | Disabled; no capability entitlement |
| Lift Log Demo | Temporary in-memory sample store | Sample health charts |
| Gym Log Watch | Persistent recording/recovery state on Watch | Records strength workouts and saves measurements |

The three iPhone schemes share their existing bundle identifier; the Watch companion uses that ID plus `.watchkitapp`. Demo mode never opens the persistent database. The app also has Settings → Open temporary sample mode.

## Data conventions

- Log the weight of one dumbbell consistently. Volume = entered weight × reps, without a two-dumbbell or unilateral multiplier. Store weights as kg and display the selected unit (default lb).
- Bodyweight entries record added weight only; 0 is valid. Their PR metric is best reps, including when added weight is used; Progress also lets you inspect added load. External-load volume excludes body mass.
- Weighted strength estimates/PRs use Epley weight × (1 + reps / 30); Progress also offers heaviest weight and best reps. The first session establishes a baseline. Only checked sets in finished sessions contribute to charts.
- One unfinished workout at a time. A day selection previews a workout; Start begins its timestamp. The configured default set count is filled from the most recent completed session, repeating its last completed set when more rows are needed.
- Historical exercise snapshots preserve names and muscle groups. Shared UUIDs connect sessions across days. Removing an exercise from a day keeps its library entry and history.
- Weeks start Monday in the device’s local time zone. Health summary duration/calories/heart rate cover the actual Watch recording. Heart-rate summary statistics use HealthKit, with a sample-average fallback for older matched workouts. Chart transport is bounded/downsampled without deriving calorie or summary estimates from chart points.
- SwiftData stores individual exercise, day, session, and preference objects with Codable payloads. Set arrays are owned snapshots inside each session, so replacing an array is an explicit saved change. A failed save rolls back; a failed import leaves the existing data intact. Store-open failure never auto-deletes data.

## Verification

Run `Scripts/verify.sh` from Terminal with Swift Command Line Tools. It compiles and runs the core test cases through a small assertion runner, parses all Swift source, and checks the project/plists. With full Xcode selected, `swift test` runs those cases under XCTest. See [validation results](docs/VALIDATION.md) for this revision.

Latest baseline: **61 XCTest cases and 29 core checks passed** on October 10, 2026; the unsigned iPhone simulator build with embedded Watch app also passed. Earlier hands-on simulator checks covered routines, notes, targets, supersets, Undo, rest notifications, disk-backed relaunch, history filters and the plate calculator. The October 5 branding update builds for both iPhone (unsigned) and Simulator; the compiled products contain the Gym Log display name and AppIcon assets. The user installed the earlier phone build successfully. The new combined iPhone/Watch unsigned build and simulator configurations pass; physical Watch installation, permissions and actual sensor delivery remain pending. See [the validation log](docs/VALIDATION.md).

To update source/Watch wiring after adding files: `python3 Scripts/generate_project.py` now preserves the existing iPhone build settings and delegates to `configure_watch_project.py`. Only the explicit `--fresh` option replaces the project with baseline settings. No generator is needed just to open/build the checked-in project.

The limited Watch companion is implemented under W01–W07 in REQUIREMENTS.md. See SETUP.md for installation, one-time permissions, opt-in tracking and physical-device acceptance. Full Watch set editing/rest haptics remain deferred.

## Latest improvements

- A bottom workout action completes the next set using the displayed weight/reps; automatic rest supports pause, resume, +30 seconds and skip. Configure rest and a weekly workout goal in Settings.
- Duplicate routines from their detail page or the leading swipe action. In an active exercise’s options menu, swap an unstarted movement for this workout only.
- Progress now compares recent performances and shows goal weeks, weight/reps trends and PR values.
- Health shows when Lift Log last checked, what data was readable, and a per-session match result. It cannot report the Watch’s exact sync time. Previously matched summaries survive unsuccessful refreshes.
- Exercise guides use provider instructions and on-demand demonstrations with manual playback and slower speed controls. Earlier generated illustrations/motion studies remain archived review material; they are not the current catalog source.

The rest timer persists its deadline and can send an opt-in local notification after permission is granted. Real-device Health remains unverified until the iPhone/Watch acceptance steps are completed.

## Additional workout tools

- **Undo:** the top banner reverses the latest completion, swap or workout deletion in this app run. It protects later edits and is cleared by import/reset.
- **Notes:** add workout notes above the set cards; use an exercise’s options menu for its notes. Saved notes appear in History and previous exercise notes appear next time.
- **Rep targets / supersets:** Routines → routine → exercise opens its target range and pairing options. Changes apply to the next workout. The bottom action alternates paired exercises and rests after the pair.
- **Effort:** completed sets have an optional “Reps left” picker. Blank is unknown, 0 means none left, 10 means 10+.
- **Rest alerts:** enable Background rest alerts in Settings outside sample mode and grant notification permission. These are generic local alerts; Focus/settings may silence them. Pause, skip and finish update pending alerts.
- **History:** use search plus Filters for routine, exercise and inclusive date ranges. Notes are searchable too.
- **Plate calculator:** Settings → Workout tools, or a barbell exercise’s options menu. Adjust the actual bar and available plate pairs; the result shows each side and total weight.

All new saved metadata is optional and included in backups. Simulator notification delivery and the listed touch flows passed; real-phone delivery and Focus behavior still require acceptance testing.
