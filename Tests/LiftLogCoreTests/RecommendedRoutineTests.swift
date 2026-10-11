import XCTest
@testable import LiftLogCore

final class RecommendedRoutineTests: XCTestCase {
    private var empty: Backup { Backup(exportedAt: Date(timeIntervalSince1970: 1800000000), exercises: [], days: [], sessions: [], preferences: Preferences()) }
    private func entry(_ move: RecommendedMove) -> CatalogExercise {
        CatalogExercise(exerciseId: move.providerID!, name: move.providerName!, gifUrl: "https://static.exercisedb.dev/media/\(move.providerID!).gif",
                        bodyParts: ["back"], equipments: [move.equipment], targetMuscles: ["test muscle"], secondaryMuscles: [], instructions: ["Test instruction"])
    }
    private func draft(_ template: RecommendedRoutine) -> RecommendedRoutineDraft {
        RecommendedRoutineDraft(templateID: template.id, type: template.type, name: template.title, weekdays: [template.type.weekday],
                                exercises: template.moves.filter { !$0.optional && $0.providerID != nil }.map(entry))
    }
    func testPlanMatchesOriginalOrderScheduleAndExplicitGaps() {
        let plan = RecommendedRoutine.all
        XCTAssertEqual(plan.map(\.type), [.push, .pull, .legs, .upper, .lower])
        XCTAssertEqual(plan.map { $0.type.weekday }, [2, 3, 4, 6, 7])
        XCTAssertEqual(plan.map { $0.moves.count }, [6, 7, 6, 6, 6])
        XCTAssertEqual(plan.flatMap(\.moves).filter { $0.providerID == nil }.map(\.title), ["DB hip thrust", "DB walking lunges"])
        XCTAssertEqual(plan.flatMap(\.moves).filter(\.optional).map(\.title), ["DB shrug"])
        XCTAssertEqual(plan[1].moves[1].providerID, "7vG5o25")
        XCTAssertEqual(plan[1].moves[2].providerID, "C0MA9bC")
        XCTAssertEqual(plan[3].moves[2].providerID, "BJ0Hz5L")
        XCTAssertEqual(plan[2].moves[2].providerID, "qx4fgX7")
    }
    func testPinnedMatchesRejectWrongIdentityEquipmentNameAndMissingGuide() throws {
        let move = RecommendedRoutine.all[0].moves[0]
        let good = entry(move)
        XCTAssertNoThrow(try move.validate(good))
        func changed(id: String? = nil, name: String? = nil, equipment: [String]? = nil, instructions: [String]? = nil) -> CatalogExercise {
            CatalogExercise(exerciseId: id ?? good.id, name: name ?? good.name, gifUrl: good.gifUrl, bodyParts: good.bodyParts,
                            equipments: equipment ?? good.equipments, targetMuscles: good.targetMuscles, secondaryMuscles: [], instructions: instructions ?? good.instructions)
        }
        XCTAssertThrowsError(try move.validate(changed(id: "wrong")))
        XCTAssertThrowsError(try move.validate(changed(name: "dumbbell incline fly")))
        XCTAssertThrowsError(try move.validate(changed(equipment: ["leverage machine"])))
        XCTAssertThrowsError(try move.validate(changed(equipment: ["dumbbell", "stability ball"])))
        XCTAssertThrowsError(try move.validate(changed(instructions: [])))
        XCTAssertNoThrow(try move.validate(changed(name: good.name.uppercased())))
    }
    func testBatchCreatesOrderedRoutinesAndSharesProviderHistoryIdentity() throws {
        let drafts = RecommendedRoutine.all.map(draft)
        let backup = try RecommendedRoutineImport.adding(drafts, to: empty)
        XCTAssertEqual(backup.days.map(\.title), ["Push", "Pull", "Legs", "Upper", "Lower"])
        XCTAssertEqual(backup.days.map(\.scheduledWeekdays), [[2], [3], [4], [6], [7]])
        XCTAssertEqual(backup.days.map { $0.exerciseIDs.count }, [6, 6, 6, 6, 4])
        XCTAssertEqual(backup.days[0].exerciseIDs[0], backup.days[3].exerciseIDs[0])
        XCTAssertEqual(backup.days[1].exerciseIDs[0], backup.days[3].exerciseIDs[1])
        XCTAssertEqual(backup.preferences.routineOrder, backup.days.map(\.id))
        XCTAssertEqual(Set(backup.exercises.compactMap(\.exerciseDBID)).count, backup.exercises.count)
        XCTAssertTrue(backup.sessions.isEmpty)
        XCTAssertEqual(try Backup.decode(backup.encoded()), backup)
    }
    func testExistingProviderIdentityAndSessionArePreservedWithoutNameMerging() throws {
        let push = draft(RecommendedRoutine.all[0])
        var existing = push.exercises[0].record; existing.id = UUID(); existing.name = "My incline press"
        let sameName = ExerciseRecord(name: push.exercises[1].name, muscle: "Chest", equipment: .dumbbell)
        let oldDay = DayRecord(type: .upper, exerciseIDs: [existing.id], name: "My plan", weekdays: [1])
        let session = SessionRecord(dayType: .upper, logs: [ExerciseLog(exercise: existing, sets: [LoggedSet(weightKg: 20, reps: 8, completed: true)])], routineID: oldDay.id)
        let original = Backup(exercises: [existing, sameName], days: [oldDay], sessions: [session], preferences: Preferences())
        let added = try RecommendedRoutineImport.adding([push], to: original)
        XCTAssertEqual(added.days[0], oldDay)
        XCTAssertEqual(added.sessions, original.sessions)
        XCTAssertEqual(added.days[1].exerciseIDs[0], existing.id)
        XCTAssertNotEqual(added.days[1].exerciseIDs[1], sameName.id)
        XCTAssertEqual(added.exercises[0], existing)
    }
    func testHistoricalProviderIdentityIsReusedWhenNotInLibrary() throws {
        let push = draft(RecommendedRoutine.all[0])
        var historical = push.exercises[0].record; historical.id = UUID()
        let history = SessionRecord(dayType: .push, start: Date(timeIntervalSince1970: 1789999900), end: Date(timeIntervalSince1970: 1790000000), logs: [ExerciseLog(exercise: historical, sets: [LoggedSet(weightKg: 25, reps: 8, completed: true)])])
        var backup = empty; backup.sessions = [history]
        let added = try RecommendedRoutineImport.adding([push], to: backup)
        XCTAssertEqual(added.days[0].exerciseIDs[0], historical.id)
        XCTAssertEqual(added.sessions, [history])
        XCTAssertEqual(WorkoutLogic.quickFill(exercise: added.exercises[0], sessions: added.sessions, count: 3).sets[0].weightKg, 25)
    }
    func testRepeatImportIsRejectedAndDeletingAllowsReimport() throws {
        let push = draft(RecommendedRoutine.all[0])
        var once = try RecommendedRoutineImport.adding([push], to: empty)
        XCTAssertThrowsError(try RecommendedRoutineImport.adding([push], to: once))
        XCTAssertNil(WorkoutLogic.duplicate(once.days[0]).recommendedTemplateID)
        once.days = []
        let again = try RecommendedRoutineImport.adding([push], to: once)
        XCTAssertEqual(again.exercises.count, once.exercises.count)
        XCTAssertEqual(again.days.count, 1)
    }
    func testInvalidBatchNeverChangesOriginalAndRespectsLimits() throws {
        let push = draft(RecommendedRoutine.all[0])
        let original = empty
        XCTAssertThrowsError(try RecommendedRoutineImport.adding([], to: original))
        XCTAssertThrowsError(try RecommendedRoutineImport.adding([push, push], to: original))
        var bad = draft(RecommendedRoutine.all[1]); bad.name = " "
        XCTAssertThrowsError(try RecommendedRoutineImport.adding([push, bad], to: original))
        bad.name = "Pull"; bad.exercises = []
        XCTAssertThrowsError(try RecommendedRoutineImport.adding([push, bad], to: original))
        bad.exercises = [push.exercises[0], push.exercises[0]]
        XCTAssertThrowsError(try RecommendedRoutineImport.adding([push, bad], to: original))
        var full = original
        full.days = (0..<100).map { DayRecord(type: .push, exerciseIDs: [], name: "Routine \($0)", weekdays: []) }
        XCTAssertThrowsError(try RecommendedRoutineImport.adding([push], to: full))
        XCTAssertTrue(original.days.isEmpty)
        XCTAssertTrue(original.exercises.isEmpty)
    }
    func testUnscheduledRenamedRoutineAndLegacyBackupCompatibility() throws {
        var push = draft(RecommendedRoutine.all[0]); push.name = "  Morning  "; push.weekdays = []
        let added = try RecommendedRoutineImport.adding([push], to: empty)
        XCTAssertEqual(added.days[0].name, "Morning")
        XCTAssertEqual(added.days[0].scheduledWeekdays, [])
        let old = DayRecord(type: .legs, exerciseIDs: [])
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as! [String: Any]
        json.removeValue(forKey: "recommendedTemplateID")
        let restored = try JSONDecoder().decode(DayRecord.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(restored.recommendedTemplateID)
        XCTAssertEqual(restored, old)
    }
}

private actor RecommendationTransport {
    var calls = 0
    var status = 200
    var changedID: String?
    private var pauseNext = false
    private var paused = false
    private var requestGate: CheckedContinuation<Void, Never>?
    private var pauseObserver: CheckedContinuation<Void, Never>?
    func pauseNextRequest() { pauseNext = true }
    func waitUntilPaused() async {
        if paused { return }
        await withCheckedContinuation { pauseObserver = $0 }
    }
    func releaseRequest() { requestGate?.resume(); requestGate = nil; paused = false }
    let entries: [String: CatalogExercise]
    init() {
        var rows: [String: CatalogExercise] = [:]
        for move in RecommendedRoutine.all.flatMap(\.moves) {
            guard let id = move.providerID, let name = move.providerName else { continue }
            rows[id] = CatalogExercise(exerciseId: id, name: name, gifUrl: "https://static.exercisedb.dev/media/\(id).gif", bodyParts: ["test"],
                                       equipments: [move.equipment], targetMuscles: ["test"], secondaryMuscles: [], instructions: ["Test"])
        }
        entries = rows
    }
    func configure(status: Int = 200, changedID: String? = nil) { self.status = status; self.changedID = changedID }
    func count() -> Int { calls }
    func fetch(_ url: URL) async throws -> (Data, HTTPURLResponse) {
        calls += 1
        if pauseNext {
            pauseNext = false; paused = true
            pauseObserver?.resume(); pauseObserver = nil
            await withCheckedContinuation { requestGate = $0 }
        }
        var value = entries[url.lastPathComponent]!
        if changedID == value.id {
            value = CatalogExercise(exerciseId: value.id, name: "wrong movement", gifUrl: value.gifUrl, bodyParts: value.bodyParts,
                                    equipments: value.equipments, targetMuscles: value.targetMuscles, secondaryMuscles: [], instructions: value.instructions)
        }
        return (try JSONEncoder().encode(CatalogEnvelope(success: true, data: value)),
                HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: ["Retry-After":"60"])!)
    }
}

extension RecommendedRoutineTests {
    @MainActor func testPreviewRequiresExplicitResolutionOfMissingMovementsAndReusesCache() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let stub = RecommendationTransport()
        let catalog = ExerciseCatalog(directory: directory, spacing: 0, transport: { try await stub.fetch($0) })
        let model = RecommendedPreviewModel(RecommendedRoutine.all)
        await model.refresh(catalog: catalog)
        XCTAssertFalse(model.ready)
        XCTAssertEqual(model.issues.count, 2)
        XCTAssertEqual(model.count, 30)
        let firstCount = await stub.count()
        XCTAssertEqual(firstCount, 19, "Shared exercises across days fetch once; optional shrug isn't fetched")
        let lower = RecommendedRoutine.all[4]
        for move in lower.moves where move.providerID == nil { model.excluded.insert(RecommendedPreviewModel.key(lower, move)) }
        await model.refresh(catalog: catalog)
        XCTAssertTrue(model.ready)
        XCTAssertEqual(model.drafts().map { $0.exercises.count }, [6, 6, 6, 6, 4])
        let secondCount = await stub.count()
        XCTAssertEqual(secondCount, firstCount)
        model.names[RecommendedRoutine.all[0].id] = " "
        XCTAssertFalse(model.ready)
    }
    @MainActor func testPreviewOptionalShrugAndExplicitReplacementPreserveOrder() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let stub = RecommendationTransport()
        let catalog = ExerciseCatalog(directory: directory, spacing: 0, transport: { try await stub.fetch($0) })
        let pull = RecommendedRoutine.all[1]
        let model = RecommendedPreviewModel([pull])
        await model.refresh(catalog: catalog)
        XCTAssertTrue(model.ready)
        XCTAssertEqual(model.count, 6)
        let key = RecommendedPreviewModel.key(pull, pull.moves.last!)
        model.excluded.remove(key)
        await model.refresh(catalog: catalog)
        XCTAssertEqual(model.drafts()[0].exercises.last?.id, "NJzBsGJ")
        XCTAssertEqual(model.count, 7)
        model.replacements[key] = model.resolved[RecommendedPreviewModel.key(pull, pull.moves[0])]
        await model.refresh(catalog: catalog)
        XCTAssertFalse(model.ready, "Choosing the same exercise twice must not silently remove a slot")
        model.replacements[key] = entry(RecommendedRoutine.all[0].moves[0])
        await model.refresh(catalog: catalog)
        XCTAssertTrue(model.ready)
        XCTAssertEqual(model.drafts()[0].exercises.last?.id, "ns0SIbU")
    }
    @MainActor func testChangedListingAndRateLimitBlockCreationWithoutFallback() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let stub = RecommendationTransport()
        let catalog = ExerciseCatalog(directory: directory, spacing: 0, transport: { try await stub.fetch($0) })
        let model = RecommendedPreviewModel([RecommendedRoutine.all[0]])
        await stub.configure(changedID: "ns0SIbU")
        await model.refresh(catalog: catalog)
        XCTAssertFalse(model.ready)
        XCTAssertEqual(model.issues.count, 1)
        XCTAssertEqual(model.resolved.count, 5)
        await catalog.clearCache()
        await stub.configure(status: 429)
        let before = await stub.count()
        await model.refresh(catalog: catalog)
        XCTAssertFalse(model.ready)
        XCTAssertNotNil(model.error)
        XCTAssertTrue(model.resolved.isEmpty)
        await model.refresh(catalog: catalog)
        let after = await stub.count()
        XCTAssertEqual(after, before + 1, "Cooldown prevents repeated requests, including Retry")
    }
}


extension RecommendedRoutineTests {
    @MainActor func testRefreshKeepsVisibleMatchesButBlocksSavingUntilRevalidated() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let stub = RecommendationTransport()
        let catalog = ExerciseCatalog(directory: directory, spacing: 0, transport: { try await stub.fetch($0) })
        let model = RecommendedPreviewModel([RecommendedRoutine.all[0]])
        await model.refresh(catalog: catalog)
        let displayed = model.resolved
        await catalog.clearCache()
        await stub.pauseNextRequest()
        let refresh = Task { await model.refresh(catalog: catalog) }
        await stub.waitUntilPaused()
        XCTAssertTrue(model.loading)
        XCTAssertFalse(model.ready)
        XCTAssertEqual(model.resolved, displayed, "Refreshing must not collapse visible rows and jump the scroll position")
        await stub.releaseRequest()
        await refresh.value
        XCTAssertTrue(model.ready)
        XCTAssertEqual(model.resolved, displayed)
    }
}
