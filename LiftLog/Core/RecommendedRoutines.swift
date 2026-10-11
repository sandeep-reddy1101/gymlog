import Foundation
import Observation

/// Curated references to the user's plan, not a bundled exercise catalog.
/// Names, instructions and media shown for a match always come from a validated API detail response.
struct RecommendedMove: Identifiable, Sendable {
    let id: String
    let title: String
    let providerID: String?
    let providerName: String?
    var equipment = "dumbbell"
    var optional = false
    var note: String? = nil

    func validate(_ exercise: CatalogExercise) throws {
        guard exercise.id == providerID,
              exercise.name.caseInsensitiveCompare(providerName ?? "") == .orderedSame,
              exercise.equipments.map({ $0.lowercased() }).sorted() == [equipment],
              !exercise.instructions.isEmpty else {
            throw BackupError.invalid("The provider listing for \(title) changed. Choose an exercise to review the replacement.")
        }
    }
}

struct RecommendedRoutine: Identifiable {
    let type: DayType
    let moves: [RecommendedMove]
    var id: String { "dumbbell-five-day-v1-" + type.rawValue }
    var title: String { type.title }

    static let all: [RecommendedRoutine] = {
        func move(_ id: String, _ title: String, _ providerID: String?, _ providerName: String?,
                  equipment: String = "dumbbell", optional: Bool = false, note: String? = nil) -> RecommendedMove {
            RecommendedMove(id: id, title: title, providerID: providerID, providerName: providerName,
                            equipment: equipment, optional: optional, note: note)
        }
        let incline = move("incline", "Incline DB press", "ns0SIbU", "dumbbell incline bench press")
        let lateral = move("lateral", "Lateral raises", "DsgkuIt", "dumbbell lateral raise")
        let extensionMove = move("extension", "Overhead DB extension", "kont8Ut", "dumbbell seated triceps extension", note: "Seated overhead version, holding one dumbbell with both hands.")
        let pullup = move("pullup", "Pull-ups", "lBDjFxJ", "pull-up", equipment: "bodyweight")
        let curl = move("curl", "Seated incline curl", "ae9UoXQ", "dumbbell incline curl")
        let goblet = move("goblet", "Goblet squat", "yn8yg1r", "dumbbell goblet squat")
        let singleRDL = move("single-rdl", "Single-leg DB RDL", "gKozT8X", "dumbbell single leg deadlift", note: "Single-leg hip-hinge version with a soft knee bend.")
        let step = move("step", "DB step-ups", "aXtJhlg", "dumbbell step-up")
        let calf = move("calf", "Single-leg calf raise", "1kB3Wmk", "dumbbell single leg calf raise")
        return [
            RecommendedRoutine(type: .push, moves: [incline,
                move("flat", "Flat DB press", "SpYC0Kp", "dumbbell bench press"),
                move("shoulder", "DB shoulder press", "znQUdHY", "dumbbell seated shoulder press"), lateral,
                move("fly", "DB fly", "yz9nUhF", "dumbbell fly"), extensionMove]),
            RecommendedRoutine(type: .pull, moves: [pullup,
                move("supported-row", "Chest-supported incline row", "7vG5o25", "dumbbell incline row", note: "Chest supported on an incline bench."),
                move("one-arm-row", "DB row", "C0MA9bC", "Dumbbell Single-Arm Bent-Over Row", note: "Single-arm version; the Upper routine uses the two-arm row."),
                move("reverse-fly", "Rear delt reverse fly", "EAs3xL9", "dumbbell reverse fly"), curl,
                move("hammer", "Seated incline hammer curl", "ByX0WxV", "dumbbell incline hammer curl"),
                move("shrug", "DB shrug", "NJzBsGJ", "dumbbell shrug", optional: true)]),
            RecommendedRoutine(type: .legs, moves: [goblet,
                move("rdl", "DB Romanian deadlift", "rR0LJzx", "dumbbell romanian deadlift"),
                move("bulgarian", "Bulgarian split squat", "qx4fgX7", "dumbbell single leg split squat", note: "Provider instructions specify the rear foot elevated on a bench."), singleRDL, step, calf]),
            RecommendedRoutine(type: .upper, moves: [incline, pullup,
                move("bent-row", "Bent-over row", "BJ0Hz5L", "dumbbell bent over row"), lateral, curl, extensionMove]),
            RecommendedRoutine(type: .lower, moves: [goblet,
                move("hip-thrust", "DB hip thrust", nil, nil),
                move("walking-lunge", "DB walking lunges", nil, nil), singleRDL, step, calf])
        ]
    }()
}

struct RecommendedRoutineDraft {
    let templateID: String
    let type: DayType
    var name: String
    var weekdays: [Int]
    var exercises: [CatalogExercise]
}

enum RecommendedRoutineImport {
    /// Reuse an existing provider identity, including a historical snapshot, without name-based merging.
    static func records(_ entries: [CatalogExercise], in backup: Backup) -> [ExerciseRecord] {
        let candidates = backup.exercises + backup.sessions.flatMap { $0.logs.map(\.exercise) }
        var seen: Set<UUID> = []
        return entries.compactMap { entry in
            let record = candidates.first { $0.exerciseDBID == entry.id } ?? entry.record
            return seen.insert(record.id).inserted ? record : nil
        }
    }

    static func adding(_ drafts: [RecommendedRoutineDraft], to backup: Backup) throws -> Backup {
        guard !drafts.isEmpty, Set(drafts.map(\.templateID)).count == drafts.count else {
            throw BackupError.invalid("Choose at least one distinct recommended routine.")
        }
        var result = backup
        for draft in drafts {
            guard !result.days.contains(where: { $0.recommendedTemplateID == draft.templateID }) else {
                throw BackupError.invalid("\(draft.type.title) is already in your routines. Edit or duplicate it from Routines.")
            }
            let records = records(draft.exercises, in: result)
            guard !records.isEmpty, records.count == draft.exercises.count else {
                throw BackupError.invalid("Each routine needs at least one exercise, with no repeated exercises.")
            }
            for record in records where !result.exercises.contains(where: { $0.id == record.id }) { result.exercises.append(record) }
            result.days.append(DayRecord(type: draft.type, exerciseIDs: records.map(\.id), name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
                                         weekdays: draft.weekdays, recommendedTemplateID: draft.templateID))
        }
        result.preferences.routineOrder = result.days.map(\.id)
        return try result.validated()
    }
}

@MainActor @Observable final class RecommendedPreviewModel {
    let templates: [RecommendedRoutine]
    var names: [String: String]
    var excluded: Set<String>
    var replacements: [String: CatalogExercise] = [:]
    var resolved: [String: CatalogExercise] = [:]
    var issues: [String: String] = [:]
    var error: String?
    var loading = false
    var scheduled = true
    var savedMessage: String?
    var createdIDs: [UUID] = []
    init(_ templates: [RecommendedRoutine]) {
        self.templates = templates
        names = Dictionary(uniqueKeysWithValues: templates.map { ($0.id, $0.title) })
        excluded = Set(templates.flatMap { template in template.moves.filter(\.optional).map { Self.key(template, $0) } })
    }
    static func key(_ template: RecommendedRoutine, _ move: RecommendedMove) -> String { template.id + "/" + move.id }
    var count: Int { templates.reduce(0) { count, t in count + t.moves.filter { !excluded.contains(Self.key(t, $0)) }.count } }
    var ready: Bool {
        !loading && error == nil && templates.allSatisfy { template in
            let name = (names[template.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let keys = template.moves.map { Self.key(template, $0) }.filter { !excluded.contains($0) }
            let entries = keys.compactMap { resolved[$0] }
            return !name.isEmpty && name.count <= 60 && !keys.isEmpty && entries.count == keys.count
                && Set(entries.map(\.id)).count == entries.count
        }
    }
    func refresh(catalog: ExerciseCatalog = .shared) async {
        guard !loading else { return }
        loading = true; error = nil
        // Keep visible row geometry stable while awaiting cached/network details.
        // Publish only the newly validated snapshot when the refresh finishes.
        var nextResolved: [String: CatalogExercise] = [:]
        var nextIssues: [String: String] = [:]
        defer { resolved = nextResolved; issues = nextIssues; loading = false }
        do {
            for template in templates {
                for move in template.moves {
                    try Task.checkCancellation()
                    let key = Self.key(template, move)
                    guard !excluded.contains(key) else { continue }
                    guard let id = replacements[key]?.id ?? move.providerID else {
                        nextIssues[key] = "No verified exact match in the library. Choose an exercise or switch off this movement."
                        continue
                    }
                    do {
                        let exercise = try await catalog.detail(id)
                        try Task.checkCancellation()
                        if let replacement = replacements[key] {
                            guard exercise.name == replacement.name && exercise.equipments == replacement.equipments else {
                                throw BackupError.invalid("This listing changed. Choose the exercise again to review it.")
                            }
                        } else { try move.validate(exercise) }
                        nextResolved[key] = exercise
                    } catch let failure as BackupError { nextIssues[key] = failure.localizedDescription }
                    catch CatalogError.missing { nextIssues[key] = "This exercise is unavailable. Choose another or switch off this movement." }
                }
            }
        } catch is CancellationError { error = "Loading paused. Tap Retry to continue." }
        catch { self.error = error.localizedDescription }
    }
    func drafts() -> [RecommendedRoutineDraft] {
        templates.map { template in
            RecommendedRoutineDraft(templateID: template.id, type: template.type, name: names[template.id] ?? template.title,
                                    weekdays: scheduled ? [template.type.weekday] : [], exercises: template.moves.compactMap {
                let key = Self.key(template, $0)
                return excluded.contains(key) ? nil : resolved[key]
            })
        }
    }
}
