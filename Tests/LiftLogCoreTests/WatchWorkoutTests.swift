import Foundation
import XCTest
@testable import LiftLogCore

final class WatchWorkoutTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_790_000_000)
    func session() -> SessionRecord {
        SessionRecord(dayType: .push, start: now, logs: [ExerciseLog(exercise: ExerciseRecord(name: "Press", muscle: "Chest"), sets: [LoggedSet(weightKg: 20, reps: 10, completed: true)])], notes: "Keep my note", watchTracking: WatchTracking(requestedAt: now))
    }
    func testStartExpiresAndEndCannotLaunchARecording() {
        var command = WatchWorkoutCommand(sessionID: UUID(), routineName: "Upper", action: .start, issuedAt: now)
        XCTAssertTrue(command.mayStart(at: now.addingTimeInterval(119)))
        XCTAssertFalse(command.mayStart(at: now.addingTimeInterval(121)))
        XCTAssertFalse(command.mayStart(at: now.addingTimeInterval(-10)))
        command.action = .finish
        XCTAssertFalse(command.mayStart(at: now))
        command.action = .discard
        XCTAssertFalse(command.mayStart(at: now))
    }
    func testRejectsWrongSessionDuplicateAndOutOfOrderReports() throws {
        var current = session()
        var report = WatchWorkoutReport(sessionID: current.id, sequence: 4, phase: .recording, updatedAt: now)
        current = try XCTUnwrap(WorkoutLogic.receivingWatch(report, in: current))
        XCTAssertNil(WorkoutLogic.receivingWatch(report, in: current))
        report.sequence = 3
        XCTAssertNil(WorkoutLogic.receivingWatch(report, in: current))
        report.sequence = 5; report.sessionID = UUID()
        XCTAssertNil(WorkoutLogic.receivingWatch(report, in: current))
    }
    func testSummaryPreservesLoggedSetsFinishTimeAndNotes() throws {
        var current = session(); current.end = now.addingTimeInterval(60)
        let report = WatchWorkoutReport(sessionID: current.id, sequence: 8, phase: .saved, updatedAt: now.addingTimeInterval(70), start: now, end: current.end, duration: 60, averageHeartRate: 110, maximumHeartRate: 140, activeCalories: 9, points: [WatchHeartPoint(date: now, value: 110)], workoutID: UUID())
        let updated = try XCTUnwrap(WorkoutLogic.receivingWatch(report, in: current))
        XCTAssertEqual(updated.logs, current.logs)
        XCTAssertEqual(updated.notes, current.notes)
        XCTAssertEqual(updated.end, current.end)
        XCTAssertEqual(updated.health?.workoutID, report.workoutID)
        XCTAssertEqual(updated.health?.calories, 9)
        var stale = report; stale.sequence += 1; stale.phase = .recording
        XCTAssertNil(WorkoutLogic.receivingWatch(stale, in: updated))
    }
    func testMissingMeasurementsStayNilAndFailureKeepsPriorHealth() throws {
        var current = session()
        let report = WatchWorkoutReport(sessionID: current.id, sequence: 1, phase: .saved, updatedAt: now, duration: 10, workoutID: UUID())
        current = try XCTUnwrap(WorkoutLogic.receivingWatch(report, in: current))
        XCTAssertNil(current.health?.calories)
        XCTAssertNil(current.health?.averageHeartRate)
        XCTAssertEqual(current.health?.heartRate, [])
        var other = session(); other.health = current.health
        let failure = WatchWorkoutReport(sessionID: other.id, sequence: 1, phase: .failed, updatedAt: now, message: "Unavailable")
        XCTAssertEqual(WorkoutLogic.receivingWatch(failure, in: other)?.health, other.health)
    }
    func testSampleModeAndUnrequestedSessionsIgnoreRealReports() {
        var current = session()
        let report = WatchWorkoutReport(sessionID: current.id, sequence: 1, phase: .recording, updatedAt: now)
        current.isSample = true
        XCTAssertNil(WorkoutLogic.receivingWatch(report, in: current))
        current.isSample = false; current.watchTracking = nil
        XCTAssertNil(WorkoutLogic.receivingWatch(report, in: current))
    }
    func testHeartChartIsBoundedAndRejectsDuplicateTimesAndInvalidValues() throws {
        var report = WatchWorkoutReport(sessionID: UUID(), updatedAt: now)
        for index in 0..<10_000 { report.appendHeartRate(100 + Double(index % 20), at: now.addingTimeInterval(Double(index))) }
        XCTAssertLessThanOrEqual(report.points.count, 480)
        XCTAssertEqual(report.heartRate, 119)
        let before = report.points
        report.appendHeartRate(120, at: report.points.last!.date)
        report.appendHeartRate(.nan, at: now.addingTimeInterval(20_000))
        XCTAssertEqual(report.points, before)
        XCTAssertLessThan(try JSONEncoder().encode(report).count, 65_000)
    }
    func testWatchBackupRoundTripAndOriginalBackupCompatibility() throws {
        let exercise = ExerciseRecord(name: "Press", muscle: "Chest")
        let current = session()
        var backup = Backup(exportedAt: now, exercises: [exercise], days: [], sessions: [current], preferences: Preferences())
        backup.preferences.automaticWatchTracking = true
        XCTAssertEqual(try Backup.decode(backup.encoded()), backup)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: backup.encoded()) as? [String: Any])
        var sessions = try XCTUnwrap(json["sessions"] as? [[String: Any]])
        sessions[0].removeValue(forKey: "watchTracking"); json["sessions"] = sessions
        var prefs = try XCTUnwrap(json["preferences"] as? [String: Any])
        prefs.removeValue(forKey: "automaticWatchTracking"); json["preferences"] = prefs
        let original = try Backup.decode(JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(original.sessions[0].watchTracking)
        XCTAssertNil(original.preferences.automaticWatchTracking)
    }
    func testImportedRecordingCannotControlOrReceiveALiveSession() {
        var current = session()
        current.watchTracking?.isImported = true
        let report = WatchWorkoutReport(sessionID: current.id, sequence: 1, phase: .recording, updatedAt: now)
        XCTAssertNil(WorkoutLogic.receivingWatch(report, in: current))
    }
    func testMalformedReportAndMismatchedBackupAreRejected() throws {
        var current = session()
        var report = WatchWorkoutReport(sessionID: current.id, sequence: 1, updatedAt: now, activeCalories: -1)
        XCTAssertNil(WorkoutLogic.receivingWatch(report, in: current))
        report.activeCalories = nil; report.sessionID = UUID()
        current.watchTracking?.report = report
        let backup = Backup(exercises: [], days: [], sessions: [current], preferences: Preferences())
        XCTAssertThrowsError(try backup.validated())
    }
}
