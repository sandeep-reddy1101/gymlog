import SwiftUI

struct WorkoutLineupView: View {
    @ScaledMetric(relativeTo: .caption) private var ordinalWidth = 25.0
    @Environment(AppStore.self) private var store
    @Environment(\.appTheme) private var theme
    let sessionID: UUID
    @State private var adding = false
    @State private var reordering = false
    @State private var notes = false
    @State private var confirmFinish = false
    @State private var confirmSave = false
    @State private var saved = false

    var body: some View {
        if let session = store.session(sessionID) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.title).font(theme.heading)
                        Text("\(session.completedSets) of \(session.totalSets) sets · Saved as you go")
                            .font(.caption).foregroundStyle(theme.secondary)
                    }
                    Spacer()
                    Menu {
                        Button("Workout notes", systemImage: "note.text") { notes = true }
                        Button("Save lineup to routine", systemImage: "calendar.badge.checkmark") { confirmSave = true }
                            .disabled(!store.days.contains { $0.id == session.routineID })
                    } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }.accessibilityLabel("Workout options")
                }
                ProgressView(value: Double(session.completedSets), total: Double(max(1, session.totalSets))).tint(theme.action)
                if session.watchTracking != nil && !store.isDemo { WatchWorkoutCard(session: session) }
                if let note = session.notes { Text(note).font(.subheadline).foregroundStyle(theme.secondary) }
                HStack {
                    Text("Your lineup · \(session.logs.count)").font(.headline)
                    Spacer()
                    Button("Reorder", systemImage: "arrow.up.arrow.down") { reordering = true }.font(.subheadline).frame(minHeight: 44)
                }
                Text("Choose any exercise. Train in your own order.").font(.caption).foregroundStyle(theme.secondary)
                VStack(spacing: 0) {
                    ForEach(Array(session.logs.enumerated()), id: \.element.id) { index, log in
                        NavigationLink {
                            WorkoutExerciseView(sessionID: sessionID, exerciseID: log.id)
                        } label: {
                            HStack(spacing: 12) {
                                Text(String(format: "%02d", index + 1)).font(.caption.monospacedDigit()).foregroundStyle(theme.secondary).frame(width: ordinalWidth)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(log.exercise.name).font(.subheadline.weight(.semibold)).foregroundStyle(theme.text)
                                    Text("\(log.sets.filter(\.completed).count)/\(log.sets.count) sets · \(log.exercise.equipmentLabel)")
                                        .font(.caption).foregroundStyle(theme.secondary)
                                    if let partner = session.supersets?.first(where: { $0.contains(log.id) })?.partner(of: log.id),
                                       let other = session.logs.first(where: { $0.id == partner }) {
                                        Label("Paired with \(other.exercise.name)", systemImage: "link").font(.caption).foregroundStyle(theme.secondary)
                                    }
                                }
                                Spacer(minLength: 4)
                                Image(systemName: !log.sets.isEmpty && log.sets.allSatisfy(\.completed) ? "checkmark.circle.fill" : "chevron.right")
                                    .foregroundStyle(theme.action)
                            }.padding(.horizontal, 14).padding(.vertical, 12).frame(minHeight: 64)
                                .contentShape(Rectangle())
                        }.buttonStyle(.plain)
                        if index < session.logs.count - 1 { Divider().padding(.leading, 51) }
                    }
                }.background(theme.surface, in: RoundedRectangle(cornerRadius: AppTheme.panelRadius))
                Button("Add exercises", systemImage: "plus") { adding = true }
                    .frame(maxWidth: .infinity, minHeight: 44).buttonStyle(SecondaryButtonStyle()).disabled(session.logs.count >= 100)
                Button {
                    if session.completedSets < session.totalSets { confirmFinish = true }
                    else { store.finish(sessionID) }
                } label: { Label("Finish workout", systemImage: "checkmark.flag") }
                    .buttonStyle(ActionButtonStyle()).disabled(session.completedSets == 0)
                Text("Only completed sets count toward progress.").font(.caption).foregroundStyle(theme.secondary)
            }
            .sheet(isPresented: $adding) { AddExerciseView(sessionID: sessionID) }
            .sheet(isPresented: $reordering) { LineupOrderView(sessionID: sessionID) }
            .sheet(isPresented: $notes) { WorkoutNotesEditor(sessionID: sessionID) }
            .confirmationDialog("Finish with \(session.completedSets) of \(session.totalSets) sets complete?", isPresented: $confirmFinish, titleVisibility: .visible) {
                Button("Save completed sets") { store.finish(sessionID) }
            }
            .confirmationDialog("Use this lineup for future workouts?", isPresented: $confirmSave, titleVisibility: .visible) {
                Button("Save lineup to routine") { saved = store.saveLineup(sessionID) }
            } message: { Text("Updates the original routine’s exercise order and pairings, including exercises added or swapped today. Its name and schedule stay the same.") }
            .alert("Routine updated", isPresented: $saved) { Button("OK", role: .cancel) {} }
        }
    }
}

struct WorkoutExerciseView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    let sessionID: UUID
    let exerciseID: UUID
    private var session: SessionRecord? { store.session(sessionID) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let session, let index = session.logs.firstIndex(where: { $0.id == exerciseID }) {
                    HStack {
                        Button("All \(session.logs.count) exercises", systemImage: "list.bullet") { dismiss() }.frame(minHeight: 44)
                        Spacer()
                        Text("\(index + 1) of \(session.logs.count)").font(.caption.monospacedDigit()).foregroundStyle(theme.secondary)
                    }
                    ExerciseCard(sessionID: sessionID, exerciseID: exerciseID)
                    Text("Enter weight and reps, then tap Complete. You choose what comes next.").font(.caption).foregroundStyle(theme.secondary)
                    Button("Choose another exercise", systemImage: "list.bullet") { dismiss() }.frame(maxWidth: .infinity, minHeight: 44).buttonStyle(SecondaryButtonStyle())
                } else {
                    ContentUnavailableView("Lineup updated", systemImage: "list.bullet", description: Text("Return to your workout to choose an exercise."))
                    Button("All exercises") { dismiss() }.buttonStyle(ActionButtonStyle())
                }
            }.padding()
        }.studioScreen().navigationTitle("Log exercise")
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if session?.end == nil && store.active?.id == sessionID && store.editingSets.isEmpty {
                    WorkoutDock(exerciseID: exerciseID)
                }
            }
            .onChange(of: session?.end) { _, end in if end != nil { dismiss() } }
    }
}

struct LineupOrderView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    let sessionID: UUID
    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let session = store.session(sessionID) {
                        ForEach(Array(session.logs.enumerated()), id: \.element.id) { index, log in
                            HStack {
                                Text(log.exercise.name).font(.subheadline)
                                Spacer()
                                Menu {
                                    Button("Move up") { move(log.id, by: -1) }.disabled(index == 0)
                                    Button("Move down") { move(log.id, by: 1) }.disabled(index == session.logs.count - 1)
                                } label: { Image(systemName: "arrow.up.arrow.down").frame(width: 44, height: 44) }
                                    .accessibilityLabel("Move \(log.exercise.name)")
                            }.listRowBackground(theme.surface)
                                .accessibilityAction(named: "Move up") { move(log.id, by: -1) }
                                .accessibilityAction(named: "Move down") { move(log.id, by: 1) }
                        }.onMove { offsets, destination in
                            var ids = session.logs.map(\.id)
                            ids.move(fromOffsets: offsets, toOffset: destination)
                            store.reorderLineup(sessionID, exerciseIDs: ids)
                        }
                    }
                } footer: { Text("Drag the handles or use the arrow menu. Changes save to this workout only. Your sets, notes and supersets stay with each exercise.") }
            }.environment(\.editMode, .constant(.active))
                .studioScreen().navigationTitle("Reorder lineup")
                .toolbar { Button("Done") { dismiss() } }
        }
    }
    private func move(_ id: UUID, by offset: Int) {
        guard let session = store.session(sessionID), let index = session.logs.firstIndex(where: { $0.id == id }), session.logs.indices.contains(index + offset) else { return }
        var ids = session.logs.map(\.id)
        ids.swapAt(index, index + offset)
        store.reorderLineup(sessionID, exerciseIDs: ids)
    }
}
