import Foundation
import HealthKit
import WatchConnectivity
import Observation

@MainActor @Observable final class WatchWorkoutService: NSObject {
    var connectionMessage = "Enable Apple Watch tracking in Settings after installing Gym Log on your Watch."
    var lastProblem: String?
    var isPaired = false
    var isInstalled = false
    var isReachable = false
    var onReport: ((WatchWorkoutReport) -> Bool)?
    private var enabled = false
    private var commands: [String: WatchWorkoutCommand] = [:]
    private let healthStore = HKHealthStore()
    private var mirroredSession: HKWorkoutSession?
    private var launching: Set<UUID> = []
    private let queueKey = "gymLog.watch.commands.v1"

    var hasUnfinishedDelivery: Bool { commands.values.contains { $0.action != .start } }

    func configure(enabled: Bool) {
        guard enabled, !self.enabled, WCSession.isSupported() else { return }
        self.enabled = true
        if let saved = UserDefaults.standard.data(forKey: queueKey) {
            commands = (try? JSONDecoder().decode([String: WatchWorkoutCommand].self, from: saved)) ?? [:]
        }
        healthStore.workoutSessionMirroringStartHandler = { [weak self] session in
            Task { @MainActor in
                guard let self else { return }
                self.mirroredSession = session
                session.delegate = self
                self.flush()
            }
        }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func begin(sessionID: UUID, title: String) {
        guard enabled else { return }
        if WCSession.default.activationState == .activated, commands[sessionID.uuidString] == nil {
            updateConnection()
            guard isPaired, isInstalled else { lastProblem = connectionMessage; return }
        }
        // Finishing a previous recording has priority over starting another sensor session.
        guard !commands.values.contains(where: { $0.sessionID != sessionID }) else {
            lastProblem = "The previous Watch workout still needs to finish. Open Gym Log on your Watch, then retry tracking here."
            return
        }
        commands[sessionID.uuidString] = WatchWorkoutCommand(sessionID: sessionID, routineName: title, action: .start, issuedAt: .now)
        persist()
        lastProblem = nil
        flush()
        launchWatch(for: sessionID)
    }

    func end(sessionID: UUID, title: String, at date: Date, discard: Bool = false) {
        guard enabled else { return }
        guard commands[sessionID.uuidString] != nil else {
            // No launch was queued (for example, the Watch app was not installed).
            let result = WatchWorkoutReport(sessionID: sessionID, sequence: 1, phase: .discarded,
                message: "Watch recording was not started. Your logged sets are saved.")
            _ = onReport?(result)
            return
        }
        let command = WatchWorkoutCommand(sessionID: sessionID, routineName: title, action: discard ? .discard : .finish, issuedAt: .now, end: date)
        commands[sessionID.uuidString] = command
        persist()
        flush()
        enqueueEnd(command)
    }

    func refresh() {
        guard enabled else { return }
        updateConnection()
        flush()
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(["requestReport": true], replyHandler: { [weak self] payload in
                Task { @MainActor in self?.receive(payload) }
            }, errorHandler: { _ in })
        }
    }

    func reconcile(sessions: [SessionRecord]) {
        guard enabled else { return }
        // Repair a process exit between committing Finish/Discard and sending its command.
        for command in Array(commands.values) {
            if let session = sessions.first(where: { $0.id == command.sessionID }) {
                if session.watchTracking?.report?.phase.isTerminal == true {
                    commands.removeValue(forKey: command.sessionID.uuidString)
                } else if let end = session.end, command.action == .start {
                    self.end(sessionID: session.id, title: session.title, at: end)
                }
            } else if command.action != .discard {
                end(sessionID: command.sessionID, title: command.routineName, at: .now, discard: true)
            }
        }
        persist()
        refresh()
    }

    private func persist() {
        if let data = WatchWorkoutWire.encode(commands) { UserDefaults.standard.set(data, forKey: queueKey) }
    }

    private func updateConnection() {
        let session = WCSession.default
        isPaired = session.isPaired
        isInstalled = session.isWatchAppInstalled
        isReachable = session.isReachable
        connectionMessage = !isPaired ? "Pair an Apple Watch with this iPhone to record heart rate and calories."
            : !isInstalled ? "Install Gym Log using the Watch app on your iPhone, then open it once on your Watch."
            : "Gym Log is installed on your Watch. Wear and unlock it before starting your routine."
    }

    private func launchWatch(for id: UUID) {
        guard enabled, let command = commands[id.uuidString], command.mayStart(at: .now), !launching.contains(id) else { return }
        guard WCSession.default.activationState == .activated else { return }
        updateConnection()
        guard isPaired, isInstalled else { lastProblem = connectionMessage; return }
        launching.insert(id)
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor
        healthStore.startWatchApp(with: configuration) { [weak self] success, error in
            Task { @MainActor in
                guard let self else { return }
                self.launching.remove(id)
                guard self.commands[id.uuidString]?.action == .start else { return }
                if !success {
                    self.lastProblem = "Couldn’t open Gym Log on your Watch. Wear and unlock it, then retry. \(error?.localizedDescription ?? "")"
                }
            }
        }
    }

    private func enqueueEnd(_ command: WatchWorkoutCommand) {
        let session = WCSession.default
        guard session.activationState == .activated, let data = WatchWorkoutWire.encode(command) else { return }
        // A durable end request survives loss of reachability and app relaunch.
        for pending in session.outstandingUserInfoTransfers {
            if let old = WatchWorkoutWire.decode(WatchWorkoutCommand.self, from: pending.userInfo[WatchWorkoutWire.commandKey]), old.sessionID == command.sessionID {
                if old == command { return }
                pending.cancel()
            }
        }
        session.transferUserInfo([WatchWorkoutWire.commandKey: data])
    }

    private func flush() {
        let session = WCSession.default
        guard enabled, session.activationState == .activated else { return }
        let payload = commands.values.compactMap { WatchWorkoutWire.encode($0) }
        try? session.updateApplicationContext(["commands": payload])
        for command in commands.values {
            guard let data = WatchWorkoutWire.encode(command) else { continue }
            if command.action != .start { enqueueEnd(command) }
            if session.isReachable {
                session.sendMessage([WatchWorkoutWire.commandKey: data], replyHandler: nil, errorHandler: { _ in })
            }
            if command.action != .start, let mirror = mirroredSession {
                mirror.sendToRemoteWorkoutSession(data: data) { _, _ in }
            }
        }
    }

    private func receive(_ payload: [String: Any]) {
        guard let report = WatchWorkoutWire.decode(WatchWorkoutReport.self, from: payload[WatchWorkoutWire.reportKey]), report.isValid else { return }
        guard onReport?(report) == true else { return }
        if report.phase.isTerminal {
            commands.removeValue(forKey: report.sessionID.uuidString)
            persist()
            flush()
        }
    }

    private func requestedCommand(for id: String?) -> [String: Any] {
        let command = id.flatMap { commands[$0] } ?? (id == nil ? commands.values.first(where: { $0.mayStart(at: .now) }) : nil)
        guard let command, let data = WatchWorkoutWire.encode(command) else { return [:] }
        return [WatchWorkoutWire.commandKey: data]
    }
}

extension WatchWorkoutService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            updateConnection()
            if let error { lastProblem = error.localizedDescription }
            receive(session.receivedApplicationContext)
            flush()
            for command in commands.values where command.mayStart(at: .now) { launchWatch(for: command.sessionID) }
        }
    }
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) { Task { @MainActor in refresh() } }
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) { Task { @MainActor in refresh() } }
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) { Task { @MainActor in receive(message) } }
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) { Task { @MainActor in receive(userInfo) } }
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) { Task { @MainActor in receive(applicationContext) } }
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        Task { @MainActor in
            if message["requestCommand"] != nil { replyHandler(requestedCommand(for: message["sessionID"] as? String)) }
            else { receive(message); replyHandler([:]) }
        }
    }
}

extension WatchWorkoutService: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {}
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in lastProblem = "Watch connection interrupted. Open Gym Log on your Watch to check recording." }
    }
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didReceiveDataFromRemoteWorkoutSession data: [Data]) {
        Task { @MainActor in for item in data { receive([WatchWorkoutWire.reportKey: item]) } }
    }
}
