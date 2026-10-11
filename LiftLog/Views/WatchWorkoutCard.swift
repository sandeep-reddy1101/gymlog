import SwiftUI
import Charts

struct WatchWorkoutCard: View {
    @Environment(\.appTheme) private var theme
    @Environment(AppStore.self) private var store
    let session: SessionRecord
    var body: some View {
        Panel {
            Label("Apple Watch", systemImage: "applewatch").font(.title3.bold())
            if session.watchTracking?.isImported == true {
                Text("Imported workout · Saved measurements only").font(.subheadline).foregroundStyle(theme.secondary)
            }
            if let report = session.watchTracking?.report {
                Text(session.watchTracking?.isImported == true && !report.phase.isTerminal ? "Recording snapshot" : title(report)).font(.headline)
                if let message = report.message { Text(message).font(.subheadline).foregroundStyle(theme.secondary) }
                if session.end != nil && session.watchTracking?.isImported != true && !report.phase.isTerminal {
                    Text("Your sets are saved. Waiting for your Watch to stop and save the measurements. If it stays disconnected, open Gym Log on the Watch and tap End recording.").font(.subheadline).foregroundStyle(theme.secondary)
                }
                if let start = report.start {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let recent = report.heartRateAt.map { context.date.timeIntervalSince($0) < 30 } ?? false
                        let live = session.end == nil && session.watchTracking?.isImported != true && report.phase == .recording
                        let seconds = live && context.date.timeIntervalSince(report.updatedAt) < 20 ? max(report.duration, context.date.timeIntervalSince(start)) : report.duration
                        Text("\(Int(seconds) / 60):\(String(format: "%02d", Int(seconds) % 60)) · \(number(report.activeCalories)) active kcal (estimated)").font(.headline)
                        if live {
                            Text(recent ? "Heart rate: \(number(report.heartRate)) bpm" : "Waiting for a fresh heart-rate reading…")
                                .foregroundStyle(.pink)
                            if context.date.timeIntervalSince(report.updatedAt) > 20 {
                                Text("Watch updates are delayed. Recording may still be running on your Watch.").font(.caption).foregroundStyle(theme.secondary)
                            }
                        }
                    }
                    Text("Average \(number(report.averageHeartRate)) · Highest \(number(report.maximumHeartRate)) bpm")
                        .font(.subheadline).foregroundStyle(theme.secondary)
                    if !report.points.isEmpty {
                        Chart(Array(report.points.enumerated()), id: \.offset) { _, point in
                            LineMark(x: .value("Time", point.date), y: .value("Heart rate", point.value)).foregroundStyle(.pink)
                        }.frame(height: 130)
                        Text("Chart shows available Watch readings. Average and highest heart rate come from HealthKit.").font(.caption2).foregroundStyle(theme.secondary)
                    }
                    Text("— means no readable measurement. Calories are Apple's estimate.").font(.caption).foregroundStyle(theme.secondary)
                }
                if report.phase == .saved {
                    Label("Saved to Apple Health", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                }
            } else if session.watchTracking?.isImported != true {
                Text(session.end == nil ? (store.watch.lastProblem == nil ? "Connecting to your Watch…" : "Watch recording unavailable") : "Waiting for your Watch to confirm the end").font(.headline)
                Text("Wear and unlock your Watch. Allow Health access in Gym Log on the Watch when asked.").font(.subheadline).foregroundStyle(theme.secondary)
                if let problem = store.watch.lastProblem { Text(problem).font(.subheadline).foregroundStyle(.orange) }
                else { Text(store.watch.connectionMessage).font(.caption).foregroundStyle(theme.secondary) }
            }
            if session.end == nil && session.watchTracking?.isImported != true && session.watchTracking?.report == nil {
                Button("Retry Watch connection") { store.startWatch(session.id) }.frame(minHeight: 44)
            }
            if session.end != nil && session.watchTracking?.report?.phase != .saved {
                Button("Refresh recording status") { store.refreshWatch(session.id) }.frame(minHeight: 44)
            }
            if let health = session.health, session.watchTracking?.report?.phase != .saved {
                Text("Saved Health workout found: \(Int(health.duration / 60)) min · \(number(health.calories)) active kcal").font(.subheadline)
            }
        }
    }
    private func number(_ value: Double?) -> String { value.map { String(Int($0.rounded())) } ?? "—" }
    private func title(_ report: WatchWorkoutReport) -> String {
        switch report.phase {
        case .preparing: "Preparing Watch recording"
        case .recording: session.end == nil ? "Recording on your Watch" : "Finishing Watch recording"
        case .paused: "Watch recording paused"
        case .ending: "Saving measurements…"
        case .saved: "Workout measurements"
        case .discarded: "No saved Watch recording"
        case .failed: "Watch recording needs attention"
        }
    }
}
