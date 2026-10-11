import SwiftUI

struct WorkoutDock: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    private var next: (ExerciseLog, Int, LoggedSet)? {
        guard let session = store.active else { return nil }
        if let position = WorkoutLogic.nextSet(in: session), let log = session.logs.first(where: { $0.id == position.exerciseID }) {
            return (log, position.index, log.sets[position.index])
        }
        return nil
    }
    var body: some View {
        if let session = store.active {
            VStack(spacing: 10) {
                if let rest = session.restTimer {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let seconds = Int(ceil(rest.remaining(at: context.date)))
                        VStack(spacing: 4) {
                            HStack {
                                Label(seconds == 0 ? "Rest complete" : rest.pausedRemaining == nil ? "Rest" : "Rest paused", systemImage: "timer")
                                    .font(.subheadline.bold())
                                Spacer()
                                Text(String(format: "%d:%02d", seconds / 60, seconds % 60)).font(.title2.bold().monospacedDigit())
                                    .contentTransition(.numericText())
                            }
                            let controls = typeSize.isAccessibilitySize
                                ? AnyLayout(VStackLayout(spacing: 8))
                                : AnyLayout(HStackLayout(spacing: 8))
                            controls {
                                Button(rest.pausedRemaining == nil ? "Pause" : "Resume") {
                                    store.changeRest { $0?.togglePause(at: .now) }
                                }.disabled(seconds == 0).frame(minHeight: 44)
                                Button("+30 sec") { store.changeRest { $0?.extend(at: .now) } }.frame(minHeight: 44)
                                Button(seconds == 0 ? "Dismiss" : "Skip rest") { store.changeRest { $0 = nil } }.frame(minHeight: 44)
                            }.font(.subheadline.weight(.semibold)).buttonStyle(.bordered)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                if let (log, index, set) = next {
                    if let pair = session.supersets?.first(where: { $0.contains(log.id) }),
                       let partner = session.logs.first(where: { $0.id == pair.partner(of: log.id) }) {
                        Text("Superset with \(partner.exercise.name) · Rest after the pair").font(.caption).foregroundStyle(.secondary)
                    }
                    Button {
                        var completed = set
                        completed.completed = true
                        store.updateSet(sessionID: session.id, exerciseID: log.id, set: completed)
                    } label: {
                        VStack(spacing: 3) {
                            Label("Complete set \(index + 1) · \(log.exercise.name)", systemImage: "checkmark.circle.fill").font(.headline)
                            Text("\(store.unit.text(set.weightKg)) \(store.unit.rawValue) × \(set.reps) reps").font(.subheadline.monospacedDigit())
                        }
                    }.buttonStyle(ActionButtonStyle())
                        .disabled(!store.editingSets.isEmpty || set.reps < 1)
                    if !store.editingSets.isEmpty { Text("Tap Done on the keyboard to finish editing.").font(.caption).foregroundStyle(.secondary) }
                } else {
                    Button { store.finish(session.id) } label: {
                        Label("Finish workout", systemImage: "checkmark.flag.fill").font(.headline)
                    }.buttonStyle(ActionButtonStyle()).disabled(session.completedSets == 0 || !store.editingSets.isEmpty)
                }
            }.padding(.horizontal, 18).padding(.vertical, 12).background(.regularMaterial)
                .overlay(alignment: .top) { Divider() }
        }
    }
}

struct SwapExerciseView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var sessionID: UUID
    var exerciseID: UUID
    @State private var selected: ExerciseRecord?
    private var session: SessionRecord? { store.session(sessionID) }
    var body: some View {
        NavigationStack {
            ExerciseCatalogBrowser(unavailable: Set(session?.logs.map(\.id) ?? []), selected: []) { selected = $0 }
                .navigationTitle("Swap exercise").navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("Cancel") { dismiss() } }
                .confirmationDialog("Use \(selected?.name ?? "replacement") for this workout?", isPresented: Binding(get: { selected != nil }, set: { if !$0 { selected = nil } }), titleVisibility: .visible) {
                    Button("Swap for this workout") {
                        if let selected, store.swapExercise(exerciseID, with: selected, sessionID: sessionID) { dismiss() }
                        selected = nil
                    }
                }
        }
    }
}
