import Foundation
import HealthKit
import WatchKit
import WatchConnectivity
import Observation

private struct WatchWorkoutArchive: Codable {
    var command: WatchWorkoutCommand
    var report: WatchWorkoutReport
}

@MainActor @Observable final class WatchWorkoutManager: NSObject {
    static let shared = WatchWorkoutManager()
    var report: WatchWorkoutReport?
    var routineName = "Gym Log"
    var status = "Start your routine in Gym Log on your iPhone."
    var authorizing = false
    private let healthStore = HKHealthStore()
    private var workout: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var command: WatchWorkoutCommand?
    private var completed: [String: WatchWorkoutReport] = [:]
    private var retired: Set<String> = []
    private var isPreparing = false
    private var isFinishing = false
    private var recovered = false
    private var recovering = false
    private var launchRequested = false
    private var lastSent = Date.distantPast
    private let archiveKey = "gymLog.watch.active.v1"
    private let completedKey = "gymLog.watch.completed.v1"
    private let retiredKey = "gymLog.watch.retired.v1"

    var enabled: Bool {
        #if HEALTHKIT_ENABLED
        HKHealthStore.isHealthDataAvailable()
        #else
        false
        #endif
    }

    override init() {
        super.init()
        if let data = UserDefaults.standard.data(forKey: archiveKey), let saved = try? JSONDecoder().decode(WatchWorkoutArchive.self, from: data) {
            command = saved.command; report = saved.report; routineName = saved.command.routineName
        }
        if let data = UserDefaults.standard.data(forKey: completedKey) {
            completed = (try? JSONDecoder().decode([String: WatchWorkoutReport].self, from: data)) ?? [:]
        }
        retired = Set(UserDefaults.standard.stringArray(forKey: retiredKey) ?? [])
    }

    func prepare() async {
        guard enabled else { status = "Watch recording is disabled in the Local Only build."; return }
        if WCSession.default.delegate == nil { WCSession.default.delegate = self; WCSession.default.activate() }
        guard !recovered, !recovering else { return }
        recovering = true
        // Also covers an ordinary relaunch during a workout, not just the system recovery callback.
        healthStore.recoverActiveWorkoutSession { [weak self] session, error in
            Task { @MainActor in
                guard let self else { return }
                self.recovering = false; self.recovered = true
                if let session, self.command != nil, self.report != nil {
                    self.attach(session)
                    if session.state == .ended || session.state == .stopped {
                        await self.finish(discard: self.command?.action == .discard)
                    } else {
                        self.report?.phase = session.state == .paused ? .paused : .recording
                        self.publish(force: true)
                        session.startMirroringToCompanionDevice { _, _ in }
                        self.requestCommand(for: self.command?.sessionID)
                    }
                } else if let session {
                    // No durable identity means we must not attach readings to an unrelated routine.
                    session.end()
                    self.status = "Recovered a recording without its routine. It has been stopped. Start again on your iPhone."
                } else if self.report?.phase.isTerminal == false {
                    await self.recoverSavedOrFail()
                }
                await self.receivePayload(WCSession.default.receivedApplicationContext)
                if self.launchRequested { self.requestCommand() }
            }
        }
    }

    func launchedForWorkout() {
        guard enabled else { return }
        launchRequested = true
        Task {
            await prepare()
            if recovered { requestCommand() }
        }
    }

    func authorize() async -> Bool {
        guard enabled, !authorizing else { return false }
        authorizing = true
        defer { authorizing = false }
        do {
            let workoutType = HKObjectType.workoutType()
            let heart = HKQuantityType(.heartRate)
            let energy = HKQuantityType(.activeEnergyBurned)
            try await healthStore.requestAuthorization(toShare: [workoutType, energy, heart], read: [workoutType, heart, energy])
            guard healthStore.authorizationStatus(for: workoutType) == .sharingAuthorized else {
                status = "Allow Gym Log to save workouts in Health permissions, then try a new routine."
                return false
            }
            status = "Ready. Start your routine on your iPhone."
            return true
        } catch {
            status = "Health setup couldn’t finish: \(error.localizedDescription)"
            return false
        }
    }

    private func receive(_ incoming: WatchWorkoutCommand, allowStart: Bool) async {
        guard enabled, incoming.routineName.count <= 60, incoming.issuedAt.timeIntervalSince1970.isFinite else { return }
        if let old = completed[incoming.sessionID.uuidString] { send(old, durable: false); return }
        if retired.contains(incoming.sessionID.uuidString) { return }
        if incoming.action == .start {
            guard allowStart, incoming.mayStart(at: .now) else { return }
            if command?.sessionID == incoming.sessionID, report?.phase.isTerminal == false {
                publish(force: true); return
            }
            guard workout == nil, !isPreparing, !isFinishing else {
                var failure = WatchWorkoutReport(sessionID: incoming.sessionID)
                failure.phase = .failed; failure.sequence = 1
                failure.message = "Another workout is still recording on your Watch. Finish it before starting a new routine."
                remember(failure); send(failure, durable: true)
                return
            }
            launchRequested = false
            isPreparing = true
            command = incoming; routineName = incoming.routineName
            report = WatchWorkoutReport(sessionID: incoming.sessionID)
            publish(force: true)
            let allowed = await authorize()
            guard command?.action == .start else {
                isPreparing = false
                await finish(discard: command?.action == .discard)
                return
            }
            guard allowed else {
                isPreparing = false
                fail(status)
                return
            }
            do {
                let config = HKWorkoutConfiguration()
                config.activityType = .traditionalStrengthTraining
                config.locationType = .indoor
                let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
                attach(session)
                let start = Date.now
                report?.start = start
                try await builder?.addMetadata([
                    WatchWorkoutWire.sessionMetadataKey: incoming.sessionID.uuidString,
                    HKMetadataKeySyncIdentifier: "GymLog.\(incoming.sessionID.uuidString)",
                    HKMetadataKeySyncVersion: 1
                ])
                // Finishing while authorization or metadata is pending must never start a late recording.
                guard command?.action == .start else {
                    isPreparing = false
                    await finish(discard: command?.action == .discard)
                    return
                }
                session.startActivity(with: start)
                try await builder?.beginCollection(at: start)
                isPreparing = false
                session.startMirroringToCompanionDevice { _, _ in }
                if command?.action != .start { await finish(discard: command?.action == .discard) }
                else { report?.phase = .recording; publish(force: true) }
            } catch {
                isPreparing = false
                fail("Couldn’t start recording: \(error.localizedDescription)")
            }
        } else {
            // Terminal requests are safe to deliver in the background; starts require a fresh phone launch.
            if command?.sessionID == incoming.sessionID {
                if command?.action == .discard { return }
                command = incoming
                persist()
                if !isPreparing { await finish(discard: incoming.action == .discard) }
            } else {
                var cancelled = WatchWorkoutReport(sessionID: incoming.sessionID)
                cancelled.sequence = 1; cancelled.phase = .discarded
                cancelled.message = "Watch recording did not start for this routine."
                remember(cancelled); send(cancelled, durable: true)
            }
        }
    }

    private func attach(_ session: HKWorkoutSession) {
        workout = session
        builder = session.associatedWorkoutBuilder()
        session.delegate = self
        builder?.delegate = self
        builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: session.workoutConfiguration)
    }

    func endFromWatch() {
        guard var current = command, report?.phase.isTerminal == false else { return }
        current.action = .finish; current.end = .now; current.issuedAt = .now
        command = current
        persist()
        Task { await finish(discard: false) }
    }

    private func finish(discard: Bool) async {
        guard !isFinishing, report?.phase.isTerminal == false else { return }
        guard !isPreparing else { return }
        isFinishing = true
        defer { isFinishing = false }
        guard let session = workout, let builder, let start = report?.start, builder.startDate != nil else {
            self.builder?.discardWorkout(); workout?.end()
            report?.phase = .discarded
            report?.message = "Watch recording did not start for this routine."
            workout = nil; self.builder = nil
            publish(force: true)
            return
        }
        // A disconnected Watch cannot stop in the past. Keep the actual measurement interval honest.
        let end = max(start, Date.now)
        let delayedFinish = command?.end.map { end.timeIntervalSince($0) > 15 } ?? false
        report?.end = end
        report?.phase = .ending
        session.stopActivity(with: end)
        publish(force: true)
        do {
            if discard {
                builder.discardWorkout()
                report?.phase = .discarded
                report?.message = "Watch recording discarded."
            } else {
                if builder.endDate == nil { try await builder.endCollection(at: end) }
                readMetrics()
                // Exactly one builder saves the workout. HealthKit's sync identifier is a second duplicate guard.
                let saved = try await builder.finishWorkout()
                report?.workoutID = saved?.uuid
                report?.duration = saved?.duration ?? builder.elapsedTime
                report?.phase = .saved
                report?.message = delayedFinish
                    ? "The finish request was delayed. Measurements include recording until your Watch stopped."
                    : saved == nil ? "Saved to Health. Unlock your Watch to make the saved workout available." : nil
            }
            publish(force: true)
            session.end()
            workout = nil; self.builder = nil
        } catch {
            fail("Recording stopped, but saving to Health failed: \(error.localizedDescription)")
        }
    }

    private func fail(_ message: String) {
        workout?.end()
        builder?.discardWorkout()
        workout = nil; builder = nil
        report?.phase = .failed; report?.message = String(message.prefix(2000)); report?.end = .now
        status = message
        publish(force: true)
    }

    private func readMetrics() {
        guard let builder else { return }
        report?.duration = builder.elapsedTime
        let heart = builder.statistics(for: HKQuantityType(.heartRate))
        let unit = HKUnit.count().unitDivided(by: .minute())
        report?.averageHeartRate = heart?.averageQuantity()?.doubleValue(for: unit)
        report?.maximumHeartRate = heart?.maximumQuantity()?.doubleValue(for: unit)
        report?.activeCalories = builder.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie())
        if let quantity = heart?.mostRecentQuantity(), let interval = heart?.mostRecentQuantityDateInterval() {
            report?.appendHeartRate(quantity.doubleValue(for: unit), at: interval.end)
        }
    }

    private func publish(force: Bool = false) {
        guard report != nil else { return }
        if !force && Date.now.timeIntervalSince(lastSent) < 5 { return }
        lastSent = .now
        report?.sequence += 1; report?.updatedAt = .now
        guard let report, report.isValid else { return }
        persist()
        if report.phase.isTerminal { remember(report) }
        send(report, durable: report.phase.isTerminal)
    }

    private func persist() {
        if let command, let report, let data = WatchWorkoutWire.encode(WatchWorkoutArchive(command: command, report: report)) {
            UserDefaults.standard.set(data, forKey: archiveKey)
        }
    }

    private func remember(_ result: WatchWorkoutReport) {
        completed[result.sessionID.uuidString] = result
        retired.insert(result.sessionID.uuidString)
        // Keep recent summaries for explicit retries; retain lightweight IDs to reject old duplicate starts.
        if completed.count > 30, let oldest = completed.values.min(by: { $0.updatedAt < $1.updatedAt }) {
            completed.removeValue(forKey: oldest.sessionID.uuidString)
        }
        UserDefaults.standard.set(WatchWorkoutWire.encode(completed), forKey: completedKey)
        UserDefaults.standard.set(Array(retired), forKey: retiredKey)
    }

    private func send(_ result: WatchWorkoutReport, durable: Bool) {
        guard let data = WatchWorkoutWire.encode(result) else { return }
        let payload: [String: Any] = [WatchWorkoutWire.reportKey: data]
        if let workout, !result.phase.isTerminal { workout.sendToRemoteWorkoutSession(data: data) { _, _ in } }
        let connection = WCSession.default
        if connection.activationState == .activated {
            try? connection.updateApplicationContext(payload)
            if connection.isReachable { connection.sendMessage(payload, replyHandler: nil, errorHandler: { _ in }) }
            if durable { connection.transferUserInfo(payload) }
        }
    }

    private func requestCommand(for id: UUID? = nil) {
        guard recovered, WCSession.default.activationState == .activated, WCSession.default.isReachable else { return }
        var payload: [String: Any] = ["requestCommand": true]
        if let id { payload["sessionID"] = id.uuidString }
        WCSession.default.sendMessage(payload, replyHandler: { [weak self] reply in
            Task { @MainActor in
                guard let self else { return }
                if let command = WatchWorkoutWire.decode(WatchWorkoutCommand.self, from: reply[WatchWorkoutWire.commandKey]) {
                    await self.receive(command, allowStart: self.launchRequested)
                } else if self.launchRequested {
                    self.status = "No new routine is waiting. Tap Retry Watch connection on your iPhone."
                }
            }
        }, errorHandler: { [weak self] _ in
            Task { @MainActor in self?.status = "Open Gym Log on your iPhone to connect." }
        })
    }

    private func receivePayload(_ payload: [String: Any]) async {
        guard enabled, recovered else { return }
        if let incoming = WatchWorkoutWire.decode(WatchWorkoutCommand.self, from: payload[WatchWorkoutWire.commandKey]) {
            await receive(incoming, allowStart: launchRequested)
        }
        if let items = payload["commands"] as? [Data] {
            for data in items {
                if let incoming = WatchWorkoutWire.decode(WatchWorkoutCommand.self, from: data), incoming.action != .start {
                    await receive(incoming, allowStart: false)
                }
            }
        }
    }

    private func recoverSavedOrFail() async {
        guard let id = command?.sessionID else { return }
        let predicate = HKQuery.predicateForObjects(withMetadataKey: WatchWorkoutWire.sessionMetadataKey, allowedValues: [id.uuidString])
        let saved: HKWorkout? = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: 1, sortDescriptors: nil) { _, samples, _ in
                continuation.resume(returning: samples?.first as? HKWorkout)
            }
            healthStore.execute(query)
        }
        if let saved {
            report?.phase = .saved; report?.workoutID = saved.uuid; report?.end = saved.endDate; report?.duration = saved.duration
            publish(force: true)
        } else {
            // Never create a second workout after an ambiguous save/crash.
            fail("The Watch recording was interrupted. Any already-saved workout can be refreshed from History on your iPhone.")
        }
    }
}

extension WatchWorkoutManager: HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        Task { @MainActor in
            guard workout === workoutSession, report?.phase.isTerminal == false, !isFinishing else { return }
            switch toState {
            case .running: report?.phase = .recording; publish(force: true)
            case .paused: report?.phase = .paused; publish(force: true)
            case .stopped, .ended:
                if command?.action == .start { command?.action = .finish; command?.end = date }
                await finish(discard: command?.action == .discard)
            default: break
            }
        }
    }
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in
            guard workout === workoutSession, report?.phase.isTerminal == false else { return }
            fail("Watch recording stopped: \(error.localizedDescription)")
        }
    }
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didReceiveDataFromRemoteWorkoutSession data: [Data]) {
        Task { @MainActor in for item in data { await receivePayload([WatchWorkoutWire.commandKey: item]) } }
    }
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        Task { @MainActor in
            guard builder === workoutBuilder, report?.phase.isTerminal == false else { return }
            readMetrics(); publish()
        }
    }
}

extension WatchWorkoutManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            if let report { send(report, durable: report.phase.isTerminal) }
            await receivePayload(session.receivedApplicationContext)
            requestCommand(for: launchRequested ? nil : command?.sessionID)
        }
    }
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            if let report { send(report, durable: false) }
            requestCommand(for: launchRequested ? nil : command?.sessionID)
        }
    }
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) { Task { @MainActor in await receivePayload(message) } }
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) { Task { @MainActor in await receivePayload(userInfo) } }
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) { Task { @MainActor in await receivePayload(applicationContext) } }
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        Task { @MainActor in
            let data = report.flatMap { WatchWorkoutWire.encode($0) }
            replyHandler(data.map { [WatchWorkoutWire.reportKey: $0] } ?? [:])
        }
    }
}
