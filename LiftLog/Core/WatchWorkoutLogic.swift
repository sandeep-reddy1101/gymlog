import Foundation

extension WorkoutLogic {
    static func receivingWatch(_ report: WatchWorkoutReport, in session: SessionRecord) -> SessionRecord? {
        guard !session.isSample, report.sessionID == session.id,
              let tracking = session.watchTracking, tracking.isImported != true,
              report.supersedes(tracking.report) else { return nil }
        var updated = session
        updated.watchTracking?.report = report
        if report.phase == .saved, let workoutID = report.workoutID {
            updated.health = HealthSummary(workoutID: workoutID, duration: report.duration,
                averageHeartRate: report.averageHeartRate, maxHeartRate: report.maximumHeartRate,
                calories: report.activeCalories, heartRate: report.points.map { HealthPoint(date: $0.date, value: $0.value) })
        }
        return updated
    }
}
