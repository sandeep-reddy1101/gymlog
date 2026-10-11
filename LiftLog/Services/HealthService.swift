import Foundation
import HealthKit
import Observation

@MainActor @Observable final class HealthService {
    var status = "Connect Apple Health to read Watch workouts and heart trends."
    // This records that a prompt was shown, never that read access was granted.
    var hasRequestedAccess = UserDefaults.standard.bool(forKey: "healthAccessRequested")
    var isBusy = false
    var restingHeartRate: [HealthPoint] = []
    var variability: [HealthPoint] = []
    var lastCheckedAt: Date? = UserDefaults.standard.object(forKey: "healthTrendsCheckedAt") as? Date
    var latestSampleAt: Date? = UserDefaults.standard.object(forKey: "healthLatestSampleAt") as? Date
    private let store = HKHealthStore()
    var enabled: Bool {
        #if HEALTHKIT_ENABLED
        HKHealthStore.isHealthDataAvailable()
        #else
        false
        #endif
    }
    var availabilityMessage: String {
        #if HEALTHKIT_ENABLED
        "Health data is unavailable on this device. Try sample mode to preview charts."
        #else
        "This is the Local Only build. Logging and backups work; live HealthKit requires the Lift Log scheme and a team that can provision HealthKit."
        #endif
    }

    func authorize() async {
        guard !isBusy else { return }
        guard enabled else { status = availabilityMessage; return }
        isBusy = true
        defer { isBusy = false }
        do {
            let types: Set<HKObjectType> = [HKObjectType.workoutType(), HKQuantityType(.heartRate),
                                           HKQuantityType(.activeEnergyBurned), HKQuantityType(.restingHeartRate),
                                           HKQuantityType(.heartRateVariabilitySDNN)]
            try await store.requestAuthorization(toShare: [], read: types)
            hasRequestedAccess = true
            UserDefaults.standard.set(true, forKey: "healthAccessRequested")
            status = "Access request completed. Apple does not disclose whether read access was denied; missing data may mean no samples or no permission."
            try await loadTrends()
        } catch { status = "Could not read Apple Health: \(error.localizedDescription)" }
    }

    func match(_ session: SessionRecord) async throws -> HealthSummary? {
        guard enabled, let end = session.end else { return nil }
        let datePredicate = HKQuery.predicateForSamples(withStart: session.start, end: end, options: [])
        let strength = NSCompoundPredicate(orPredicateWithSubpredicates: [
            HKQuery.predicateForWorkouts(with: .traditionalStrengthTraining),
            HKQuery.predicateForWorkouts(with: .functionalStrengthTraining)
        ])
        let exact = HKQuery.predicateForObjects(withMetadataKey: WatchWorkoutWire.sessionMetadataKey, allowedValues: [session.id.uuidString])
        let predicate = session.watchTracking == nil ? NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, strength]) : exact
        let samples = try await query(HKObjectType.workoutType(), predicate: predicate)
        let workouts = (samples as? [HKWorkout] ?? []).filter {
            // Avoid silently attaching a third-party phone/manual workout.
            session.watchTracking != nil || $0.sourceRevision.productType?.hasPrefix("Watch") == true || $0.device?.model?.localizedCaseInsensitiveContains("watch") == true
        }
        let ranked = workouts.map { workout in
            (workout, WorkoutLogic.overlap(start: session.start, end: end, otherStart: workout.startDate, otherEnd: workout.endDate))
        }.filter { $0.1 > 0 }.sorted { $0.1 > $1.1 }
        guard let workout = session.watchTracking == nil ? ranked.first?.0 : workouts.first else { return nil }
        let time = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate, options: [.strictStartDate, .strictEndDate])
        let source = HKQuery.predicateForObjects(from: workout.sourceRevision.source)
        let heartPredicate = session.watchTracking == nil ? NSCompoundPredicate(andPredicateWithSubpredicates: [time, source]) : HKQuery.predicateForObjects(from: workout)
        let heartSamples = try await query(HKQuantityType(.heartRate), predicate: heartPredicate)
        let heart = (heartSamples as? [HKQuantitySample] ?? []).map {
            HealthPoint(date: $0.startDate, value: $0.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())))
        }
        var calories = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie())
        if calories == nil {
            let associated = HKQuery.predicateForObjects(from: workout)
            let energy = try await query(HKQuantityType(.activeEnergyBurned), predicate: associated)
            let quantities = energy as? [HKQuantitySample] ?? []
            if !quantities.isEmpty { calories = quantities.reduce(0) { $0 + $1.quantity.doubleValue(for: .kilocalorie()) } }
        }
        let heartStats = workout.statistics(for: HKQuantityType(.heartRate))
        let heartUnit = HKUnit.count().unitDivided(by: .minute())
        return HealthSummary(workoutID: workout.uuid, duration: workout.duration,
                             averageHeartRate: heartStats?.averageQuantity()?.doubleValue(for: heartUnit) ?? (heart.isEmpty ? nil : heart.map(\.value).reduce(0,+) / Double(heart.count)),
                             maxHeartRate: heartStats?.maximumQuantity()?.doubleValue(for: heartUnit) ?? heart.map(\.value).max(), calories: calories, heartRate: heart)
    }

    func loadTrends() async throws {
        guard enabled else { return }
        let start = Calendar.current.date(byAdding: .day, value: -28, to: .now)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now, options: .strictStartDate)
        let resting = try await query(HKQuantityType(.restingHeartRate), predicate: predicate)
        let hrv = try await query(HKQuantityType(.heartRateVariabilitySDNN), predicate: predicate)
        restingHeartRate = dailyMeans(resting as? [HKQuantitySample] ?? [], unit: HKUnit.count().unitDivided(by: .minute()))
        variability = dailyMeans(hrv as? [HKQuantitySample] ?? [], unit: HKUnit.secondUnit(with: .milli))
        lastCheckedAt = .now
        latestSampleAt = (resting + hrv).map(\.endDate).max()
        UserDefaults.standard.set(lastCheckedAt, forKey: "healthTrendsCheckedAt")
        UserDefaults.standard.set(latestSampleAt, forKey: "healthLatestSampleAt")
    }
    private func dailyMeans(_ samples: [HKQuantitySample], unit: HKUnit) -> [HealthPoint] {
        let groups = Dictionary(grouping: samples) { Calendar.current.startOfDay(for: $0.startDate) }
        return groups.map { date, values in
            HealthPoint(date: date, value: values.reduce(0) { $0 + $1.quantity.doubleValue(for: unit) } / Double(values.count))
        }.sorted { $0.date < $1.date }
    }
    private func query(_ type: HKSampleType, predicate: NSPredicate) async throws -> [HKSample] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit,
                                      sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, samples, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: samples ?? []) }
            }
            store.execute(query)
        }
    }
    func loadSampleTrends() {
        restingHeartRate = (0..<28).map { day in
            HealthPoint(date: Calendar.current.date(byAdding: .day, value: day - 27, to: .now)!, value: 62 - Double(day % 7))
        }
        variability = restingHeartRate.enumerated().map { index, point in
            HealthPoint(date: point.date, value: 38 + Double((index * 7) % 20))
        }
        status = "Sample health data · Not read from Apple Health."
    }
}
