import Foundation

// Shared by iPhone, Watch, and the platform-independent tests.
enum WatchWorkoutAction: String, Codable { case start, finish, discard }
enum WatchWorkoutPhase: String, Codable {
    case preparing, recording, paused, ending, saved, discarded, failed
    var isTerminal: Bool { self == .saved || self == .discarded || self == .failed }
}

struct WatchWorkoutCommand: Codable, Equatable {
    var sessionID: UUID
    var routineName: String
    var action: WatchWorkoutAction
    var issuedAt: Date
    var end: Date?

    func mayStart(at now: Date) -> Bool {
        action == .start && (-5...120).contains(now.timeIntervalSince(issuedAt))
    }
}

struct WatchHeartPoint: Codable, Equatable {
    var date: Date
    var value: Double
}

struct WatchWorkoutReport: Codable, Equatable {
    var sessionID: UUID
    var sequence: Int = 0
    var phase: WatchWorkoutPhase = .preparing
    var updatedAt: Date = .now
    var start: Date?
    var end: Date?
    var duration: TimeInterval = 0
    var heartRate: Double?
    var heartRateAt: Date?
    var averageHeartRate: Double?
    var maximumHeartRate: Double?
    var activeCalories: Double?
    var points: [WatchHeartPoint] = []
    var workoutID: UUID?
    var message: String?

    var isValid: Bool {
        sequence >= 0 && updatedAt.timeIntervalSince1970.isFinite && duration.isFinite && (0...604800).contains(duration)
        && [start, end, heartRateAt].compactMap { $0 }.allSatisfy { $0.timeIntervalSince1970.isFinite }
        && (start == nil || end == nil || end! >= start!)
        && [heartRate, averageHeartRate, maximumHeartRate].compactMap { $0 }.allSatisfy { $0.isFinite && (1...400).contains($0) }
        && (activeCalories.map { $0.isFinite && (0...100000).contains($0) } ?? true)
        && points.count <= 480 && points.allSatisfy { $0.date.timeIntervalSince1970.isFinite && $0.value.isFinite && (1...400).contains($0.value) }
        && (message?.count ?? 0) <= 2000
    }

    // A newer transport delivery must never undo a terminal result or change its identity.
    func supersedes(_ previous: WatchWorkoutReport?) -> Bool {
        guard isValid else { return false }
        guard let previous else { return true }
        return sessionID == previous.sessionID && sequence > previous.sequence
            && (!previous.phase.isTerminal || phase == previous.phase)
    }

    mutating func appendHeartRate(_ value: Double, at date: Date) {
        guard value.isFinite, (1...400).contains(value), date > (points.last?.date ?? .distantPast) else { return }
        heartRate = value
        heartRateAt = date
        // Bound transport size. Summary statistics come from HealthKit, not this chart's downsampled points.
        if points.count >= 480 { points = points.enumerated().filter { $0.offset.isMultiple(of: 2) }.map(\.element) }
        points.append(WatchHeartPoint(date: date, value: value))
    }
}

enum WatchWorkoutWire {
    static let commandKey = "gymLogCommand"
    static let reportKey = "gymLogReport"
    static let sessionMetadataKey = "GymLogSessionID"
    static func encode<T: Encodable>(_ value: T) -> Data? { try? JSONEncoder().encode(value) }
    static func decode<T: Decodable>(_ type: T.Type, from value: Any?) -> T? {
        guard let data = value as? Data, data.count <= 65_000 else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

struct WatchTracking: Codable, Equatable {
    var requestedAt: Date
    var report: WatchWorkoutReport?
    var isImported: Bool? = nil
}
