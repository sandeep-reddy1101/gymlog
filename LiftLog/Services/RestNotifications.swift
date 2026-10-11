import Foundation
import Observation
import UserNotifications

@MainActor @Observable final class RestNotifications {
    var status = "Rest alerts are off. Enable them to be notified outside the app."
    var isRequesting = false
    private let center = UNUserNotificationCenter.current()
    private let identifier = "liftlog.rest.complete"
    private var tail: Task<Void, Never>?

    func requestPermission() async -> Bool {
        guard !isRequesting else { return false }
        isRequesting = true
        defer { isRequesting = false }
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            status = granted ? "Rest alerts enabled. Focus and system notification settings may silence them." : "Notifications are not allowed. You can enable them in iPhone Settings → Notifications → Gym Log."
            return granted
        } catch {
            status = "Could not request notifications: \(error.localizedDescription)"
            return false
        }
    }

    // Serialize system requests so an older async add cannot resurrect a skipped timer.
    func reconcile(timer: RestTimerState?, enabled: Bool) {
        let previous = tail
        tail = Task {
            await previous?.value
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            center.removeDeliveredNotifications(withIdentifiers: [identifier])
            guard enabled else { status = "Rest alerts are off."; return }
            let settings = await center.notificationSettings()
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                status = "Notifications are not allowed. Enable them in iPhone Settings → Notifications → Gym Log."
                return
            }
            status = "Rest alerts enabled. Focus and system notification settings may silence them."
            guard let deadline = timer?.deadline, deadline > .now else { return }
            let content = UNMutableNotificationContent()
            content.title = "Rest complete"
            content.body = "Ready for your next set? Open Gym Log when you’re ready."
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, deadline.timeIntervalSinceNow), repeats: false)
            do { try await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)) }
            catch { status = "Rest alert could not be scheduled: \(error.localizedDescription)" }
        }
    }
}
