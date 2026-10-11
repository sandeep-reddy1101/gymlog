# Lift Log for iOS: Build Requirements

Paste this whole document to the AI that will build the app. Where something is unclear, make a reasonable choice, state it in one line, and keep going.

## 1. Goal

Build a personal, native iOS workout tracker called **Lift Log**. It replaces a web prototype I already use. It must:

1. Store my fixed 5-day dumbbell workout plan.
2. Let me log weight and reps for every set quickly, mid-workout, with one hand.
3. Show my progress with clear charts.
4. Read Apple Watch data (workouts, heart rate, calories) through HealthKit and show it next to my logged sets.

This is for **me only**, installed directly on my own iPhone from Xcode. It will **never** go to the App Store, so ignore App Store review, onboarding marketing, subscriptions, accounts, and analytics.

## 2. My setup and constraints

- Development Mac with Xcode (assume the latest stable release).
- My own iPhone and Apple Watch for testing. Health data does not exist in the simulator, so include mock or sample data so the UI is testable without a device.
- **Free Apple ID signing, not a paid developer account.** Do not use any capability that requires the paid program (iCloud/CloudKit, push notifications, App Groups that need a paid team, etc.). HealthKit is expected to work on a free account; if it does not, tell me clearly and offer a fallback.
- Builds from a free account expire after about 7 days, so I will reinstall regularly. **Local data must survive reinstalls as far as possible, and the app needs an export/import feature** (JSON file via the share sheet) as a backup.
- I use **pounds (lb)**. Add a lb/kg setting, default lb.
- Offline only. No backend, no login, no network calls.

## 3. Tech stack

- **Swift and SwiftUI**, targeting a recent iOS version (iOS 17 or later is fine, so SwiftData and Swift Charts are available).
- **SwiftData** for local persistence.
- **Swift Charts** for all charts.
- **HealthKit** for reading Apple Watch data.
- No third-party dependencies unless there is a strong reason; explain any you add.
- Phase 2 only: a watchOS companion target using `HKWorkoutSession` and WatchConnectivity.

## 4. The workout plan (seed data)

I have a **dumbbell-only gym** with a flat/incline bench, a pull-up bar and a bench press station. No cables or machines, so these are already substitutions. Preload this plan, and let me edit, add, remove and reorder exercises in the app.

**Monday: Push**
1. Incline DB press (chest)
2. Flat DB press (chest)
3. DB shoulder press (shoulders)
4. Lateral raises (side delts)
5. DB fly (chest)
6. Overhead DB extension (triceps)

**Tuesday: Pull**
1. Pull-ups (lats)
2. Chest-supported incline row (back)
3. DB row (lats)
4. Rear delt reverse fly (rear delts)
5. Seated incline curl (biceps)
6. Seated incline hammer curl (biceps)
7. DB shrug, optional (traps)

**Wednesday: Legs**
1. Goblet squat (quads)
2. DB Romanian deadlift (hamstrings)
3. Bulgarian split squat (quads, glutes)
4. Single-leg DB RDL (hamstrings)
5. DB step-ups (quads)
6. Single-leg calf raise (calves)

**Friday: Upper**
1. Incline DB press (chest)
2. Pull-ups (lats)
3. Bent-over row (back)
4. Lateral raises (side delts)
5. Seated incline curl (biceps)
6. Overhead DB extension (triceps)

**Saturday: Lower**
1. Goblet squat (quads)
2. DB hip thrust (glutes)
3. DB walking lunges (quads, glutes)
4. Single-leg DB RDL (hamstrings)
5. DB step-ups (quads)
6. Single-leg calf raise (calves)

Rest days: Thursday and Sunday. Exercises that appear on more than one day (for example Incline DB press, Pull-ups) should share one history, so progress carries across days.

## 5. Features

### Phase 1: iPhone app (build this first)

**Today screen**
- Opens on today's workout based on the weekday (Mon/Tue/Wed/Fri/Sat). On rest days, show a rest-day screen with a shortcut to pick any workout.
- A day picker across the top, with a distinct colour per day type (push, pull, legs, upper, lower).
- A **progress ring** showing sets completed out of total sets.
- Each exercise is a card showing the muscle group, the **previous session's sets** ("Last time: 40×10, 40×9…"), and rows of sets.
- Each set row has weight, reps and a done check. Defaults to 3 sets, with an "add set" button.
- **Quick-fill:** weight and reps are pre-filled from the last session. Tapping the check on an untouched set accepts those numbers.
- Large tap targets and numeric keypad, because I use it between sets with sweaty hands.
- A "Finish workout" button saves the session. Support resuming an unfinished workout if the app is closed mid-session.
- Bodyweight exercises (pull-ups) allow weight 0 and optional added weight.

**Progress screen**
- Stats: total workouts, workouts this week, total volume lifted.
- A 4-week calendar heat map of workout days, coloured by day type.
- A weekly volume bar chart for the last 8 weeks.
- Per-exercise line chart over time, using estimated 1-rep max (Epley: weight × (1 + reps/30)), or best reps for bodyweight exercises. Include an exercise picker.
- Personal-record badges when I beat a previous best.

**History**
- A list of past workouts, each opening to its full set detail. Allow editing and deleting a session.

**HealthKit integration (read-only)**
- Request read access for: workouts, heart rate, active energy burned, resting heart rate, and heart rate variability.
- After a workout, match the Apple Watch workout (strength training type) that overlaps the logged session time, and attach: duration, average and max heart rate, and calories. Show a small heart rate chart for that session.
- Show resting heart rate and HRV trends on the Progress screen if available.
- Handle every case where permission is denied or data is missing, with a clear empty state instead of a crash.
- Include correct `Info.plist` usage descriptions and the HealthKit entitlement, and tell me exactly which Xcode steps enable it.

**Settings**
- lb/kg toggle, default set count, export/import JSON backup, and a reset option behind a confirmation.

### Phase 2: Apple Watch companion (only after Phase 1 works)

- A watchOS app showing today's exercises with a simple log screen for weight and reps.
- Starts an `HKWorkoutSession` for live heart rate while lifting.
- Syncs completed sets back to the iPhone via WatchConnectivity.
- Optional rest timer with haptics.

### Out of scope

App Store submission, accounts, cloud sync, social features, AI-generated plans, nutrition tracking, subscriptions, ads.

## 6. Data model (suggested)

- **Exercise**: id, name, muscle group, isBodyweight.
- **WorkoutDay**: id, weekday, name (Push/Pull/…), colour, ordered list of Exercises.
- **WorkoutSession**: id, date, dayType, start/end time, optional HealthKit summary (avg HR, max HR, calories, duration).
- **SetEntry**: id, session, exercise, order, weight, reps, completed.
- Derived values (volume, estimated 1RM, PRs) are computed, not stored.

## 7. Design direction

- Clean, bold and fast to scan. Large numbers, generous spacing, supports light and dark mode and Dynamic Type.
- Colour per day type: push coral (#FF4D6D), pull blue (#3B82F6), legs green (#22C55E), upper purple (#A855F7), lower amber (#F59E0B).
- The progress ring and calendar heat map are the signature visuals; keep everything else calm.
- Light haptic on completing a set, and a stronger one on finishing a workout.

## 8. Acceptance criteria

1. App builds and runs from Xcode on my iPhone with a free Apple ID.
2. I can complete a full Monday push workout in under a minute of tapping beyond the lifting itself.
3. Closing and reopening the app keeps my data and any in-progress workout.
4. Export then import restores all history.
5. With the Apple Watch worn during a workout, the session shows matched heart rate and calories.
6. Denying HealthKit permission leaves the rest of the app fully working.
7. No crashes on empty data (first launch, no history, no Health data).

## 9. How I want you to work

1. Start with a short plan and the project/file structure.
2. Build **Phase 1 in small steps** (data model, Today screen, saving, Progress charts, History, HealthKit, Settings/export), giving complete compilable files at each step.
3. After each step, tell me exactly what to do in Xcode (targets, capabilities, signing, plist keys) and what I should see when it works.
4. Include sample/mock data and SwiftUI previews so I can see screens without a watch.
5. Flag anything that behaves differently on a free Apple ID.
6. Keep explanations short and practical. I'm a developer, but new to Swift/iOS.
7. Do not start Phase 2 until I confirm Phase 1 works on my phone.

## 10. Reference

A working web prototype exists with the same plan, set logging, quick-fill, progress ring, heat map, weekly volume chart and per-exercise trend chart. Match its behaviour and layout where it makes sense, adapting to native iOS patterns.