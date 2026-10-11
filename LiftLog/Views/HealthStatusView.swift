import SwiftUI

struct HealthConnectionStatus: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(store.isDemo ? "Sample Health data" : store.health.enabled ? "Apple Health" : "Health unavailable in this build",
                  systemImage: "heart.text.clipboard").font(.headline)
            if store.isDemo {
                Text("Preview data only. Run the Lift Log scheme on your iPhone to connect Apple Health.")
            } else if !store.health.enabled {
                Text(store.health.availabilityMessage)
            } else {
                Text(store.health.status)
                if let checked = store.health.lastCheckedAt {
                    Text("Last trends check: \(checked.formatted(date: .abbreviated, time: .shortened))")
                }
                if let sample = store.health.latestSampleAt {
                    Text("Latest readable trend sample: \(sample.formatted(date: .abbreviated, time: .shortened))")
                }
                Text("These times describe what Gym Log could read. Apple Health does not expose your Watch’s last sync time.").font(.caption)
            }
        }.font(.subheadline).foregroundStyle(.secondary)
    }
}

struct WorkoutHealthStatus: View {
    @Environment(AppStore.self) private var store
    var session: SessionRecord
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if !store.health.enabled {
                Text(store.health.availabilityMessage)
            } else if store.matchingSessions.contains(session.id) {
                Label("Checking for a matching Watch workout…", systemImage: "arrow.clockwise")
            } else if let check = session.healthCheck {
                switch check.outcome {
                case .matched: Label("Watch workout matched", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                case .noMatch:
                    Text(session.health == nil ? "No readable match yet" : "No new match · Saved summary kept").font(.headline)
                    Text("Your Watch may still be syncing, read access may be off, or no strength workout overlaps this session.")
                case .failed:
                    Text("Health check couldn’t finish. Try again.").font(.headline)
                    if session.health != nil { Text("Your previously saved summary is kept.") }
                }
                Text("Last check: \(check.attemptedAt.formatted(date: .abbreviated, time: .shortened))").font(.caption)
                if let matched = check.lastMatchedAt {
                    Text("Summary read: \(matched.formatted(date: .abbreviated, time: .shortened))").font(.caption)
                }
            } else {
                Text(session.health == nil ? "Ready to check Apple Health" : "Saved Watch summary available").font(.headline)
                Text("Connect Health and check for an overlapping Watch strength workout.")
            }
        }.font(.subheadline).foregroundStyle(.secondary)
    }
}
