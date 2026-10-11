import SwiftUI
import HealthKit
import WatchKit

final class WatchAppDelegate: NSObject, WKApplicationDelegate {
    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        Task { @MainActor in WatchWorkoutManager.shared.launchedForWorkout() }
    }
    func handleActiveWorkoutRecovery() {
        Task { @MainActor in await WatchWorkoutManager.shared.prepare() }
    }
}

@main struct GymLogWatchApp: App {
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) var delegate
    var body: some Scene {
        WindowGroup { WatchWorkoutView() }
    }
}

struct WatchWorkoutView: View {
    @State private var manager = WatchWorkoutManager.shared
    @State private var confirmEnd = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Label("Gym Log", systemImage: "dumbbell.fill").font(.headline).foregroundStyle(.orange)
                if let report = manager.report, !report.phase.isTerminal {
                    Text(manager.routineName).font(.title3.bold())
                    Text(report.phase == .preparing ? "Preparing…" : report.phase == .ending ? "Saving workout…" : report.phase == .paused ? "Paused" : "Recording").foregroundStyle(.secondary)
                    TimelineView(.periodic(from: .now, by: 1)) { timeline in
                        let fresh = report.heartRateAt.map { timeline.date.timeIntervalSince($0) < 30 } ?? false
                        Text("\(fresh ? report.heartRate.map { String(Int($0.rounded())) } ?? "—" : "—") bpm").font(.title.bold()).foregroundStyle(.pink)
                    }
                    Text("\(report.activeCalories.map { String(Int($0.rounded())) } ?? "—") active kcal · estimate")
                    Text("Finish on your iPhone. If it disconnects, you can stop recording here.").font(.footnote)
                    Button("End recording", role: .destructive) { confirmEnd = true }.disabled(report.phase == .preparing || report.phase == .ending)
                } else {
                    if let report = manager.report {
                        Text(report.phase == .saved ? "Workout saved" : report.phase == .discarded ? "Recording ended" : "Recording unavailable").font(.headline)
                        if let message = report.message { Text(message).font(.footnote) }
                        if report.phase == .saved {
                            Text("\(Int(report.duration / 60)) min · \(report.activeCalories.map { String(Int($0.rounded())) } ?? "—") active kcal")
                        }
                    }
                    Text(manager.status).font(.footnote)
                    Button(manager.authorizing ? "Connecting…" : "Connect Apple Health") { Task { _ = await manager.authorize() } }
                        .disabled(manager.authorizing || !manager.enabled)
                    Text("Allow workouts, heart rate and active energy. Then use Start and Finish in Gym Log on your iPhone.").font(.footnote).foregroundStyle(.secondary)
                }
            }.padding(.horizontal, 4)
        }
        .task { await manager.prepare() }
        .confirmationDialog("End Watch recording?", isPresented: $confirmEnd) {
            Button("End and save", role: .destructive) { manager.endFromWatch() }
        } message: { Text("Your measurements will be saved. Finish logging your sets on your iPhone.") }
    }
}
