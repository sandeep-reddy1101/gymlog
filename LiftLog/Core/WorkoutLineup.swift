import Foundation

extension WorkoutLogic {
    /// Only the sequence changes. Logs, set identities, notes, pairings and sensor state are retained.
    static func reordering(_ session: SessionRecord, exerciseIDs: [UUID]) throws -> SessionRecord {
        guard session.end == nil, exerciseIDs.count == session.logs.count,
              Set(exerciseIDs).count == exerciseIDs.count,
              Set(exerciseIDs) == Set(session.logs.map(\.id)) else {
            throw BackupError.invalid("The workout changed. Reopen the lineup and try again.")
        }
        var result = session
        let logs = Dictionary(uniqueKeysWithValues: session.logs.map { ($0.id, $0) })
        result.logs = exerciseIDs.compactMap { logs[$0] }
        return result
    }

    static func adding(_ exercises: [ExerciseRecord], to session: SessionRecord,
                       history: [SessionRecord], count: Int) throws -> SessionRecord {
        guard session.end == nil else { throw BackupError.invalid("This workout has finished.") }
        var result = session
        for exercise in exercises where !result.logs.contains(where: { $0.id == exercise.id }) {
            result.logs.append(quickFill(exercise: exercise, sessions: history, count: count))
        }
        guard result.logs.count <= 100 else { throw BackupError.invalid("A workout can contain up to 100 exercises.") }
        return result
    }

    /// Explicit opt-in: changes the routine, never the session or its recorded data.
    static func savingLineup(_ session: SessionRecord, in backup: Backup) throws -> Backup {
        guard session.end == nil, let routineID = session.routineID,
              let index = backup.days.firstIndex(where: { $0.id == routineID }) else {
            throw BackupError.invalid("The original routine is no longer available.")
        }
        var result = backup
        let ids = session.logs.map(\.id)
        for log in session.logs where !result.exercises.contains(where: { $0.id == log.id }) {
            result.exercises.append(log.exercise)
        }
        result.days[index].exerciseIDs = ids
        result.days[index].targets = result.days[index].targets?.filter { ids.contains($0.exerciseID) }
        result.days[index].supersets = session.supersets
        return try result.validated()
    }
}
