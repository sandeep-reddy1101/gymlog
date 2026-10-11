import Foundation
import SwiftData

@Model final class Exercise {
    @Attribute(.unique) var id: UUID
    var payload: Data
    init(id: UUID, payload: Data) { self.id = id; self.payload = payload }
}
@Model final class WorkoutDay {
    @Attribute(.unique) var id: UUID
    var payload: Data
    init(id: UUID, payload: Data) { self.id = id; self.payload = payload }
}
@Model final class WorkoutSession {
    @Attribute(.unique) var id: UUID
    var payload: Data
    init(id: UUID, payload: Data) { self.id = id; self.payload = payload }
}
@Model final class AppSettings {
    @Attribute(.unique) var key: String
    var payload: Data
    init(payload: Data) { key = "preferences"; self.payload = payload }
}

// Versioned Codable payloads keep set snapshots independent of edits to the plan.
// Only changed objects are written; one explicit SwiftData save commits each action.
@MainActor final class Persistence {
    let container: ModelContainer
    let context: ModelContext
    init(inMemory: Bool = false) throws {
        let schema = Schema([Exercise.self, WorkoutDay.self, WorkoutSession.self, AppSettings.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
        container = try ModelContainer(for: schema, configurations: [configuration])
        context = ModelContext(container)
        context.autosaveEnabled = false
    }

    func load() throws -> Backup? {
        let decoder = JSONDecoder()
        let settings = try context.fetch(FetchDescriptor<AppSettings>())
        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        let days = try context.fetch(FetchDescriptor<WorkoutDay>())
        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        guard let preferences = settings.first else {
            guard exercises.isEmpty && days.isEmpty && sessions.isEmpty else {
                throw BackupError.invalid("The local store is incomplete. Your files have been preserved.")
            }
            return nil
        }
        return try Backup(exercises: exercises.map { try decoder.decode(ExerciseRecord.self, from: $0.payload) },
                          days: days.map { try decoder.decode(DayRecord.self, from: $0.payload) },
                          sessions: sessions.map { try decoder.decode(SessionRecord.self, from: $0.payload) },
                          preferences: decoder.decode(Preferences.self, from: preferences.payload)).validated()
    }

    func save(_ backup: Backup, previous: Backup? = nil) throws {
        _ = try backup.validated()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let oldExercises = Dictionary(uniqueKeysWithValues: (previous?.exercises ?? []).map { ($0.id, $0) })
        let oldDays = Dictionary(uniqueKeysWithValues: (previous?.days ?? []).map { ($0.id, $0) })
        let oldSessions = Dictionary(uniqueKeysWithValues: (previous?.sessions ?? []).map { ($0.id, $0) })
        do {
            let exercises = try context.fetch(FetchDescriptor<Exercise>())
            let exerciseMap = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
            let exerciseIDs = Set(backup.exercises.map(\.id))
            for old in exercises where !exerciseIDs.contains(old.id) { context.delete(old) }
            for value in backup.exercises {
                if oldExercises[value.id] == value { continue }
                let data = try encoder.encode(value)
                if let existing = exerciseMap[value.id] {
                    if existing.payload != data { existing.payload = data }
                } else { context.insert(Exercise(id: value.id, payload: data)) }
            }
            let days = try context.fetch(FetchDescriptor<WorkoutDay>())
            let dayMap = Dictionary(uniqueKeysWithValues: days.map { ($0.id, $0) })
            let dayIDs = Set(backup.days.map(\.id))
            for old in days where !dayIDs.contains(old.id) { context.delete(old) }
            for value in backup.days {
                if oldDays[value.id] == value { continue }
                let data = try encoder.encode(value)
                if let existing = dayMap[value.id] {
                    if existing.payload != data { existing.payload = data }
                } else { context.insert(WorkoutDay(id: value.id, payload: data)) }
            }
            let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
            let sessionMap = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
            let sessionIDs = Set(backup.sessions.map(\.id))
            for old in sessions where !sessionIDs.contains(old.id) { context.delete(old) }
            for value in backup.sessions {
                if oldSessions[value.id] == value { continue }
                let data = try encoder.encode(value)
                if let existing = sessionMap[value.id] {
                    if existing.payload != data { existing.payload = data }
                } else { context.insert(WorkoutSession(id: value.id, payload: data)) }
            }
            let settings = try context.fetch(FetchDescriptor<AppSettings>())
            let data = try encoder.encode(backup.preferences)
            if let existing = settings.first {
                if existing.payload != data { existing.payload = data }
            } else { context.insert(AppSettings(payload: data)) }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
