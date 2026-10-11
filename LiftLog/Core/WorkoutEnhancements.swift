import Foundation

struct RestTimerState: Codable, Equatable {
    var setID: UUID
    var exerciseName: String
    var deadline: Date?
    var pausedRemaining: TimeInterval?

    init(setID: UUID, exerciseName: String, seconds: Int, now: Date = .now) {
        self.setID = setID
        self.exerciseName = exerciseName
        deadline = now.addingTimeInterval(Double(seconds))
    }
    func remaining(at now: Date) -> TimeInterval {
        max(0, pausedRemaining ?? deadline?.timeIntervalSince(now) ?? 0)
    }
    mutating func togglePause(at now: Date) {
        if let pausedRemaining {
            deadline = now.addingTimeInterval(pausedRemaining)
            self.pausedRemaining = nil
        } else {
            pausedRemaining = remaining(at: now)
            deadline = nil
        }
    }
    mutating func extend(at now: Date, seconds: TimeInterval = 30) {
        let updated = min(3600, remaining(at: now) + seconds)
        if pausedRemaining != nil { pausedRemaining = updated }
        else { deadline = now.addingTimeInterval(updated) }
    }
}

enum HealthCheckOutcome: String, Codable { case matched, noMatch, failed }
struct HealthCheck: Codable, Equatable {
    var attemptedAt: Date
    var outcome: HealthCheckOutcome
    var lastMatchedAt: Date?
}

struct ExercisePerformance: Identifiable {
    var id: UUID
    var date: Date
    var maxWeight: Double
    var bestReps: Int
    var score: Double
    var sets: [LoggedSet]
}

extension WorkoutLogic {
    static func receivingHealth(_ summary: HealthSummary?, in session: SessionRecord, now: Date = .now, failed: Bool = false) -> SessionRecord {
        var updated = session
        if let summary, !failed { updated.health = summary }
        updated.healthCheck = HealthCheck(attemptedAt: now, outcome: failed ? .failed : summary == nil ? .noMatch : .matched,
                                         lastMatchedAt: summary != nil && !failed ? now : session.healthCheck?.lastMatchedAt)
        return updated
    }
    static func duplicate(_ day: DayRecord) -> DayRecord {
        DayRecord(type: day.type, exerciseIDs: day.exerciseIDs,
                  name: String(day.title.prefix(53)) + " (copy)", weekdays: day.scheduledWeekdays,
                  targets: day.targets, supersets: day.supersets)
    }

    static func swapping(_ originalID: UUID, with exercise: ExerciseRecord, in session: SessionRecord,
                         history: [SessionRecord]) throws -> SessionRecord {
        guard session.end == nil,
              let index = session.logs.firstIndex(where: { $0.id == originalID }),
              !session.logs[index].sets.contains(where: \.completed),
              !session.logs.contains(where: { $0.id == exercise.id }) else {
            throw BackupError.invalid("Swap an exercise before completing any of its sets, and choose one not already in this workout.")
        }
        var updated = session
        updated.logs[index] = quickFill(exercise: exercise, sessions: history,
                                       count: max(1, session.logs[index].sets.count), before: session.start)
        updated.supersets = session.supersets?.map { pair in
            var pair = pair
            if pair.first == originalID { pair.first = exercise.id }
            if pair.second == originalID { pair.second = exercise.id }
            return pair
        }
        return updated
    }

    static func performances(for id: UUID, in sessions: [SessionRecord]) -> [ExercisePerformance] {
        sessions.filter { $0.end != nil }.sorted { $0.start < $1.start }.compactMap { session in
            guard let log = session.logs.first(where: { $0.id == id }) else { return nil }
            let sets = log.sets.filter(\.completed)
            guard !sets.isEmpty else { return nil }
            return ExercisePerformance(id: session.id, date: session.start, maxWeight: sets.map(\.weightKg).max() ?? 0,
                                       bestReps: sets.map(\.reps).max() ?? 0, score: log.score, sets: sets)
        }
    }

    static func weeklyCounts(_ sessions: [SessionRecord], now: Date = .now) -> [HealthPoint] {
        weeklyVolumes([], now: now).map { bucket in
            let end = calendar.date(byAdding: .weekOfYear, value: 1, to: bucket.date)!
            return HealthPoint(date: bucket.date, value: Double(sessions.filter {
                $0.end != nil && $0.completedSets > 0 && $0.start >= bucket.date && $0.start < end && $0.start <= now
            }.count))
        }
    }

    // An unfinished current week doesn't break the sequence of completed goal weeks.
    static func goalStreak(_ sessions: [SessionRecord], goal: Int, now: Date = .now) -> Int {
        let valid = sessions.filter { $0.end != nil && $0.completedSets > 0 && $0.start <= now }
        let buckets = Dictionary(grouping: valid) { calendar.dateInterval(of: .weekOfYear, for: $0.start)!.start }
        var week = calendar.dateInterval(of: .weekOfYear, for: now)!.start
        if (buckets[week]?.count ?? 0) < goal { week = calendar.date(byAdding: .weekOfYear, value: -1, to: week)! }
        var result = 0
        while (buckets[week]?.count ?? 0) >= max(1, goal) {
            result += 1
            week = calendar.date(byAdding: .weekOfYear, value: -1, to: week)!
        }
        return result
    }
}
