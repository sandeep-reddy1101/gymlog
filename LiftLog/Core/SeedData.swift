import Foundation

enum SeedData {
    static func plan() -> (exercises: [ExerciseRecord], days: [DayRecord]) {
        ([], [])
    }

    // Historical fixtures only. Sample mode also starts with unassigned routines.
    static func samplePlan() -> (exercises: [ExerciseRecord], days: [DayRecord]) {
        let exercises = ExerciseLibrary.catalog
        let indices: [[Int]] = [[0,1,2,3,4,5], [6,7,8,9,10,11,12], [13,14,15,16,17,18], [0,6,19,3,10,5], [13,20,21,16,17,18]]
        let days = zip(DayType.allCases, indices).map { type, list in
            DayRecord(type: type, exerciseIDs: list.map { exercises[$0].id })
        }
        return (exercises, days)
    }

    static func sampleSessions(exercises: [ExerciseRecord], days: [DayRecord], now: Date = .now) -> [SessionRecord] {
        let cal = WorkoutLogic.calendar
        return (1...56).reversed().compactMap { offset in
            let date = cal.date(byAdding: .day, value: -offset, to: now)!
            guard let type = DayType.today(date), let day = days.first(where: { $0.type == type }) else { return nil }
            let start = cal.date(bySettingHour: 17, minute: 30, second: 0, of: date)!
            let logs = day.exerciseIDs.compactMap { id -> ExerciseLog? in
                guard let exercise = exercises.first(where: { $0.id == id }) else { return nil }
                return ExerciseLog(exercise: exercise, sets: (0..<3).map { index in
                    LoggedSet(weightKg: exercise.isBodyweight ? 0 : WeightUnit.lb.kilograms(25 + Double((56 - offset) / 7) * 2.5), reps: 10 - index + (56 - offset) / 21, completed: true)
                })
            }
            let heart = (0..<40).map { minute in
                HealthPoint(date: start.addingTimeInterval(Double(minute * 60)), value: 100 + Double((minute * 17) % 48))
            }
            let health = HealthSummary(workoutID: UUID(), duration: 2400, averageHeartRate: heart.map(\.value).reduce(0,+) / 40,
                                       maxHeartRate: heart.map(\.value).max(), calories: 225, heartRate: heart, isSample: true)
            return SessionRecord(dayType: type, start: start, end: start.addingTimeInterval(2400), logs: logs, health: health, isSample: true)
        }
    }
}
