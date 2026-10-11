import Foundation

enum WeightUnit: String, Codable, CaseIterable, Identifiable {
    case lb, kg
    var id: String { rawValue }
    func display(_ kilograms: Double) -> Double { self == .lb ? kilograms * 2.2046226218 : kilograms }
    func kilograms(_ value: Double) -> Double { self == .lb ? value / 2.2046226218 : value }
    func text(_ kilograms: Double) -> String {
        display(kilograms).formatted(.number.precision(.fractionLength(0...1)))
    }
}

enum DayType: String, Codable, CaseIterable, Identifiable {
    case push, pull, legs, upper, lower
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var weekday: Int { switch self { case .push: 2; case .pull: 3; case .legs: 4; case .upper: 6; case .lower: 7 } }
    var shortDay: String { switch self { case .push: "Mon"; case .pull: "Tue"; case .legs: "Wed"; case .upper: "Fri"; case .lower: "Sat" } }
    var colorName: String { switch self { case .push: "Coral"; case .pull: "Blue"; case .legs: "Green"; case .upper: "Purple"; case .lower: "Amber" } }
    var hex: UInt32 { switch self { case .push: 0xFF4D6D; case .pull: 0x3B82F6; case .legs: 0x22C55E; case .upper: 0xA855F7; case .lower: 0xF59E0B } }
    static func today(_ date: Date = .now, calendar: Calendar = .current) -> DayType? {
        allCases.first { $0.weekday == calendar.component(.weekday, from: date) }
    }
}

struct ExerciseRecord: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var muscle: String
    var isBodyweight: Bool = false
    // Optional metadata keeps original version-1 backups readable.
    var equipment: Equipment? = nil
    var aliases: [String]? = nil
    var catalogKey: String? = nil
    var exerciseDBID: String? = nil
    var equipmentDescription: String? = nil
    var equipmentLabel: String { equipmentDescription ?? equipment?.rawValue ?? "Other" }
}

struct DayRecord: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var type: DayType
    var exerciseIDs: [UUID]
    var name: String? = nil
    var weekdays: [Int]? = nil
    var targets: [RepTarget]? = nil
    var supersets: [SupersetPair]? = nil
    var title: String { name ?? type.title }
    var scheduledWeekdays: [Int] { weekdays ?? [type.weekday] }
    func isScheduled(on date: Date = .now, calendar: Calendar = .current) -> Bool {
        scheduledWeekdays.contains(calendar.component(.weekday, from: date))
    }
    var scheduleDescription: String {
        let ordered = [2, 3, 4, 5, 6, 7, 1].filter { scheduledWeekdays.contains($0) }
        return ordered.isEmpty ? "Any day" : ordered.map { Calendar.current.shortWeekdaySymbols[$0 - 1] }.joined(separator: ", ")
    }
}

struct LoggedSet: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var weightKg: Double = 0
    var reps: Int = 10
    var completed: Bool = false
    var repsInReserve: Int? = nil
    var volume: Double { completed ? weightKg * Double(reps) : 0 }
    var estimatedMax: Double { completed ? weightKg * (1 + Double(reps) / 30) : 0 }
}

// Snapshots preserve historical labels when the plan is edited later.
struct ExerciseLog: Codable, Identifiable, Equatable {
    var id: UUID { exercise.id }
    var exercise: ExerciseRecord
    var sets: [LoggedSet]
    var target: RepRange? = nil
    var notes: String? = nil
    var score: Double {
        exercise.isBodyweight ? Double(sets.filter(\.completed).map(\.reps).max() ?? 0)
            : sets.map(\.estimatedMax).max() ?? 0
    }
}

struct HealthPoint: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var date: Date
    var value: Double
}

struct HealthSummary: Codable, Equatable {
    var workoutID: UUID
    var duration: TimeInterval
    var averageHeartRate: Double?
    var maxHeartRate: Double?
    var calories: Double?
    var heartRate: [HealthPoint]
    var isSample: Bool = false
}

struct SessionRecord: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var dayType: DayType
    var start: Date = .now
    var end: Date?
    var logs: [ExerciseLog]
    var health: HealthSummary?
    var isSample: Bool = false
    var routineID: UUID? = nil
    var routineName: String? = nil
    var restTimer: RestTimerState? = nil
    var healthCheck: HealthCheck? = nil
    var notes: String? = nil
    var supersets: [SupersetPair]? = nil
    var title: String { routineName ?? dayType.title }
    var watchTracking: WatchTracking? = nil
    var completedSets: Int { logs.flatMap(\.sets).filter(\.completed).count }
    var totalSets: Int { logs.flatMap(\.sets).count }
    var volume: Double { logs.flatMap(\.sets).reduce(0) { $0 + $1.volume } }
}

struct Preferences: Codable, Equatable {
    var unit: WeightUnit = .lb
    var defaultSets: Int = 3
    var restSeconds: Int? = nil
    var automaticRest: Bool? = nil
    var weeklyGoal: Int? = nil
    var routineOrder: [UUID]? = nil
    var restAlerts: Bool? = nil
    var automaticWatchTracking: Bool? = nil
    var resolvedRestSeconds: Int { restSeconds ?? 90 }
    var resolvedAutomaticRest: Bool { automaticRest ?? true }
    var resolvedWeeklyGoal: Int { weeklyGoal ?? 3 }
}

struct Backup: Codable, Equatable {
    var version: Int = 2
    var exportedAt: Date = .now
    var exercises: [ExerciseRecord]
    var days: [DayRecord]
    var sessions: [SessionRecord]
    var preferences: Preferences

    func validated() throws -> Backup {
        func require(_ condition: Bool, _ message: String) throws {
            if !condition { throw BackupError.invalid(message) }
        }
        try require(version == 1 || version == 2, "This backup version is not supported.")
        try require((1...10).contains(preferences.defaultSets), "Default sets must be between 1 and 10.")
        try require((15...600).contains(preferences.resolvedRestSeconds), "Rest time must be between 15 and 600 seconds.")
        try require((1...7).contains(preferences.resolvedWeeklyGoal), "Weekly goal must be between 1 and 7 workouts.")
        try require(exercises.count <= 1000 && sessions.count <= 50000, "Backup exceeds supported size.")
        try require(Set(exercises.map(\.id)).count == exercises.count, "Duplicate exercise IDs.")
        try require(Set(days.map(\.id)).count == days.count, "Duplicate day IDs.")
        try require(Set(sessions.map(\.id)).count == sessions.count, "Duplicate session IDs.")
        try require(days.count <= 100, "Too many routines.")
        let ids = Set(exercises.map(\.id))
        for exercise in exercises { try validateExercise(exercise) }
        for day in days {
            try require(!day.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && day.title.count <= 60, "Routine names must be 1–60 characters.")
            try require(Set(day.scheduledWeekdays).count == day.scheduledWeekdays.count && day.scheduledWeekdays.allSatisfy { (1...7).contains($0) }, "Invalid routine schedule.")
            try require(day.exerciseIDs.count <= 100 && Set(day.exerciseIDs).count == day.exerciseIDs.count, "Invalid exercise order.")
            try require(Set(day.exerciseIDs).isSubset(of: ids), "Workout refers to a missing exercise.")
            try require(Set((day.targets ?? []).map(\.exerciseID)).count == (day.targets ?? []).count, "Duplicate rep targets.")
            try require((day.targets ?? []).allSatisfy { day.exerciseIDs.contains($0.exerciseID) && $0.range.isValid }, "Invalid routine rep target.")
            try validatePairs(day.supersets, exerciseIDs: day.exerciseIDs)
        }
        try require(sessions.filter { $0.end == nil }.count <= 1, "Only one unfinished workout is supported.")
        for session in sessions {
            if let tracking = session.watchTracking {
                try require(tracking.requestedAt.timeIntervalSince1970.isFinite, "Invalid Watch request date.")
                if let report = tracking.report {
                    try require(report.sessionID == session.id && report.isValid, "Invalid Watch recording.")
                }
            }
            try require((session.notes?.count ?? 0) <= 4000, "Workout notes exceed 4,000 characters.")
            try validatePairs(session.supersets, exerciseIDs: session.logs.map(\.id))
            if let timer = session.restTimer {
                try require(session.end == nil && session.logs.flatMap(\.sets).contains { $0.id == timer.setID && $0.completed }, "Rest timer needs a completed set in an active workout.")
                try require((timer.deadline != nil) != (timer.pausedRemaining != nil), "Invalid rest timer state.")
                if let remaining = timer.pausedRemaining { try require(remaining.isFinite && (0...3600).contains(remaining), "Invalid remaining rest time.") }
                if let deadline = timer.deadline { try require(deadline.timeIntervalSince1970.isFinite, "Invalid rest deadline.") }
            }
            try require(session.start.timeIntervalSince1970.isFinite, "Invalid workout date.")
            if let end = session.end { try require(end >= session.start, "Workout end precedes its start.") }
            try require(session.logs.count <= 100 && Set(session.logs.map(\.id)).count == session.logs.count, "Duplicate or too many exercise logs.")
            let sets = session.logs.flatMap(\.sets)
            try require(Set(sets.map(\.id)).count == sets.count, "Duplicate set IDs.")
            for log in session.logs {
                try require(log.target?.isValid ?? true, "Invalid exercise rep target.")
                try require((log.notes?.count ?? 0) <= 2000, "Exercise notes exceed 2,000 characters.")
                try validateExercise(log.exercise)
                try require(log.sets.count <= 100, "Too many sets for one exercise.")
                for set in log.sets {
                    try require(set.repsInReserve.map { (0...10).contains($0) } ?? true, "Reps in reserve must be 0–10 or omitted.")
                    try require(set.weightKg.isFinite && (0...2000).contains(set.weightKg) && (0...1000).contains(set.reps), "Invalid weight or rep count.")
                    try require(!set.completed || set.reps > 0, "Completed sets need at least one rep.")
                }
            }
            if let health = session.health {
                try require(health.duration.isFinite && (0...604800).contains(health.duration), "Invalid health duration.")
                for value in [health.averageHeartRate, health.maxHeartRate].compactMap({ $0 }) {
                    try require(value.isFinite && (0...400).contains(value), "Invalid heart-rate summary.")
                }
                if let calories = health.calories {
                    try require(calories.isFinite && (0...100000).contains(calories), "Invalid calorie summary.")
                }
                try require(health.heartRate.count <= 100000, "Too many heart-rate samples.")
                try require(Set(health.heartRate.map(\.id)).count == health.heartRate.count, "Duplicate heart-rate samples.")
                for point in health.heartRate {
                    try require(point.value.isFinite && (0...400).contains(point.value), "Invalid heart-rate sample.")
                }
            }
        }
        var upgraded = self
        upgraded.version = 2
        if let order = preferences.routineOrder {
            let positions = Dictionary(order.enumerated().map { ($0.element, $0.offset) }, uniquingKeysWith: { first, _ in first })
            upgraded.days = days.enumerated().sorted {
                let a = positions[$0.element.id] ?? (order.count + $0.offset)
                let b = positions[$1.element.id] ?? (order.count + $1.offset)
                return a < b
            }.map(\.element)
        }
        return upgraded
    }

    private func validateExercise(_ exercise: ExerciseRecord) throws {
        guard !exercise.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              exercise.name.count <= 200, exercise.muscle.count <= 200,
              (exercise.exerciseDBID?.count ?? 0) <= 100, (exercise.equipmentDescription?.count ?? 0) <= 500 else {
            throw BackupError.invalid("An exercise has an invalid name or muscle group.")
        }
    }
    private func validatePairs(_ pairs: [SupersetPair]?, exerciseIDs: [UUID]) throws {
        let pairs = pairs ?? []
        let members = pairs.flatMap { [$0.first, $0.second] }
        guard pairs.count <= 50, Set(pairs.map(\.id)).count == pairs.count,
              Set(members).count == members.count, Set(members).isSubset(of: Set(exerciseIDs)) else {
            throw BackupError.invalid("Supersets must be distinct pairs of exercises in the routine or workout.")
        }
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(try validated())
    }
    static func decode(_ data: Data) throws -> Backup {
        guard data.count <= 50_000_000 else { throw BackupError.invalid("Backup is larger than 50 MB.") }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Backup.self, from: data).validated()
    }
}

enum BackupError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { switch self { case .invalid(let message): message } }
}
