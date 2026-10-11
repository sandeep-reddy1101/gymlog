import SwiftUI

struct WorkoutDock: View {
    @Environment(\.appTheme) private var theme
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    var exerciseID: UUID? = nil
    private func invalidDraft(_ set: LoggedSet) -> Bool {
        guard let draft = store.entryDrafts[set.id], draft.applies(to: set, unit: store.unit) else { return false }
        return !draft.isValid
    }
    private var next: (ExerciseLog, Int, LoggedSet)? {
        guard let session = store.active else { return nil }
        if let exerciseID, let log = session.logs.first(where: { $0.id == exerciseID }),
           let index = log.sets.firstIndex(where: { !$0.completed }) {
            return (log, index, log.sets[index])
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
                            }.font(.subheadline.weight(.semibold)).buttonStyle(SecondaryButtonStyle())
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                if let (log, index, set) = next {
                    if let pair = session.supersets?.first(where: { $0.contains(log.id) }),
                       let partner = session.logs.first(where: { $0.id == pair.partner(of: log.id) }) {
                        Text("Superset with \(partner.exercise.name) · Rest after the pair").font(.caption).foregroundStyle(theme.secondary)
                    }
                    Button {
                        var completed = set
                        completed.completed = true
                        store.updateSet(sessionID: session.id, exerciseID: log.id, set: completed)
                    } label: {
                        VStack(spacing: 3) {
                            Label("Complete set \(index + 1)", systemImage: "checkmark.circle.fill").font(.headline)
                            Text("\(store.unit.text(set.weightKg)) \(store.unit.rawValue) × \(set.reps) reps").font(.subheadline.monospacedDigit())
                        }
                    }.buttonStyle(ActionButtonStyle())
                        .disabled(!store.editingSets.isEmpty || set.reps < 1 || invalidDraft(set))
                    if invalidDraft(set) { Text("Finish the weight and reps above before completing this set.").font(.caption).foregroundStyle(theme.secondary) }
                    if !store.editingSets.isEmpty { Text("Tap Done on the keyboard to finish editing.").font(.caption).foregroundStyle(theme.secondary) }
                } else if let exerciseID, session.logs.contains(where: { $0.id == exerciseID }) {
                    Label("Exercise complete · Choose your next exercise above", systemImage: "checkmark.circle")
                        .font(.subheadline).frame(minHeight: 44)
                }
            }.padding(.horizontal, 18).padding(.vertical, 12).background(.regularMaterial)
                .overlay(alignment: .top) { Divider() }
        }
    }
}

struct SwapExerciseView: View {
    @Environment(\.appTheme) private var theme
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var sessionID: UUID
    var exerciseID: UUID
    @State private var selected: ExerciseRecord?
    private var session: SessionRecord? { store.session(sessionID) }
    var body: some View {
        NavigationStack {
            ExerciseCatalogBrowser(unavailable: Set(session?.logs.map(\.id) ?? []), selected: []) { selected = $0 }
                .studioScreen().navigationTitle("Swap exercise").navigationBarTitleDisplayMode(.inline)
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
