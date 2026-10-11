import SwiftUI
import Observation

@MainActor @Observable final class AppStore {
    private let persistence: Persistence
    var data: Backup
    var errorMessage: String?
    var celebration: String?
    var pendingUndo: WorkoutUndo?
    let restNotifications = RestNotifications()
    let health = HealthService()
    let watch = WatchWorkoutService()
    var completedSessionID: UUID?
    var isDemo: Bool
    var editingSets: Set<UUID> = []
    var entryDrafts: [UUID: SetEntryDraft] = [:]
    var matchingSessions: Set<UUID> = []
    private var dataGeneration = UUID()

    var exercises: [ExerciseRecord] { data.exercises.sorted { $0.name < $1.name } }
    var days: [DayRecord] { data.days }
    var sessions: [SessionRecord] { data.sessions.sorted { $0.start > $1.start } }
    var finished: [SessionRecord] { sessions.filter { $0.end != nil } }
    var active: SessionRecord? { sessions.first { $0.end == nil } }
    var unit: WeightUnit { data.preferences.unit }

    init(inMemory: Bool = false, demo: Bool = false) throws {
        persistence = try Persistence(inMemory: inMemory)
        isDemo = demo
        if let saved = try persistence.load() {
            data = saved
        }
        else {
            let plan = demo ? (exercises: SeedData.samplePlan().exercises, days: [DayRecord]()) : SeedData.plan()
            data = Backup(exercises: plan.exercises, days: plan.days,
                          sessions: demo ? SeedData.sampleSessions(exercises: plan.exercises, days: SeedData.samplePlan().days) : [], preferences: Preferences())
            try persistence.save(data)
        }
        if demo { health.loadSampleTrends() }
        else {
            syncRestAlerts()
            watch.onReport = { [weak self] report in self?.receiveWatch(report) ?? false }
            watch.configure(enabled: health.enabled)
            watch.reconcile(sessions: data.sessions)
        }
    }

    @discardableResult func commit(_ change: (inout Backup) -> Void) -> Bool {
        var next = data
        change(&next)
        next.preferences.routineOrder = next.days.map(\.id)
        do {
            try persistence.save(next, previous: data)
            let restChanged = active?.restTimer != next.sessions.first(where: { $0.end == nil })?.restTimer || data.preferences.restAlerts != next.preferences.restAlerts
            data = next
            if restChanged { syncRestAlerts() }
            return true
        } catch {
            errorMessage = "Could not save: \(error.localizedDescription)"
            return false
        }
    }

    func session(_ id: UUID) -> SessionRecord? { data.sessions.first { $0.id == id } }
    @discardableResult func updateSession(_ value: SessionRecord) -> Bool {
        let value = WorkoutLogic.normalizingRest(in: value)
        return commit { backup in
            if let index = backup.sessions.firstIndex(where: { $0.id == value.id }) { backup.sessions[index] = value }
        }
    }
    @discardableResult func reorderLineup(_ id: UUID, exerciseIDs: [UUID]) -> Bool {
        guard let session = session(id) else { return false }
        do { return updateSession(try WorkoutLogic.reordering(session, exerciseIDs: exerciseIDs)) }
        catch { errorMessage = error.localizedDescription; return false }
    }
    @discardableResult func saveLineup(_ id: UUID) -> Bool {
        guard let session = session(id) else { return false }
        do {
            let next = try WorkoutLogic.savingLineup(session, in: data)
            return commit { $0 = next }
        } catch { errorMessage = error.localizedDescription; return false }
    }
    @discardableResult func addExercises(_ exercises: [ExerciseRecord], dayID: UUID? = nil, sessionID: UUID? = nil) -> Bool {
        do {
            var next = data
            if let sessionID, let index = next.sessions.firstIndex(where: { $0.id == sessionID }) {
                next.sessions[index] = try WorkoutLogic.adding(exercises, to: next.sessions[index], history: finished, count: next.preferences.defaultSets)
            } else if let dayID, let index = next.days.firstIndex(where: { $0.id == dayID }) {
                next.days[index] = ExerciseLibrary.adding(exercises.map(\.id), to: next.days[index])
            } else { throw BackupError.invalid("This routine or workout is no longer available.") }
            for exercise in exercises where !next.exercises.contains(where: { $0.id == exercise.id }) { next.exercises.append(exercise) }
            _ = try next.validated()
            return commit { $0 = next }
        } catch { errorMessage = error.localizedDescription; return false }
    }
    func start(_ day: DayRecord) {
        guard active == nil else { return }
        let logs = day.exerciseIDs.compactMap { id -> ExerciseLog? in
            guard let exercise = exercises.first(where: { $0.id == id }) else { return nil }
            var log = WorkoutLogic.quickFill(exercise: exercise, sessions: finished, count: data.preferences.defaultSets)
            log.target = day.targets?.first { $0.exerciseID == id }?.range
            return log
        }
        guard !logs.isEmpty else { errorMessage = "Add an exercise to this day first."; return }
        let session = SessionRecord(dayType: day.type, logs: logs, isSample: isDemo, routineID: day.id, routineName: day.title, supersets: day.supersets)
        if commit({ $0.sessions.append(session) }), data.preferences.automaticWatchTracking == true { startWatch(session.id) }
    }
    func finish(_ id: UUID) {
        guard var session = session(id), session.end == nil, session.completedSets > 0 else { return }
        session.end = .now
        session.restTimer = nil
        let records = WorkoutLogic.records(in: session, history: finished)
        guard updateSession(session) else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        celebration = records.isEmpty ? "Workout saved. Nice work." : "Workout saved · \(records.count) new personal record\(records.count == 1 ? "" : "s")!"
        completedSessionID = id
        if session.watchTracking != nil {
            if session.watchTracking?.isImported != true && session.watchTracking?.report?.phase.isTerminal != true {
                watch.end(sessionID: id, title: session.title, at: session.end!)
            }
        } else if !isDemo && health.enabled && health.hasRequestedAccess { Task { await matchHealth(id) } }
    }
    func delete(_ id: UUID) {
        guard let old = session(id) else { return }
        if commit({ $0.sessions.removeAll { $0.id == id } }) {
            var restorable = old
            if old.end == nil, old.watchTracking != nil, old.watchTracking?.isImported != true {
                watch.end(sessionID: id, title: old.title, at: .now, discard: true)
                // Undo restores the sets, but cannot undo a stopped/discarded sensor recording.
                restorable.watchTracking = nil
            }
            pendingUndo = WorkoutUndo(title: old.end == nil ? "Workout discarded" : "Workout deleted", change: .deletion(restorable))
        }
    }
    func undoLastAction() {
        guard let pendingUndo else { return }
        do {
            let restored = try pendingUndo.restoring(in: data)
            if commit({ $0 = restored }) { self.pendingUndo = nil; celebration = nil }
        } catch { errorMessage = error.localizedDescription }
    }
    func updateSet(sessionID: UUID, exerciseID: UUID, set: LoggedSet) {
        guard let original = session(sessionID),
              let previous = original.logs.first(where: { $0.id == exerciseID })?.sets.first(where: { $0.id == set.id }) else { return }
        let updated = WorkoutLogic.changingSet(set, exerciseID: exerciseID, in: original, preferences: data.preferences)
        if updateSession(updated), previous.completed != set.completed {
            pendingUndo = WorkoutUndo(title: set.completed ? "Set completed" : "Set unchecked", change: .set(sessionID: sessionID, exerciseID: exerciseID, before: previous, after: set, oldRest: original.restTimer, newRest: updated.restTimer))
            if set.completed { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        }
    }
    func syncRestAlerts() {
        guard !isDemo else { return }
        restNotifications.reconcile(timer: active?.restTimer, enabled: data.preferences.restAlerts ?? false)
    }
    func enableRestAlerts() async {
        guard !isDemo else { return }
        let granted = await restNotifications.requestPermission()
        _ = commit { $0.preferences.restAlerts = granted }
        if granted { syncRestAlerts() }
    }
    func changeRest(_ action: (inout RestTimerState?) -> Void) {
        guard var session = active else { return }
        action(&session.restTimer)
        _ = updateSession(session)
    }
    @discardableResult func swapExercise(_ id: UUID, with replacement: ExerciseRecord, sessionID: UUID) -> Bool {
        guard let session = session(sessionID) else { return false }
        do {
            let updated = try WorkoutLogic.swapping(id, with: replacement, in: session, history: finished)
            guard let before = session.logs.first(where: { $0.id == id }), let after = updated.logs.first(where: { $0.id == replacement.id }), updateSession(updated) else { return false }
            pendingUndo = WorkoutUndo(title: "Exercise swapped", change: .swap(sessionID: sessionID, before: before, after: after, oldPairs: session.supersets, newPairs: updated.supersets))
            return true
        }
        catch { errorMessage = error.localizedDescription; return false }
    }
    func matchHealth(_ id: UUID) async {
        guard !isDemo, let original = session(id), original.end != nil, !original.isSample, health.enabled,
              !matchingSessions.contains(id) else { return }
        matchingSessions.insert(id)
        let generation = dataGeneration
        defer { matchingSessions.remove(id) }
        do {
            let summary = try await health.match(original)
            // Re-read after the query so a set edit during the query cannot be overwritten.
            guard generation == dataGeneration, let latest = session(id) else { return }
            _ = updateSession(WorkoutLogic.receivingHealth(summary, in: latest))
        } catch {
            guard generation == dataGeneration, let latest = session(id) else { return }
            _ = updateSession(WorkoutLogic.receivingHealth(nil, in: latest, failed: true))
        }
    }
    func importBackup(_ backup: Backup) {
        guard canReplaceData else { return }
        do {
            var checked = try backup.validated()
            for index in checked.sessions.indices where checked.sessions[index].watchTracking != nil {
                checked.sessions[index].watchTracking?.isImported = true
            }
            try persistence.save(checked)
            data = checked
            dataGeneration = UUID()
            editingSets.removeAll()
            entryDrafts.removeAll()
            pendingUndo = nil
            syncRestAlerts()
        } catch { errorMessage = "Import failed; your existing data was kept. \(error.localizedDescription)" }
    }
    func reset() {
        guard canReplaceData else { return }
        let plan = SeedData.plan()
        if commit({ $0 = Backup(exercises: plan.exercises, days: plan.days, sessions: [], preferences: Preferences()) }) {
            dataGeneration = UUID()
            editingSets.removeAll()
            entryDrafts.removeAll()
            pendingUndo = nil
        }
    }

    private var canReplaceData: Bool {
        if !isDemo && (watch.hasUnfinishedDelivery || data.sessions.contains { $0.watchTracking != nil && $0.watchTracking?.isImported != true && $0.watchTracking?.report?.phase.isTerminal != true }) {
            errorMessage = "Finish or discard your Watch workout and wait for the Watch to confirm before replacing local data."
            return false
        }
        return true
    }

    func startWatch(_ id: UUID) {
        guard !isDemo, health.enabled, var current = session(id), current.end == nil,
              current.watchTracking?.isImported != true,
              current.watchTracking?.report?.phase.isTerminal != true else { return }
        current.watchTracking = current.watchTracking ?? WatchTracking(requestedAt: .now)
        guard updateSession(current) else { return }
        watch.begin(sessionID: id, title: current.title)
    }

    func refreshWatch(_ id: UUID) {
        guard !isDemo, let session = session(id), session.watchTracking != nil else { return }
        if let end = session.end, session.watchTracking?.isImported != true, session.watchTracking?.report?.phase.isTerminal != true {
            watch.end(sessionID: id, title: session.title, at: end)
        }
        watch.refresh()
        if session.end != nil { Task { await matchHealth(id) } }
    }

    private func receiveWatch(_ report: WatchWorkoutReport) -> Bool {
        guard !isDemo else { return false }
        guard let current = session(report.sessionID) else { return true }
        guard let updated = WorkoutLogic.receivingWatch(report, in: current) else { return true }
        return updateSession(updated)
    }
}
