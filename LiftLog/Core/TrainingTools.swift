import Foundation

struct RepRange: Codable, Equatable {
    var lower: Int
    var upper: Int
    var text: String { lower == upper ? "\(lower) reps" : "\(lower)–\(upper) reps" }
    var isValid: Bool { (1...1000).contains(lower) && (lower...1000).contains(upper) }
}
struct RepTarget: Codable, Equatable {
    var exerciseID: UUID
    var range: RepRange
}
struct SupersetPair: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var first: UUID
    var second: UUID
    func contains(_ id: UUID) -> Bool { first == id || second == id }
    func partner(of id: UUID) -> UUID? { first == id ? second : second == id ? first : nil }
}
struct SetPosition: Equatable {
    var exerciseID: UUID
    var setID: UUID
    var index: Int
}

extension WorkoutLogic {
    static func setOrder(in session: SessionRecord) -> [SetPosition] {
        var result: [SetPosition] = []
        var visited: Set<UUID> = []
        for log in session.logs where !visited.contains(log.id) {
            let pair = session.supersets?.first { $0.contains(log.id) }
            let members = pair.map { p in [p.first, p.second].compactMap { id in session.logs.first { $0.id == id } } } ?? [log]
            for index in 0..<(members.map { $0.sets.count }.max() ?? 0) {
                for member in members where member.sets.indices.contains(index) {
                    result.append(SetPosition(exerciseID: member.id, setID: member.sets[index].id, index: index))
                }
            }
            visited.formUnion(members.map(\.id))
        }
        return result
    }
    static func nextSet(in session: SessionRecord) -> SetPosition? {
        let completed = Set(session.logs.flatMap(\.sets).filter(\.completed).map(\.id))
        return setOrder(in: session).first { !completed.contains($0.setID) }
    }
    static func shouldRest(after position: SetPosition, in session: SessionRecord) -> Bool {
        guard session.end == nil, session.completedSets < session.totalSets else { return false }
        guard let pair = session.supersets?.first(where: { $0.contains(position.exerciseID) }),
              let partnerID = pair.partner(of: position.exerciseID),
              let partner = session.logs.first(where: { $0.id == partnerID }),
              partner.sets.indices.contains(position.index) else { return true }
        return partner.sets[position.index].completed
    }
    static func changingSet(_ set: LoggedSet, exerciseID: UUID, in original: SessionRecord,
                            preferences: Preferences, now: Date = .now) -> SessionRecord {
        guard let logIndex = original.logs.firstIndex(where: { $0.id == exerciseID }),
              let index = original.logs[logIndex].sets.firstIndex(where: { $0.id == set.id }) else { return original }
        var session = original
        let newlyCompleted = !session.logs[logIndex].sets[index].completed && set.completed
        session.logs[logIndex].sets[index] = set
        if newlyCompleted && session.end == nil {
            // Moving into the next exercise/round ends the previous rest.
            session.restTimer = nil
            let position = SetPosition(exerciseID: exerciseID, setID: set.id, index: index)
            if preferences.resolvedAutomaticRest && shouldRest(after: position, in: session) {
                session.restTimer = RestTimerState(setID: set.id, exerciseName: session.logs[logIndex].exercise.name,
                                                  seconds: preferences.resolvedRestSeconds, now: now)
            }
        }
        return normalizingRest(in: session)
    }
    static func normalizingRest(in original: SessionRecord) -> SessionRecord {
        var session = original
        guard let timer = session.restTimer else { return session }
        guard let position = setOrder(in: session).first(where: { $0.setID == timer.setID }),
              let log = session.logs.first(where: { $0.id == position.exerciseID }),
              log.sets[position.index].completed, shouldRest(after: position, in: session) else {
            session.restTimer = nil
            return session
        }
        return session
    }
}

struct HistoryFilter {
    var search = ""
    var routineTitle: String?
    var exerciseID: UUID?
    var from: Date?
    var until: Date? // exclusive: use the next day to include the selected end date
    func matches(_ session: SessionRecord) -> Bool {
        guard session.end != nil else { return false }
        if let routineTitle, session.title != routineTitle { return false }
        if let exerciseID, !session.logs.contains(where: { $0.id == exerciseID }) { return false }
        if let from, session.start < from { return false }
        if let until, session.start >= until { return false }
        let haystack = ExerciseLibrary.normalized(([session.title, session.notes ?? ""] + session.logs.flatMap { [$0.exercise.name, $0.notes ?? ""] }).joined(separator: " "))
        return ExerciseLibrary.normalized(search).split(separator: " ").allSatisfy { haystack.contains($0) }
    }
}

// Undo only the affected item; never restore a whole stale database snapshot.
struct WorkoutUndo {
    enum Change {
        case set(sessionID: UUID, exerciseID: UUID, before: LoggedSet, after: LoggedSet, oldRest: RestTimerState?, newRest: RestTimerState?)
        case swap(sessionID: UUID, before: ExerciseLog, after: ExerciseLog, oldPairs: [SupersetPair]?, newPairs: [SupersetPair]?)
        case deletion(SessionRecord)
    }
    var title: String
    var change: Change
    func restoring(in original: Backup) throws -> Backup {
        var data = original
        func conflict() -> BackupError { .invalid("This item changed after that action. Undo is unavailable to protect your newer edits.") }
        switch change {
        case let .set(sessionID, exerciseID, before, after, oldRest, newRest):
            guard let i = data.sessions.firstIndex(where: { $0.id == sessionID }),
                  let j = data.sessions[i].logs.firstIndex(where: { $0.id == exerciseID }),
                  let k = data.sessions[i].logs[j].sets.firstIndex(where: { $0.id == before.id }),
                  data.sessions[i].logs[j].sets[k] == after else { throw conflict() }
            data.sessions[i].logs[j].sets[k] = before
            if data.sessions[i].end == nil && data.sessions[i].restTimer == newRest { data.sessions[i].restTimer = oldRest }
            data.sessions[i] = WorkoutLogic.normalizingRest(in: data.sessions[i])
        case let .swap(sessionID, before, after, oldPairs, newPairs):
            guard let i = data.sessions.firstIndex(where: { $0.id == sessionID }),
                  let j = data.sessions[i].logs.firstIndex(where: { $0.id == after.id }),
                  data.sessions[i].logs[j] == after, data.sessions[i].supersets == newPairs,
                  !data.sessions[i].logs.contains(where: { $0.id == before.id }) else { throw conflict() }
            data.sessions[i].logs[j] = before
            data.sessions[i].supersets = oldPairs
        case let .deletion(session):
            guard !data.sessions.contains(where: { $0.id == session.id }) else { throw conflict() }
            guard session.end != nil || !data.sessions.contains(where: { $0.end == nil }) else {
                throw BackupError.invalid("Finish or discard the current workout before restoring this unfinished one.")
            }
            data.sessions.append(session)
        }
        return try data.validated()
    }
}

struct PlateStock: Equatable, Identifiable {
    var weight: Double
    var pairs: Int
    var id: Double { weight }
}
struct PlateResult: Equatable {
    var perSide: [Double]
    var total: Double
    var shortfall: Double
}
enum PlateCalculator {
    static func standard(_ unit: WeightUnit) -> [PlateStock] {
        (unit == .kg ? [25,20,15,10,5,2.5,1.25,0.5,0.25] : [45,35,25,10,5,2.5,1.25]).map {
            PlateStock(weight: $0, pairs: $0 < 1 ? 0 : 4)
        }
    }
    static func calculate(target: Double, bar: Double, stock: [PlateStock]) throws -> PlateResult {
        guard target.isFinite, bar.isFinite, (0...2000).contains(target), (0...200).contains(bar), target >= bar,
              stock.count <= 20, Set(stock.map(\.weight)).count == stock.count,
              stock.allSatisfy({ $0.weight.isFinite && (0.25...100).contains($0.weight) && abs($0.weight * 4 - ($0.weight * 4).rounded()) < 0.00001 && (0...12).contains($0.pairs) }) else {
            throw BackupError.invalid("Enter a target at least as heavy as the bar (up to 2,000), and a bar from 0 to 200.")
        }
        let plates = stock.sorted { $0.weight > $1.weight }
        let limit = Int(floor((target - bar) * 2 + 0.000001)) // quarter-units per side
        var best = [Int](repeating: 10000, count: limit + 1)
        best[0] = 0
        var choices: [[Int]] = []
        for plate in plates {
            let previous = best
            var used = [Int](repeating: 0, count: limit + 1)
            let step = Int((plate.weight * 4).rounded())
            if plate.pairs > 0 {
                for amount in 0...limit {
                    for count in 1...plate.pairs where count * step <= amount {
                        let candidate = previous[amount - count * step] + count
                        if candidate < best[amount] { best[amount] = candidate; used[amount] = count }
                    }
                }
            }
            choices.append(used)
        }
        let achieved = (0...limit).reversed().first { best[$0] < 10000 } ?? 0
        var amount = achieved
        var result: [Double] = []
        for i in plates.indices.reversed() {
            let count = choices[i][amount]
            result += Array(repeating: plates[i].weight, count: count)
            amount -= count * Int((plates[i].weight * 4).rounded())
        }
        let total = bar + Double(achieved) / 2
        return PlateResult(perSide: result.sorted(by: >), total: total, shortfall: max(0, target - total))
    }
}
