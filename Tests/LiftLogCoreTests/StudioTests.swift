import XCTest
@testable import LiftLogCore

final class StudioTests: XCTestCase {
    private func fixture() -> Backup {
        let a = ExerciseRecord(name: "Row", muscle: "Back")
        let b = ExerciseRecord(name: "Press", muscle: "Chest")
        let day = DayRecord(type: .upper, exerciseIDs: [a.id, b.id], name: "My training", weekdays: [2, 4])
        var session = SessionRecord(dayType: .upper, start: Date(timeIntervalSince1970: 1790000000), logs: [
            ExerciseLog(exercise: a, sets: [LoggedSet(weightKg: 12.345, reps: 8, completed: true, repsInReserve: 2), LoggedSet(weightKg: 18, reps: 9)], target: RepRange(lower: 8, upper: 12), notes: "Keep this note"),
            ExerciseLog(exercise: b, sets: [LoggedSet(weightKg: 20, reps: 10)])
        ], routineID: day.id, routineName: day.title, notes: "Session note", supersets: [SupersetPair(first: a.id, second: b.id)])
        session.restTimer = RestTimerState(setID: session.logs[0].sets[0].id, exerciseName: a.name, seconds: 90, now: session.start)
        session.watchTracking = WatchTracking(requestedAt: session.start)
        return Backup(exportedAt: Date(timeIntervalSince1970: 1790000000), exercises: [a, b], days: [day], sessions: [session], preferences: Preferences())
    }
    func testDraftFollowsSetIdentityAndRejectsChangedDataOrUnits() {
        let set = LoggedSet(weightKg: 12.345, reps: 8)
        let draft = SetEntryDraft(weight: "12.", reps: "", baseline: set, unit: .kg, isValid: false)
        XCTAssertTrue(draft.applies(to: set, unit: .kg))
        XCTAssertFalse(draft.applies(to: set, unit: .lb))
        var completed = set; completed.completed = true
        XCTAssertFalse(draft.applies(to: completed, unit: .kg))
        var edited = set; edited.reps = 9
        XCTAssertFalse(draft.applies(to: edited, unit: .kg))
        var different = set; different.id = UUID()
        XCTAssertFalse(draft.applies(to: different, unit: .kg))
    }
    func testLegacyAndUnknownThemePreferencesFallBackWithoutLosingSettings() throws {
        let legacy = try JSONDecoder().decode(Preferences.self, from: Data(#"{"unit":"kg","defaultSets":4}"#.utf8))
        XCTAssertEqual(legacy.resolvedTheme, .studio)
        XCTAssertEqual(legacy.resolvedAppearance, .system)
        XCTAssertEqual(legacy.unit, .kg)
        var future = legacy
        future.designTheme = "future-design"
        future.appearance = "future-mode"
        XCTAssertEqual(future.resolvedTheme, .studio)
        XCTAssertEqual(future.resolvedAppearance, .system)
    }
    func testThemeBackupRoundTripPreservesWorkout() throws {
        var backup = fixture()
        backup.preferences.designTheme = DesignTheme.velocity.rawValue
        backup.preferences.appearance = AppAppearance.dark.rawValue
        let restored = try Backup.decode(backup.encoded())
        XCTAssertEqual(restored, backup)
        XCTAssertEqual(restored.preferences.resolvedTheme, .velocity)
        XCTAssertEqual(restored.preferences.resolvedAppearance, .dark)
    }
    func testReorderPreservesAllLogsAndRoutineUntilExplicitSave() throws {
        let backup = fixture()
        let original = backup.sessions[0]
        let ids = original.logs.map(\.id).reversed().map { $0 }
        let reordered = try WorkoutLogic.reordering(original, exerciseIDs: ids)
        var expected = original
        expected.logs.reverse()
        XCTAssertEqual(reordered, expected)
        XCTAssertEqual(reordered.completedSets, original.completedSets)
        XCTAssertEqual(reordered.volume, original.volume)
        XCTAssertEqual(backup.days[0].exerciseIDs, original.logs.map(\.id))
        var changed = backup; changed.sessions[0] = reordered
        let saved = try WorkoutLogic.savingLineup(reordered, in: changed)
        XCTAssertEqual(saved.days[0].exerciseIDs, ids)
        XCTAssertEqual(saved.days[0].name, backup.days[0].name)
        XCTAssertEqual(saved.days[0].weekdays, backup.days[0].weekdays)
        XCTAssertEqual(saved.sessions, changed.sessions)
        XCTAssertNoThrow(try saved.validated())
    }
    func testSavingLineupKeepsLatestRoutineMetadataAndTargets() throws {
        var backup = fixture()
        let original = backup.sessions[0]
        backup.days[0].name = "Renamed while training"
        backup.days[0].weekdays = [1, 6]
        backup.days[0].targets = [RepTarget(exerciseID: original.logs[0].id, range: RepRange(lower: 5, upper: 7))]
        let reordered = try WorkoutLogic.reordering(original, exerciseIDs: original.logs.map(\.id).reversed())
        let saved = try WorkoutLogic.savingLineup(reordered, in: backup)
        XCTAssertEqual(saved.days[0].name, backup.days[0].name)
        XCTAssertEqual(saved.days[0].weekdays, backup.days[0].weekdays)
        XCTAssertEqual(saved.days[0].targets, backup.days[0].targets)
        XCTAssertEqual(saved.sessions[0], original)
        XCTAssertEqual(saved.days[0].supersets, original.supersets)
    }
    func testReorderRejectsStaleDuplicateMissingOrFinishedLineup() throws {
        let session = fixture().sessions[0]
        XCTAssertThrowsError(try WorkoutLogic.reordering(session, exerciseIDs: [session.logs[0].id, session.logs[0].id]))
        XCTAssertThrowsError(try WorkoutLogic.reordering(session, exerciseIDs: [UUID(), session.logs[0].id]))
        XCTAssertThrowsError(try WorkoutLogic.reordering(session, exerciseIDs: [session.logs[0].id]))
        var finished = session; finished.end = .now
        XCTAssertThrowsError(try WorkoutLogic.reordering(finished, exerciseIDs: finished.logs.map(\.id)))
    }
    func testSessionAdditionIsIdempotentAndDoesNotChangeOriginalSets() throws {
        let backup = fixture()
        let extra = ExerciseRecord(name: "Curl", muscle: "Biceps")
        let result = try WorkoutLogic.adding([extra, extra, backup.exercises[0]], to: backup.sessions[0], history: [], count: 4)
        XCTAssertEqual(result.logs.count, 3)
        XCTAssertEqual(Array(result.logs.prefix(2)), backup.sessions[0].logs)
        XCTAssertEqual(result.logs[2].sets.count, 4)
        XCTAssertFalse(result.logs[2].sets.contains(where: \.completed))
        XCTAssertEqual(backup.days[0].exerciseIDs.count, 2)
        var updated = backup; updated.sessions[0] = result
        let saved = try WorkoutLogic.savingLineup(result, in: updated)
        XCTAssertEqual(saved.exercises.last, extra)
        XCTAssertEqual(saved.days[0].exerciseIDs, result.logs.map(\.id))
        XCTAssertEqual(saved.sessions[0], result)
        XCTAssertNoThrow(try saved.validated())
    }
    func testCannotSaveToDeletedRoutineOrAddToFinishedWorkout() throws {
        var backup = fixture()
        let session = backup.sessions[0]
        backup.days = []
        XCTAssertThrowsError(try WorkoutLogic.savingLineup(session, in: backup))
        var finished = session; finished.end = .now
        XCTAssertThrowsError(try WorkoutLogic.adding([ExerciseRecord(name: "Curl", muscle: "Arms")], to: finished, history: [], count: 3))
    }
    func testAdditionUsesCompletedHistoryAndHonorsLimit() throws {
        let backup = fixture()
        let exercise = ExerciseRecord(name: "Curl", muscle: "Arms")
        let old = SessionRecord(dayType: .pull, start: .distantPast, end: Date(timeIntervalSince1970: 1), logs: [ExerciseLog(exercise: exercise, sets: [LoggedSet(weightKg: 13, reps: 7, completed: true)])])
        let added = try WorkoutLogic.adding([exercise], to: backup.sessions[0], history: [old], count: 3)
        XCTAssertEqual(added.logs.last?.sets.map(\.weightKg), [13, 13, 13])
        let tooMany = (0..<99).map { ExerciseRecord(name: "Custom \($0)", muscle: "Arms") }
        XCTAssertThrowsError(try WorkoutLogic.adding(tooMany, to: backup.sessions[0], history: [], count: 3))
    }
}
