import Foundation
#if SWIFT_PACKAGE
import XCTest
@testable import LiftLogCore
#endif

final class WorkoutLogicTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)
    private func backup() -> Backup {
        let plan = SeedData.samplePlan()
        return Backup(exportedAt: now, exercises: plan.exercises, days: plan.days,
                      sessions: SeedData.sampleSessions(exercises: plan.exercises, days: plan.days, now: now), preferences: Preferences())
    }
    func testSeedPlanAndSharedHistoryIdentity() {
        let plan = SeedData.samplePlan()
        XCTAssertEqual(plan.days.map { $0.exerciseIDs.count }, [6, 7, 6, 6, 6])
        XCTAssertEqual(plan.exercises.count, 157)
        let incline = plan.exercises.first { $0.name == "Incline DB press" }!
        XCTAssertTrue(plan.days[0].exerciseIDs.contains(incline.id))
        XCTAssertTrue(plan.days[3].exerciseIDs.contains(incline.id))
        XCTAssertTrue(plan.exercises.first { $0.name == "Pull-ups" }!.isBodyweight)
    }
    func testRoundTripIncludesPlanSettingsHealthAndDraft() throws {
        var value = backup()
        value.preferences = Preferences(unit: .kg, defaultSets: 4)
        value.sessions.append(SessionRecord(dayType: .push, start: now, logs: [ExerciseLog(exercise: value.exercises[0], sets: [LoggedSet(weightKg: 18.1436948, reps: 11, completed: true), LoggedSet()])]))
        let restored = try Backup.decode(value.encoded())
        XCTAssertEqual(value, restored)
        XCTAssertEqual(restored.sessions.filter { $0.end == nil }.count, 1)
        XCTAssertFalse(restored.sessions[0].health!.heartRate.isEmpty)
    }
    func testQuickFillUsesLastCompletedSessionAcrossDays() {
        let exercise = ExerciseRecord(name: "Incline DB press", muscle: "Chest")
        let old = SessionRecord(dayType: .push, start: now.addingTimeInterval(-200), end: now.addingTimeInterval(-100), logs: [ExerciseLog(exercise: exercise, sets: [LoggedSet(weightKg: 20, reps: 10, completed: true), LoggedSet(weightKg: 20, reps: 9, completed: true), LoggedSet(weightKg: 99, reps: 5, completed: false)])])
        let draft = SessionRecord(dayType: .upper, start: now.addingTimeInterval(-50), logs: [ExerciseLog(exercise: exercise, sets: [LoggedSet(weightKg: 100, reps: 1, completed: true)])])
        let filled = WorkoutLogic.quickFill(exercise: exercise, sessions: [draft, old], count: 3, before: now)
        XCTAssertEqual(filled.sets.map(\.weightKg), [20,20,20])
        XCTAssertEqual(filled.sets.map(\.reps), [10,9,9])
        XCTAssertFalse(filled.sets.contains(where: \.completed))
        XCTAssertNotEqual(filled.sets[0].id, old.logs[0].sets[0].id)
    }
    func testUnitConversionAndEpleyVolume() {
        let kilograms = WeightUnit.lb.kilograms(40)
        XCTAssertEqual(WeightUnit.lb.display(kilograms), 40, accuracy: 0.0000001)
        let set = LoggedSet(weightKg: kilograms, reps: 10, completed: true)
        XCTAssertEqual(WeightUnit.lb.display(set.volume), 400, accuracy: 0.000001)
        XCTAssertEqual(WeightUnit.lb.display(set.estimatedMax), 53.3333333, accuracy: 0.00001)
        XCTAssertEqual(LoggedSet(weightKg: 20, reps: 10).volume, 0)
    }
    func testBodyweightUsesRepsAndPRRequiresPreviousBaseline() {
        let exercise = ExerciseRecord(name: "Pull-ups", muscle: "Lats", isBodyweight: true)
        let old = SessionRecord(dayType: .pull, start: now.addingTimeInterval(-100), end: now.addingTimeInterval(-90), logs: [ExerciseLog(exercise: exercise, sets: [LoggedSet(reps: 8, completed: true)])])
        let new = SessionRecord(dayType: .upper, start: now, end: now.addingTimeInterval(60), logs: [ExerciseLog(exercise: exercise, sets: [LoggedSet(reps: 10, completed: true)])])
        XCTAssertEqual(new.logs[0].score, 10)
        XCTAssertTrue(WorkoutLogic.records(in: old, history: [old]).isEmpty)
        XCTAssertEqual(WorkoutLogic.records(in: new, history: [new, old]).count, 1)
        var skipped = old
        skipped.logs[0].sets[0].completed = false
        XCTAssertTrue(WorkoutLogic.records(in: new, history: [skipped]).isEmpty)
        XCTAssertEqual(new.volume, 0)
    }
    func testWeeklyVolumeIncludesOnlyFinishedAndEightBuckets() {
        let exercise = ExerciseRecord(name: "Row", muscle: "Back")
        let session = SessionRecord(dayType: .pull, start: now, end: now.addingTimeInterval(1), logs: [ExerciseLog(exercise: exercise, sets: [LoggedSet(weightKg: 20, reps: 10, completed: true)])])
        var draft = session; draft.id = UUID(); draft.end = nil
        let weeks = WorkoutLogic.weeklyVolumes([session, draft], now: now)
        XCTAssertEqual(weeks.count, 8)
        XCTAssertEqual(weeks.last?.value, 200)
        XCTAssertEqual(weeks.dropLast().reduce(0) { $0 + $1.value }, 0)
    }
    func testRestDaysAndOverlapBoundaries() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let sunday = cal.date(from: DateComponents(year: 2026, month: 10, day: 4))!
        XCTAssertNil(DayType.today(sunday, calendar: cal))
        XCTAssertEqual(DayType.today(sunday.addingTimeInterval(86400), calendar: cal), .push)
        XCTAssertEqual(WorkoutLogic.overlap(start: now, end: now.addingTimeInterval(60), otherStart: now.addingTimeInterval(30), otherEnd: now.addingTimeInterval(90)), 30)
        XCTAssertEqual(WorkoutLogic.overlap(start: now, end: now.addingTimeInterval(60), otherStart: now.addingTimeInterval(60), otherEnd: now.addingTimeInterval(90)), 0)
    }
    func testRejectUnsupportedAndMalformedBackups() throws {
        var value = backup(); value.version = 3
        XCTAssertThrowsError(try value.validated())
        value = backup(); value.exercises.append(value.exercises[0])
        XCTAssertThrowsError(try value.validated())
        value = backup(); value.days[0].exerciseIDs.append(UUID())
        XCTAssertThrowsError(try value.validated())
        value = backup(); value.sessions[0].logs[0].sets[0].weightKg = -1
        XCTAssertThrowsError(try value.validated())
        value = backup(); value.sessions[0].end = value.sessions[0].start.addingTimeInterval(-1)
        XCTAssertThrowsError(try value.validated())
        value = backup(); value.sessions[0].logs[0].sets[0].reps = 0
        XCTAssertThrowsError(try value.validated())
        value = backup(); value.sessions[0].health?.calories = 1e300
        XCTAssertThrowsError(try value.validated())
        value = backup(); value.sessions[0].end = nil; value.sessions[1].end = nil
        XCTAssertThrowsError(try value.validated())
        XCTAssertThrowsError(try Backup.decode(Data("not JSON".utf8)))
    }
    func testEmptyHistoryAndEmptyPlanDayAreValid() throws {
        var value = backup(); value.sessions = []; value.days[0].exerciseIDs = []
        XCTAssertNoThrow(try value.validated())
        XCTAssertEqual(WorkoutLogic.quickFill(exercise: value.exercises[0], sessions: [], count: 3).sets.count, 3)
        XCTAssertTrue(WorkoutLogic.weeklyVolumes([], now: now).allSatisfy { $0.value == 0 })
    }
    func testFreshInstallHasNoStaticExercisesOrRoutines() throws {
        let plan = SeedData.plan()
        XCTAssertTrue(plan.days.isEmpty)
        XCTAssertTrue(plan.exercises.isEmpty)
        XCTAssertNoThrow(try Backup(exercises: plan.exercises, days: [], sessions: [], preferences: Preferences()).validated())
    }
    func testSearchAliasesAndCombinedFilters() {
        let catalog = ExerciseLibrary.catalog
        let aliases = ExerciseLibrary.filtered(catalog, search: "incline dumbbell bench", muscle: .chest, equipment: .dumbbell)
        XCTAssertEqual(aliases.map(\.name), ["Incline DB press"])
        XCTAssertFalse(ExerciseLibrary.filtered(catalog, search: "RDL", muscle: .hamstrings, equipment: .dumbbell).isEmpty)
        XCTAssertTrue(ExerciseLibrary.filtered(catalog, search: "bench", muscle: .calves, equipment: .barbell).isEmpty)
        XCTAssertEqual(ExerciseLibrary.filtered(catalog, search: "  PÚLL-UP  ", muscle: .back, equipment: .bodyweight).count, 2)
        let custom = ExerciseRecord(name: "My row variation", muscle: "Back", equipment: .band)
        XCTAssertEqual(ExerciseLibrary.filtered(catalog + [custom], search: "my row", muscle: .back, equipment: .band).map(\.id), [custom.id])
    }
    func testLibraryUpgradePreservesIdentityAndCustomEdits() {
        let existing = ExerciseRecord(name: "Incline DB press", muscle: "My chest label")
        let custom = ExerciseRecord(name: "My unique movement", muscle: "Core", equipment: .other)
        let upgraded = ExerciseLibrary.mergingCatalog(into: [existing, custom])
        let match = upgraded.first { $0.id == existing.id }!
        XCTAssertEqual(match.muscle, "My chest label")
        XCTAssertEqual(match.equipment, .dumbbell)
        XCTAssertEqual(upgraded.filter { $0.name == existing.name }.count, 1)
        XCTAssertTrue(upgraded.contains(custom))
        XCTAssertEqual(ExerciseLibrary.mergingCatalog(into: upgraded), upgraded)
    }
    func testCustomScheduleAndOrderedSelection() throws {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let sunday = cal.date(from: DateComponents(year: 2026, month: 10, day: 4))!
        var day = DayRecord(type: .upper, exerciseIDs: [], name: "Full body A", weekdays: [1, 4, 6])
        XCTAssertTrue(day.isScheduled(on: sunday, calendar: cal))
        XCTAssertFalse(day.isScheduled(on: sunday.addingTimeInterval(86400), calendar: cal))
        let a = UUID(), b = UUID()
        day = ExerciseLibrary.adding([a, b, a], to: day)
        XCTAssertEqual(day.exerciseIDs, [a, b])
        XCTAssertEqual(ExerciseLibrary.adding([b], to: day), day)
        day.weekdays = []
        XCTAssertEqual(day.scheduleDescription, "Any day")
        XCTAssertFalse(day.isScheduled(on: sunday, calendar: cal))
        let legacy = DayRecord(type: .push, exerciseIDs: [])
        XCTAssertEqual(legacy.scheduledWeekdays, [2])
        XCTAssertEqual(legacy.title, "Push")
    }
    func testLegacyBackupAndCustomRoutineRoundTrip() throws {
        var value = backup()
        value.version = 1
        let encoded = try value.encoded()
        var json = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        json["version"] = 1
        var exercises = json["exercises"] as! [[String: Any]]
        for index in exercises.indices {
            exercises[index].removeValue(forKey: "equipment")
            exercises[index].removeValue(forKey: "aliases")
            exercises[index].removeValue(forKey: "catalogKey")
        }
        json["exercises"] = exercises
        let restored = try Backup.decode(JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(restored.version, 2)
        XCTAssertEqual(restored.days, value.days)
        XCTAssertEqual(restored.sessions, value.sessions)
        XCTAssertEqual(restored.exercises.map(\.id), value.exercises.map(\.id))
        var modern = backup()
        modern.days = [DayRecord(type: .pull, exerciseIDs: [modern.exercises[0].id], name: "Custom A", weekdays: [1,3,5])]
        modern.sessions[0].routineName = "Original session name"
        modern.sessions[0].routineID = modern.days[0].id
        modern.days[0].name = "Renamed routine"
        let roundTrip = try Backup.decode(modern.encoded())
        XCTAssertEqual(roundTrip, modern)
        XCTAssertEqual(roundTrip.sessions[0].title, "Original session name")
        modern.days[0].weekdays = [9]
        XCTAssertThrowsError(try modern.validated())
    }

    func testRestTimerSurvivesElapsedTimePauseAndRoundTrip() throws {
        var timer = RestTimerState(setID: UUID(), exerciseName: "Squat", seconds: 90, now: now)
        XCTAssertEqual(timer.remaining(at: now.addingTimeInterval(25)), 65)
        timer.togglePause(at: now.addingTimeInterval(25))
        XCTAssertEqual(timer.remaining(at: now.addingTimeInterval(600)), 65)
        timer.extend(at: now.addingTimeInterval(600))
        timer.togglePause(at: now.addingTimeInterval(600))
        XCTAssertEqual(timer.remaining(at: now.addingTimeInterval(630)), 65)
        let restored = try JSONDecoder().decode(RestTimerState.self, from: JSONEncoder().encode(timer))
        XCTAssertEqual(restored.remaining(at: now.addingTimeInterval(900)), 0)
        timer.extend(at: now.addingTimeInterval(900))
        XCTAssertEqual(timer.remaining(at: now.addingTimeInterval(900)), 30)
    }
    func testDuplicateAndSwapPreserveRoutineAndCompletedWork() throws {
        let a = ExerciseRecord(name: "Press", muscle: "Chest")
        let b = ExerciseRecord(name: "Fly", muscle: "Chest")
        let c = ExerciseRecord(name: "Squat", muscle: "Quads")
        let day = DayRecord(type: .push, exerciseIDs: [a.id, c.id], name: "Morning", weekdays: [2,5])
        let copy = WorkoutLogic.duplicate(day)
        XCTAssertNotEqual(copy.id, day.id)
        XCTAssertEqual(copy.exerciseIDs, day.exerciseIDs)
        XCTAssertEqual(copy.scheduledWeekdays, [2,5])
        XCTAssertEqual(copy.title, "Morning (copy)")
        let previous = SessionRecord(dayType: .upper, start: now.addingTimeInterval(-500), end: now.addingTimeInterval(-100), logs: [ExerciseLog(exercise: b, sets: [LoggedSet(weightKg: 12, reps: 8, completed: true)])])
        let session = SessionRecord(dayType: .push, start: now, logs: [ExerciseLog(exercise: a, sets: [LoggedSet(weightKg: 90, reps: 12)]), ExerciseLog(exercise: c, sets: [LoggedSet(weightKg: 50, reps: 6, completed: true)])])
        let swapped = try WorkoutLogic.swapping(a.id, with: b, in: session, history: [previous])
        XCTAssertEqual(swapped.logs[0].id, b.id)
        XCTAssertEqual(swapped.logs[0].sets[0].weightKg, 12)
        XCTAssertEqual(swapped.logs[0].sets[0].reps, 8)
        XCTAssertFalse(swapped.logs[0].sets[0].completed)
        XCTAssertEqual(swapped.logs[1], session.logs[1])
        XCTAssertEqual(day.exerciseIDs, [a.id, c.id])
        XCTAssertThrowsError(try WorkoutLogic.swapping(c.id, with: b, in: session, history: []))
        XCTAssertThrowsError(try WorkoutLogic.swapping(a.id, with: c, in: session, history: []))
        var finished = session; finished.end = now.addingTimeInterval(60)
        XCTAssertThrowsError(try WorkoutLogic.swapping(a.id, with: b, in: finished, history: []))
    }
    func testWeeklyGoalBoundariesAndUnfinishedWeek() {
        let monday = WorkoutLogic.calendar.dateInterval(of: .weekOfYear, for: now)!.start
        let exercise = ExerciseRecord(name: "Curl", muscle: "Biceps")
        func workout(_ weeksAgo: Int) -> SessionRecord {
            let start = WorkoutLogic.calendar.date(byAdding: .weekOfYear, value: -weeksAgo, to: monday)!
            return SessionRecord(dayType: .pull, start: start, end: start.addingTimeInterval(60), logs: [ExerciseLog(exercise: exercise, sets: [LoggedSet(reps: 10, completed: true)])])
        }
        let history = [workout(1), workout(1), workout(2), workout(2), workout(4), workout(4)]
        XCTAssertEqual(WorkoutLogic.goalStreak(history, goal: 2, now: now), 2)
        XCTAssertEqual(WorkoutLogic.goalStreak(history + [workout(0), workout(0)], goal: 2, now: now), 3)
        XCTAssertEqual(WorkoutLogic.goalStreak([workout(2), workout(2)], goal: 2, now: now), 0)
        var draft = workout(0); draft.end = nil
        var empty = workout(0); empty.logs[0].sets[0].completed = false
        XCTAssertEqual(WorkoutLogic.weeklyCounts(history + [draft, empty], now: now).last?.value, 0)
        XCTAssertEqual(WorkoutLogic.weeklyCounts(history, now: now).count, 8)
    }
    func testPerformanceMetricsExcludeDraftsAndUncheckedSets() {
        let exercise = ExerciseRecord(name: "Curl", muscle: "Biceps")
        let session = SessionRecord(dayType: .pull, start: now, end: now.addingTimeInterval(60), logs: [ExerciseLog(exercise: exercise, sets: [LoggedSet(weightKg: 20, reps: 8, completed: true), LoggedSet(weightKg: 15, reps: 12, completed: true), LoggedSet(weightKg: 99, reps: 99)])])
        var draft = session; draft.id = UUID(); draft.end = nil
        let values = WorkoutLogic.performances(for: exercise.id, in: [draft, session])
        XCTAssertEqual(values.count, 1)
        XCTAssertEqual(values[0].maxWeight, 20)
        XCTAssertEqual(values[0].bestReps, 12)
        XCTAssertEqual(values[0].sets.count, 2)
        XCTAssertEqual(values[0].score, 20 * (1 + 8.0 / 30), accuracy: 0.0001)
    }
    func testEmptyAndFailedHealthRefreshKeepSavedSummary() {
        var session = backup().sessions[0]
        let health = session.health!
        session = WorkoutLogic.receivingHealth(health, in: session, now: now)
        XCTAssertEqual(session.healthCheck?.outcome, .matched)
        let missing = WorkoutLogic.receivingHealth(nil, in: session, now: now.addingTimeInterval(60))
        XCTAssertEqual(missing.health, health)
        XCTAssertEqual(missing.healthCheck?.outcome, .noMatch)
        XCTAssertEqual(missing.healthCheck?.lastMatchedAt, now)
        let failed = WorkoutLogic.receivingHealth(nil, in: missing, now: now.addingTimeInterval(120), failed: true)
        XCTAssertEqual(failed.health, health)
        XCTAssertEqual(failed.healthCheck?.outcome, .failed)
        XCTAssertEqual(failed.healthCheck?.lastMatchedAt, now)
    }
    func testEnhancedBackupCompatibilityAndRoutineOrder() throws {
        var value = backup()
        value.preferences = Preferences(unit: .kg, defaultSets: 4, restSeconds: 120, automaticRest: false, weeklyGoal: 4, routineOrder: value.days.reversed().map(\.id))
        let completed = LoggedSet(weightKg: 12, reps: 10, completed: true)
        let draft = SessionRecord(dayType: .pull, start: now, logs: [ExerciseLog(exercise: value.exercises[0], sets: [completed, LoggedSet()])], restTimer: RestTimerState(setID: completed.id, exerciseName: "Test", seconds: 90, now: now))
        value.sessions.append(draft)
        let roundTrip = try Backup.decode(value.encoded())
        XCTAssertEqual(roundTrip.days.map(\.id), value.preferences.routineOrder)
        XCTAssertEqual(roundTrip.sessions.last?.restTimer, draft.restTimer)
        XCTAssertEqual(roundTrip.preferences.resolvedRestSeconds, 120)
        var json = try JSONSerialization.jsonObject(with: value.encoded()) as! [String: Any]
        json["preferences"] = ["unit": "lb", "defaultSets": 3]
        let old = try Backup.decode(JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(old.preferences.resolvedRestSeconds, 90)
        XCTAssertEqual(old.preferences.resolvedWeeklyGoal, 3)
        XCTAssertTrue(old.preferences.resolvedAutomaticRest)
        value.preferences.weeklyGoal = 0
        XCTAssertThrowsError(try value.validated())
        value.preferences.weeklyGoal = 3; value.preferences.restSeconds = 0
        XCTAssertThrowsError(try value.validated())
        value.preferences.restSeconds = 90; value.sessions[value.sessions.count - 1].restTimer?.setID = UUID()
        XCTAssertThrowsError(try value.validated())
    }
    func testSampleGuidesOnlyAttachToMatchingCatalogExercises() {
        let samples = ExerciseLibrary.catalog.filter { ExerciseGuide.guide(for: $0) != nil }
        XCTAssertEqual(Set(samples.map(\.name)), Set(["Goblet squat", "Dumbbell curl"]))
        var renamed = samples[0]; renamed.name = "My custom variation"
        XCTAssertNil(ExerciseGuide.guide(for: renamed))
        XCTAssertNil(ExerciseGuide.guide(for: ExerciseRecord(name: "Goblet squat", muscle: "Quads")))
    }

    func testSupersetAlternatesAndRestsOnlyAfterPair() throws {
        let a = ExerciseRecord(name: "A", muscle: "Chest"), b = ExerciseRecord(name: "B", muscle: "Back")
        var session = SessionRecord(dayType: .upper, start: now, logs: [ExerciseLog(exercise: a, sets: [LoggedSet(), LoggedSet()]), ExerciseLog(exercise: b, sets: [LoggedSet(), LoggedSet()])], supersets: [SupersetPair(first: a.id, second: b.id)])
        XCTAssertEqual(WorkoutLogic.setOrder(in: session).map(\.exerciseID), [a.id, b.id, a.id, b.id])
        var first = session.logs[0].sets[0]; first.completed = true
        session = WorkoutLogic.changingSet(first, exerciseID: a.id, in: session, preferences: Preferences(), now: now)
        XCTAssertNil(session.restTimer)
        XCTAssertEqual(WorkoutLogic.nextSet(in: session)?.exerciseID, b.id)
        var second = session.logs[1].sets[0]; second.completed = true
        session = WorkoutLogic.changingSet(second, exerciseID: b.id, in: session, preferences: Preferences(), now: now)
        XCTAssertEqual(session.restTimer?.remaining(at: now), 90)
        var unchecked = first; unchecked.completed = false
        let corrected = WorkoutLogic.changingSet(unchecked, exerciseID: a.id, in: session, preferences: Preferences(), now: now)
        XCTAssertNil(corrected.restTimer) // An incomplete pair must no longer schedule rest.
        XCTAssertEqual(WorkoutLogic.nextSet(in: session)?.exerciseID, a.id)
        first = session.logs[0].sets[1]; first.completed = true
        session = WorkoutLogic.changingSet(first, exerciseID: a.id, in: session, preferences: Preferences(), now: now)
        XCTAssertNil(session.restTimer)
        second = session.logs[1].sets[1]; second.completed = true
        session = WorkoutLogic.changingSet(second, exerciseID: b.id, in: session, preferences: Preferences(), now: now)
        XCTAssertNil(WorkoutLogic.nextSet(in: session))
        XCTAssertNil(session.restTimer)
    }
    func testSupersetUnevenSetsAndSwapMembership() throws {
        let a = ExerciseRecord(name: "A", muscle: "Chest"), b = ExerciseRecord(name: "B", muscle: "Back"), c = ExerciseRecord(name: "C", muscle: "Back")
        var session = SessionRecord(dayType: .upper, start: now, logs: [ExerciseLog(exercise: a, sets: [LoggedSet(), LoggedSet(), LoggedSet()]), ExerciseLog(exercise: b, sets: [LoggedSet()])], supersets: [SupersetPair(first: a.id, second: b.id)])
        XCTAssertEqual(WorkoutLogic.setOrder(in: session).map(\.exerciseID), [a.id,b.id,a.id,a.id])
        let swapped = try WorkoutLogic.swapping(b.id, with: c, in: session, history: [])
        XCTAssertEqual(swapped.supersets?.first?.second, c.id)
        XCTAssertEqual(WorkoutLogic.setOrder(in: swapped).map(\.exerciseID), [a.id,c.id,a.id,a.id])
        session.logs[0].sets[0].completed = true; session.logs[1].sets[0].completed = true
        var set = session.logs[0].sets[1]; set.completed = true
        session = WorkoutLogic.changingSet(set, exerciseID: a.id, in: session, preferences: Preferences(), now: now)
        XCTAssertEqual(session.restTimer?.setID, set.id)
    }
    func testUndoSetKeepsUnrelatedNotesAndNewerTimer() throws {
        let exercise = ExerciseRecord(name: "Curl", muscle: "Biceps")
        let before = LoggedSet(weightKg: 10, reps: 8)
        var session = SessionRecord(dayType: .pull, start: now, logs: [ExerciseLog(exercise: exercise, sets: [before, LoggedSet(), LoggedSet()])])
        var after = before; after.completed = true
        session = WorkoutLogic.changingSet(after, exerciseID: exercise.id, in: session, preferences: Preferences(), now: now)
        let undo = WorkoutUndo(title: "Set completed", change: .set(sessionID: session.id, exerciseID: exercise.id, before: before, after: after, oldRest: nil, newRest: session.restTimer))
        var next = session.logs[0].sets[1]; next.completed = true
        session = WorkoutLogic.changingSet(next, exerciseID: exercise.id, in: session, preferences: Preferences(), now: now.addingTimeInterval(60))
        session.notes = "Keep this newer note"
        let data = Backup(exercises: [exercise], days: [], sessions: [session], preferences: Preferences())
        let restored = try undo.restoring(in: data)
        XCTAssertEqual(restored.sessions[0].notes, session.notes)
        XCTAssertEqual(restored.sessions[0].restTimer, session.restTimer)
        XCTAssertFalse(restored.sessions[0].logs[0].sets[0].completed)
        XCTAssertTrue(restored.sessions[0].logs[0].sets[1].completed)
        var conflict = data; conflict.sessions[0].logs[0].sets[0].reps = 12
        XCTAssertThrowsError(try undo.restoring(in: conflict))
    }
    func testUndoSwapPreservesOtherExerciseAndRestoresPair() throws {
        let a = ExerciseRecord(name: "A", muscle: "Chest"), b = ExerciseRecord(name: "B", muscle: "Back"), c = ExerciseRecord(name: "C", muscle: "Chest")
        let original = SessionRecord(dayType: .upper, start: now, logs: [ExerciseLog(exercise: a, sets: [LoggedSet()], target: RepRange(lower: 8, upper: 12), notes: "Seat 3"), ExerciseLog(exercise: b, sets: [LoggedSet()])], supersets: [SupersetPair(first: a.id, second: b.id)])
        var swapped = try WorkoutLogic.swapping(a.id, with: c, in: original, history: [])
        let undo = WorkoutUndo(title: "Swapped", change: .swap(sessionID: original.id, before: original.logs[0], after: swapped.logs[0], oldPairs: original.supersets, newPairs: swapped.supersets))
        swapped.logs[1].notes = "New note"
        let data = Backup(exercises: [a,b,c], days: [], sessions: [swapped], preferences: Preferences())
        let restored = try undo.restoring(in: data)
        XCTAssertEqual(restored.sessions[0].logs[0], original.logs[0])
        XCTAssertEqual(restored.sessions[0].supersets, original.supersets)
        XCTAssertEqual(restored.sessions[0].logs[1].notes, "New note")
        var conflict = data; conflict.sessions[0].logs[0].sets[0].completed = true
        XCTAssertThrowsError(try undo.restoring(in: conflict))
    }
    func testUndoDeletionRestoresHealthAndRejectsTwoDrafts() throws {
        let value = backup(); let deleted = value.sessions[0]
        let undo = WorkoutUndo(title: "Deleted", change: .deletion(deleted))
        var data = value; data.sessions.removeFirst()
        let restored = try undo.restoring(in: data)
        XCTAssertEqual(restored.sessions.last, deleted)
        XCTAssertThrowsError(try undo.restoring(in: restored))
        var draft = deleted; draft.end = nil; draft.health = nil
        let draftUndo = WorkoutUndo(title: "Discarded", change: .deletion(draft))
        var other = draft; other.id = UUID(); data.sessions.append(other)
        XCTAssertThrowsError(try draftUndo.restoring(in: data))
    }
    func testCombinedHistoryFiltersUseInclusiveStartExclusiveEnd() {
        var session = backup().sessions[0]; session.start = now; session.end = now.addingTimeInterval(60)
        session.routineName = "Upper A"; session.notes = "Shoulder felt good"; session.logs[0].notes = "Seat 3"
        let filter = HistoryFilter(search: "ÚPPER seat", routineTitle: "Upper A", exerciseID: session.logs[0].id, from: now, until: now.addingTimeInterval(86400))
        XCTAssertTrue(filter.matches(session))
        var wrong = filter; wrong.exerciseID = UUID(); XCTAssertFalse(wrong.matches(session))
        wrong = filter; wrong.routineTitle = "Lower"; XCTAssertFalse(wrong.matches(session))
        wrong = filter; wrong.until = now; XCTAssertFalse(wrong.matches(session))
        wrong = filter; wrong.from = now.addingTimeInterval(1); XCTAssertFalse(wrong.matches(session))
        session.end = nil; XCTAssertFalse(filter.matches(session))
    }
    func testPlateCalculatorHonorsInventoryAndNeverRoundsUp() throws {
        let pounds = try PlateCalculator.calculate(target: 225, bar: 45, stock: PlateCalculator.standard(.lb))
        XCTAssertEqual(pounds.perSide, [45,45]); XCTAssertEqual(pounds.total, 225)
        let exact = try PlateCalculator.calculate(target: 16, bar: 0, stock: [PlateStock(weight: 6, pairs: 1), PlateStock(weight: 4, pairs: 2)])
        XCTAssertEqual(exact.perSide, [4,4]) // Greedy would miss this exact result.
        let limited = try PlateCalculator.calculate(target: 100, bar: 20, stock: [PlateStock(weight: 25, pairs: 1), PlateStock(weight: 10, pairs: 1)])
        XCTAssertEqual(limited.total, 90); XCTAssertEqual(limited.shortfall, 10)
        XCTAssertEqual(try PlateCalculator.calculate(target: 20, bar: 20, stock: []).perSide, [])
        for target in stride(from: 20.0, through: 150, by: 1.3) {
            let result = try PlateCalculator.calculate(target: target, bar: 20, stock: [PlateStock(weight: 10, pairs: 2), PlateStock(weight: 2.5, pairs: 1)])
            XCTAssertTrue(result.total <= target + 0.00001)
            XCTAssertEqual(result.total, 20 + 2 * result.perSide.reduce(0,+), accuracy: 0.00001)
            XCTAssertTrue(result.perSide.filter { $0 == 10 }.count <= 2)
            XCTAssertTrue(result.perSide.filter { $0 == 2.5 }.count <= 1)
        }
        XCTAssertThrowsError(try PlateCalculator.calculate(target: 10, bar: 20, stock: []))
        XCTAssertThrowsError(try PlateCalculator.calculate(target: .infinity, bar: 20, stock: []))
        XCTAssertThrowsError(try PlateCalculator.calculate(target: 100, bar: 20, stock: [PlateStock(weight: 0, pairs: 2)]))
    }
    func testTrainingMetadataRoundTripAndValidation() throws {
        var value = backup()
        let a = value.days[0].exerciseIDs[0], b = value.days[0].exerciseIDs[1]
        value.days[0].targets = [RepTarget(exerciseID: a, range: RepRange(lower: 8, upper: 12))]
        value.days[0].supersets = [SupersetPair(first: a, second: b)]
        value.sessions[0].notes = "Great workout"
        value.sessions[0].logs[0].notes = "Seat 4"
        value.sessions[0].logs[0].target = RepRange(lower: 6, upper: 10)
        value.sessions[0].logs[0].sets[0].repsInReserve = 2
        value.preferences.restAlerts = true
        XCTAssertEqual(try Backup.decode(value.encoded()), value)
        let copy = WorkoutLogic.duplicate(value.days[0])
        XCTAssertEqual(copy.targets, value.days[0].targets); XCTAssertEqual(copy.supersets, value.days[0].supersets)
        var bad = value; bad.days[0].supersets?.append(SupersetPair(first: a, second: b))
        XCTAssertThrowsError(try bad.validated())
        bad = value; bad.days[0].targets?[0].range = RepRange(lower: 12, upper: 8)
        XCTAssertThrowsError(try bad.validated())
        bad = value; bad.sessions[0].logs[0].sets[0].repsInReserve = 11
        XCTAssertThrowsError(try bad.validated())
        bad = value; bad.sessions[0].notes = String(repeating: "x", count: 4001)
        XCTAssertThrowsError(try bad.validated())
        var json = try JSONSerialization.jsonObject(with: backup().encoded()) as! [String: Any]
        json["preferences"] = ["unit": "lb", "defaultSets": 3]
        let legacy = try Backup.decode(JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(legacy.preferences.restAlerts)
        XCTAssertNil(legacy.sessions[0].notes)
        XCTAssertNil(legacy.sessions[0].logs[0].sets[0].repsInReserve)
    }

}
