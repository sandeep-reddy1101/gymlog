# Run Gym Log on your iPhone

The installed app is now **Gym Log**, with the coral kettlebell mascot. Open the existing `LiftLog.xcodeproj`; its target and schemes intentionally still use Lift Log.

The iPhone app now includes a Gym Log Watch companion. The combined device build and normal/Local Only simulator builds pass in Xcode 27.0. Live recording on your actual Watch still needs the acceptance test below.

## 1. Open and sign

1. Install the latest stable Xcode from Apple, open it, and let it finish installing iOS platform support. Choose Xcode → Settings → Locations → Command Line Tools → that Xcode version if needed.
2. Open `LiftLog.xcodeproj` (not `Package.swift`, which is only the core tests).
3. In Xcode → Settings → Accounts, add your Apple Account.
4. Select the blue project → **TARGETS → LiftLog → Signing & Capabilities**. Enable **Automatically manage signing**, choose your **Personal Team**, and keep your existing identifier, `com.sandeep.gymlog`, and your selected team. Do not change them when updating this installation.
5. Select the **Lift Log Demo** scheme and an iPhone simulator. Press **⌘R**. You should see four tabs, a yellow sample-mode banner, and eight weeks of sample Progress/History data. No signing team is needed for the simulator.
6. For your phone, select **Lift Log**, connect/unlock the iPhone, enable Developer Mode if iOS requests it, choose it as the destination, and press **⌘R**. Trust your developer identity under Settings → General → VPN & Device Management if iOS asks.

Deployment targets: iOS 17.0 and watchOS 10.0. The project has an iPhone target, **LiftLog**, and its embedded Watch target, **GymLogWatch**. There are no package dependencies.

## Add a recommended routine

1. Open **Routines → Recommended routines**, or **Add exercises → Recommended → Ready-made routines**. The first-routine screen also has **Browse recommended routines**.
2. Choose Push, Pull, Legs, Upper or Lower, or **Preview all 5 routines**. After adding some, the full-plan action offers only the remaining ones.
3. Review the API exercise under each planned movement. Names are editable; **Use suggested weekdays** schedules Mon/Tue/Wed/Fri/Sat, or turn it off to leave the routines on demand. The Pull-day shrug is optional and starts excluded.
4. For an unavailable exact match, tap **Choose exercise** to select a real API exercise, or turn off **Include** to omit that movement. DB hip thrust and DB walking lunges currently need this explicit choice. A different movement is never silently substituted.
5. Tap **Create … routine(s)**. You can open each created routine immediately, edit its days/order, then return to Train and start it. Existing routines/workouts are kept. If opened from Add exercises, a single-routine preview also offers **Add … exercises to [current routine/workout]**.

To remove a saved routine, open **Routines → [routine] → Delete routine**, then confirm its name. You can also swipe left on a routine in the list. Saved workouts, any active workout and the exercise library stay available. A deleted recommendation can be added again from Recommended routines.

The first preview needs the network unless its details are still in the one-hour cache. Retry respects provider rate limits. Already saved routines work offline; preview/guide fetching still follows cache policy.

## 2. HealthKit capability and keys

The normal scheme already uses `LiftLog/Resources/LiftLog.entitlements` with `com.apple.developer.healthkit = true`. In **LiftLog → Signing & Capabilities**, confirm **HealthKit** appears. If it does not, select **+ Capability → HealthKit**. Leave Clinical Health Records and Background Delivery unchecked; neither is needed.

The explicit `LiftLog/Resources/Info.plist` includes:

- `NSHealthShareUsageDescription`: explains reading workouts, heart rate, active calories, resting heart rate, and HRV.
- `NSHealthUpdateUsageDescription`: explains that the Watch companion saves recorded workouts, heart rate and active energy. The iPhone authorization request remains read-only; the Watch requests its recording permissions separately.

Do not add duplicate plist build resources or a second generated Info.plist. The project’s **Generate Info.plist File** setting is **No**, and its **Info.plist File** points to the provided file.

Apple currently lists HealthKit under the free **Apple Developer** capability column. Actual provisioning still needs to succeed for your Personal Team. If Xcode says your team/profile cannot provision HealthKit, choose **Lift Log Local Only**, verify its **Code Signing Entitlements** is `LiftLog/Resources/LocalOnly.entitlements`, and run again. It compiles out HealthKit access through the absence of `HEALTHKIT_ENABLED`. Workout logging, local history, backups, and temporary sample charts still work; live Watch health does not. No paid membership is required for that fallback.

Sources: [Apple’s capability table](https://developer.apple.com/help/account/reference/supported-capabilities-ios/), [configuring HealthKit](https://developer.apple.com/documentation/xcode/configuring-healthkit-access), [HealthKit authorization](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data).

## Install and enable the new Watch companion

1. **Update the iPhone app:** Open `LiftLog.xcodeproj`, choose **Lift Log → Sandeep Reddy**, then **⌘R**, as before. Keep the existing app installed so its routines/history stay in place.
2. **Check the new target:** Select the blue project → **TARGETS → GymLogWatch → Signing & Capabilities**. Automatic signing and your existing team are already copied into the project. Its identifier is **`com.sandeep.gymlog.watchkitapp`**. Leave HealthKit enabled. The Watch uses the **Workout processing** background mode; HealthKit Background Delivery is not needed.
3. **Install on the Watch:** On your iPhone, open **Watch → My Watch → Apps → Available Apps** (on some versions, Available Apps is directly under My Watch). Tap **Install** beside Gym Log if it is listed. Alternatively, in Xcode select **Gym Log Watch**, choose your paired physical Apple Watch as the destination, and press **⌘R**. If it is missing, open Xcode's **Device Hub** and finish pairing/preparation for the companion iPhone and Watch. Keep both devices nearby and unlocked. Allow Xcode time to prepare the Watch.
4. **Developer Mode:** If Xcode requests it, on the Watch open **Settings → Privacy & Security → Developer Mode**, enable it, restart, and confirm on the Watch. This is required for development builds; let the device guide you through its prompts.
5. **One-time Watch permission:** Open **Gym Log on the Watch → Connect Apple Health**. Allow saving workouts, heart rate and active energy, and allow reading the workout measurements. Denying a measurement leaves that field unavailable. Saving workouts must be allowed for recording to start.
6. **Enable phone control:** In **Gym Log on your iPhone → Settings**, turn on **Use Apple Watch for workouts** and complete the iPhone Health prompt. This preference starts off for existing installations so the update does not silently begin sensor recording.
7. **Short test:** Wear your unlocked Watch. Leave Apple's Workout app closed. Start a routine in Gym Log on the phone. Wait for **Recording on your Watch**, log a set, and tap **Finish workout**. The summary opens automatically; it should update with estimated active calories, average/highest heart rate and a chart. Check that recording stops on the Watch and exactly one workout appears in Health/Fitness.

If the Watch disconnects, the phone saves your sets and keeps a pending finish request. Keep the devices nearby or tap **End recording** in Gym Log on the Watch. Until the request reaches the Watch, recording may continue; the summary explicitly identifies a delayed finish and uses the actual recording interval. A short session or denied/missing samples may show **—**. No calorie values are calculated from logged weights or reps.

**Retry Watch connection** is for a start that never confirmed. **Refresh recording status** retries pending delivery and checks for this exact Gym Log workout in Health; it does not substitute an unrelated overlapping workout. If Health setup fails on the Watch, correct permissions and use a new routine session. A failed session is not silently restarted.

The main Lift Log scheme embeds the Watch app. The separate Gym Log Watch scheme is useful for installing/debugging it directly. Local Only and Demo do not communicate with the Watch or record real Health data. To install Watch simulator support later, use Xcode's platform/component settings; a Watch simulator runtime is not installed on this Mac yet.

Apple references: [running on devices](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices), [pairing devices](https://developer.apple.com/documentation/xcode/pairing-your-devices-with-your-mac), [Developer Mode](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device), [installing Watch apps](https://support.apple.com/en-ie/109023).

## 3. Validate the implementation in small steps

Steps A–D and F check the phone features. Step E uses the newly installed Watch companion and normal HealthKit scheme described above.

| Step | What to do in Xcode / the app | What success looks like |
| --- | --- | --- |
| A · Routines and library | Run **Lift Log Local Only** on a simulator with no previous app data. Open Today. | Today offers Create routine. Create a named routine, assign weekdays, and choose exercises from the searchable library. No exercises are preassigned. Settings defaults to lb and 3 sets. |
| B · Today and saving | Create a routine, add exercises, then tap Start. Enter 40 lb × 10, check it, add a set, edit an unchecked row. Stop the app in Xcode, then run it again. | The unfinished session resumes with its sets and edits. Ring counts only checked rows. Tap Finish; confirm a partial workout if applicable. It appears in History. |
| C · Quick-fill | Add Incline DB press to two custom routines. Finish a set in the first, then start the second. | Incline DB press displays the prior completed sets and pre-fills new rows using the same shared history. Untouched checkmarks accept those values. Pull-ups accept zero added weight. |
| D · Progress and History | Use **Lift Log Demo** or Settings → sample mode. Open Progress and History. Edit a session; swipe to delete one and confirm. | Heat map, volume bars, strength trends and PR badges appear. Edits recalculate values; deletion removes that workout. Closing sample mode returns to your real data. |
| E · Apple Watch | Complete the one-time setup above. Start a routine on the phone, verify recording on the Watch, log a set, then Finish on the phone. | Sets save immediately, the summary opens automatically, Watch recording stops, and the summary shows available measurements. Exactly one workout is saved to Health/Fitness. |
| F · Settings and backup | In sample mode, export JSON → Save to Files outside Lift Log or AirDrop to your Mac. Note workout count and a set value. Reset sample data; import your saved file and confirm replacement. | Plan, settings, full history, health summaries and any unfinished session return. A malformed file is rejected without replacing current data. Repeat with a real backup before relying on it. |

To view a SwiftUI preview, open `Views/Components.swift`, enable **Editor → Canvas**, and resume **Sample app**. Select an iPhone preview destination. The preview uses in-memory sample data.

## 4. Test permission and empty states

- Decline every Health read permission. Log and finish sets anyway: the workout must save, and History should explain that no readable overlap is available. HealthKit does not reveal whether read access was denied, so the app must not claim denial with certainty.
- Grant workouts but decline heart rate: a matched workout may have missing HR; the app shows a missing-data message. Declining calories may leave calories unavailable.
- Use a fresh Local Only install: Progress has zeros and empty chart explanations, History is empty, and Settings explains the fallback.
- Change lb → kg → lb: values should represent the same weight. Complete an untouched quick-filled set in kg and confirm the stored precision is not rounded away.
- Change iPhone text size to an accessibility size and test light/dark modes. Set rows stack vertically at accessibility sizes; scroll to reach all controls. Confirm no clipped text on your actual screen.
- Once you have history, time a six-exercise routine with 18 completion taps. The under-one-minute interaction goal is not yet measured on device.

## 5. Rebuild weekly without losing data

Apple’s free Personal Team provisioning profiles expire after **7 days**. Re-run from Xcode using the same bundle identifier/team over the existing installation; an ordinary update generally retains its sandbox. Do not delete the app as part of re-signing.

Deleting the app removes its SwiftData store. Changing identity/signing, OS restores, or installation errors can also prevent continued access. No local database can guarantee survival after deletion. Export to a location outside Lift Log regularly and before changing signing or reinstalling. A backup left only inside the app’s own storage is not protection against deletion. The app itself makes no network calls; you choose the export destination in the system share sheet.

[Apple’s current Personal Team limits](https://developer.apple.com/help/account/basics/about-your-developer-account) also list 10 App IDs, 3 devices, and up to 3 apps per device for free provisioning.

## 6. Checks for developers

With full Xcode selected:

```sh
swift test
xcodebuild -project LiftLog.xcodeproj -scheme 'Lift Log' -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO build
xcodebuild -project LiftLog.xcodeproj -scheme 'Lift Log Local Only' -destination 'generic/platform=iOS Simulator' -configuration DebugLocal CODE_SIGNING_ALLOWED=NO build
```

Without Xcode, `Scripts/verify.sh` runs the Foundation-only checks, parses source syntax and checks plists. It does not validate SwiftUI rendering, SwiftData macros, or HealthKit on iOS. The app scheme has no UI-test target; `Package.swift` contains the core XCTest target.

The limited Watch recording phase is now implemented. Before relying on it, complete the physical-device test above, then check permissions denied, disconnect/reconnect, app relaunch, and duplicate finish. Simulator success does not prove these behaviors on a Watch.


## Custom routines and exercise library

See [REQUIREMENTS.md](REQUIREMENTS.md) for the current agreement and the revision acceptance walkthrough. Create a routine from Today, set its name, color and any weekdays, then choose exercises. ExerciseDB supplies name search and muscle, body-part and equipment filters; select multiple items and tap Add. The browser stays open and confirms the addition; continue searching or tap Done when finished. Switching apps preserves your current screen while Gym Log is running. A fresh launch opens Today without deleting saved data. Search matches every name word: “dumbbell row” and “DB rows” show row variants rather than curls/presses. Exact names rank first among loaded results. A search checks up to three candidate pages per action; use Load more when more results are available. An internet connection is needed for results not fetched within the past hour. Use Saved for previously selected/custom exercises offline. Routines → a routine lets you rename, reschedule, reorder or remove its exercises. The Demo has sample History/Progress but starts with no assigned routines.

Existing installations retain their previous routines and history. Delete unwanted routines individually after reviewing them; do not reset your real history just to get the new library. New exports are version 2; version-1 backups still import. ExerciseDB instructions and GIFs replace the two illustrated samples. Tap a result’s play icon, or open View exercise guide when editing a saved API exercise. Legacy exercises retain their IDs and are not automatically matched to similarly named API entries.

## Workout tools and exercise guides

- Inside a chosen exercise, the bottom action shows its next unchecked set and values. Tap to complete it; keyboard editing temporarily disables the action. Previous completed performance still prefills the exercise rows.
- Completing a set starts rest automatically unless all sets are complete. Pause/resume, +30 seconds and skip are available in the bottom panel. Set duration or turn off automatic rest in Settings → Rest & consistency. Deadlines survive leaving/reopening the app in a persistent build; optional local alerts can be enabled in Settings after granting notification permission.
- Routines → a routine → Duplicate routine opens an editable copy. Tap Edit to reorder exercises. In the active workout, an exercise’s options menu offers Swap for this workout before any of its sets are completed.
- Progress shows a weekly goal and streak, exercise weight/reps/strength trends, recent sets and record values. Set the weekly target in Settings.
- API exercise guides start paused at half speed. Choose ¼× / ½× / 1×, play one cycle, pause on the current frame, or use the slider and Previous/Next frame controls. Reduce Motion is respected. The free provider’s 180p source limits clarity; the smaller preview does not add image detail. GIFs load on demand and share the one-hour cache. Settings → Exercise library credits AscendAPI and can clear downloads. No API key is needed for the non-commercial free V1 prototype.
- Health panels report Lift Log check/read times, not a Watch sync timestamp. Real Health access still requires the Lift Log scheme on a physical iPhone.

Visual/touch checks for this follow-up were explicitly deferred by the user while the Mac was locked. Build and core tests do not verify screen layout or actual iPhone Health access. Follow the new acceptance walkthrough in REQUIREMENTS.md when testing resumes.

## Notes, targets, pairs, undo and plates

1. Open Routines → your routine → an exercise. Set its optional rep range and superset partner, then Save. Start a new workout to use these changes.
2. Choose each paired exercise from the lineup and complete its set. Complete both exercises in a round before rest begins. The app does not force your next exercise; pairing labels and individual set buttons remain available.
3. Add workout notes above the set cards, or exercise notes through its options menu. Record optional Reps left after checking a set. In History, Edit sets exposes the same notes/effort controls.
4. Undo appears at the top after a completion, swap or deletion. It is the most recent undoable action only, lasts during this app run, and does not replace backups.
5. History search accepts names and notes. Filters combine routine name, exercise and dates; Through includes the whole selected day.
6. Settings → Workout tools → Plate calculator: select units, actual bar weight, target including bar and available plate pairs. Results never exceed the target; any shortfall is shown. Exercise options also offer it for barbells.

### Enable background rest alerts

Use the persistent **Lift Log** or **Lift Log Local Only** scheme. Settings → Rest & consistency → Background rest alerts asks for notification permission. Allow it on your iPhone. No push entitlement, paid developer membership, server or Background Modes capability is needed for these local alerts. Demo intentionally leaves real notification scheduling alone.

If permission is denied or later changed, logging and the countdown keep working. Change notification access in iPhone Settings → Notifications → Gym Log. Focus or notification settings can silence alerts. Verify a real locked-phone alert and cancellation after pause/skip/finish; these delivery checks remain pending.

## Backup and recording recovery

Finish/discard an owned Watch workout and wait for confirmation before importing or resetting local data. Imported Watch details are snapshots and cannot control a live recording. Undo of a discarded workout restores its sets but cannot restart the discarded Watch recording. Deleting a finished Gym Log entry leaves its Apple Health workout intact.

## Easier exercise selection and set entry (October 7)

- Add exercises: use the top search field, switch All exercises / Saved, and open Filters when needed. Tap Select on rows, use Review to remove pending choices, then Add. The same search stays open until Done.
- Filters: change options and tap Show exercises to apply together. Cancel keeps the previous filters.
- Workout: enter Weight and Reps in the larger fields, then tap Complete. Undo reverses completion; the More menu offers confirmed removal. Keyboard controls move between weight and reps.
- Optional effort: after completing a set, expand Add effort · optional to record how many reps you had left. Leaving it Not set does not mean the workout entry failed to save.

## Studio design (October 11)

1. Run the usual **Lift Log** scheme. Studio applies automatically, including to existing data. Settings → Appearance changes Design (Studio / Velocity) and Appearance (System / Light / Dark).
2. Train → pick a routine → Start workout. The full lineup opens. Tap any exercise, enter its weight/reps and Complete. Use All exercises or Choose another exercise to return; completion keeps you on the chosen exercise.
3. Reorder opens drag handles and an arrow menu with Move up/down. This changes only this session. Workout options (ellipsis beside its title) → Save lineup to routine asks before applying the lineup to future sessions.
4. Add exercises on the lineup adds to this workout; Routines → your routine → Browse exercise library adds to that routine. Adding stays in search. Use Done when finished selecting.
5. Workout options also contains workout notes. Exercise options retains notes, form guide, plate calculator and swap. Progress, History editing/filtering, backups, rest settings and Health/Watch controls remain in their existing tabs.
6. During an active workout, Plan lets you browse other routines; Resume workout returns to the active lineup. Theme changes and backgrounding keep navigation state. A fresh process opens Train while loading your persisted unfinished workout.

Use the [Studio acceptance checklist](docs/STUDIO_IMPLEMENTATION.md) for device testing. Simulator visual/touch checks and physical Watch/Health verification are not implied by a successful build.
