import Foundation

enum WorkoutLogic {
    static func quickFill(exercise: ExerciseRecord, sessions: [SessionRecord], count: Int, before: Date = .now) -> ExerciseLog {
        let previous = sessions.filter { $0.end != nil && $0.start < before }
            .sorted { $0.start > $1.start }
            .compactMap { $0.logs.first { $0.id == exercise.id && $0.sets.contains(where: \.completed) } }.first
        let completed = previous?.sets.filter(\.completed) ?? []
        let sets = (0..<max(1, count)).map { index in
            let source = index < completed.count ? completed[index] : completed.last
            return LoggedSet(weightKg: source?.weightKg ?? 0, reps: source?.reps ?? 10)
        }
        return ExerciseLog(exercise: exercise, sets: sets)
    }

    static func records(in session: SessionRecord, history: [SessionRecord]) -> [ExerciseLog] {
        session.logs.filter { log in
            let previous = history.filter { $0.id != session.id && $0.end != nil && $0.start < session.start }
                .flatMap(\.logs).filter { $0.id == log.id && $0.sets.contains(where: \.completed) }
            // The first completed performance is a baseline, not a beaten record.
            return !previous.isEmpty && log.score > (previous.map(\.score).max() ?? 0)
        }
    }

    static var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }

    static func weeklyVolumes(_ sessions: [SessionRecord], now: Date = .now) -> [HealthPoint] {
        let cal = calendar
        let current = cal.dateInterval(of: .weekOfYear, for: now)!.start
        return (-7...0).map { offset in
            let start = cal.date(byAdding: .weekOfYear, value: offset, to: current)!
            let end = cal.date(byAdding: .weekOfYear, value: 1, to: start)!
            return HealthPoint(date: start, value: sessions.filter { $0.end != nil && $0.start >= start && $0.start < end }.reduce(0) { $0 + $1.volume })
        }
    }

    static func overlap(start: Date, end: Date, otherStart: Date, otherEnd: Date) -> TimeInterval {
        max(0, min(end, otherEnd).timeIntervalSince(max(start, otherStart)))
    }
}
