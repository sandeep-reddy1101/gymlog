import SwiftUI
import Charts

struct HistoryView: View {
    @Environment(AppStore.self) private var store
    @State private var pendingDelete: SessionRecord?
    @State private var filter = HistoryFilter()
    @State private var filters = false
    private var matches: [SessionRecord] { store.finished.filter { filter.matches($0) } }
    private var filtering: Bool { !filter.search.isEmpty || filter.routineTitle != nil || filter.exerciseID != nil || filter.from != nil }
    var body: some View {
        NavigationStack {
            List {
                if store.finished.isEmpty {
                    ContentUnavailableView("Your story starts here", systemImage: "clock.arrow.circlepath", description: Text("Finished workouts will appear here."))
                }
                if filtering {
                    Section {
                        Text("\(matches.count) matching workouts").font(.subheadline).foregroundStyle(.secondary)
                        Button("Clear search & filters") { filter = HistoryFilter() }
                    }
                }
                if matches.isEmpty && !store.finished.isEmpty {
                    ContentUnavailableView("No matching workouts", systemImage: "magnifyingglass", description: Text("Try another name, date range, or exercise."))
                }
                ForEach(matches) { session in
                    NavigationLink {
                        SessionDetail(sessionID: session.id)
                    } label: {
                        HStack(spacing: 14) {
                            RoundedRectangle(cornerRadius: 3).fill(session.dayType.color).frame(width: 5)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(session.title + (session.isSample ? " · Sample" : "")).font(.headline)
                                Text(session.start.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                                Text("\(session.completedSets) \(session.completedSets == 1 ? "set" : "sets") · \(store.unit.text(session.volume)) \(store.unit.rawValue) volume")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if !WorkoutLogic.records(in: session, history: store.finished).isEmpty {
                                Image(systemName: "trophy.fill").foregroundStyle(.orange).accessibilityLabel("Personal record")
                            }
                            if session.health != nil { Image(systemName: "heart.fill").foregroundStyle(.pink).accessibilityLabel("Health data attached") }
                        }.padding(.vertical, 6)
                    }.swipeActions { Button("Delete", role: .destructive) { pendingDelete = session } }
                }
            }.navigationTitle("History")
                .searchable(text: $filter.search, prompt: "Routine, exercise, or notes")
                .toolbar { Button("Filters", systemImage: filtering ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle") { filters = true } }
                .sheet(isPresented: $filters) { HistoryFilterSheet(filter: $filter) }
                .alert("Delete workout?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
                    Button("Delete", role: .destructive) { if let pendingDelete { store.delete(pendingDelete.id) }; pendingDelete = nil }
                    Button("Cancel", role: .cancel) { pendingDelete = nil }
                } message: { Text("This removes the local workout and attached summary. Apple Health is never changed.") }
        }
    }
}

struct SessionDetail: View {
    @Environment(AppStore.self) private var store
    let sessionID: UUID
    @State private var editing = false
    @State private var matching = false
    @State private var notes = false
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let session = store.session(sessionID) {
                    if editing {
                        Text("Edits save immediately.").font(.caption).foregroundStyle(.secondary)
                        SessionEditor(sessionID: sessionID)
                    } else {
                        Panel {
                            if store.completedSessionID == session.id, let message = store.celebration {
                                Label(message, systemImage: "checkmark.circle.fill").font(.subheadline).foregroundStyle(.green)
                            }
                            Text(session.title).font(.largeTitle.bold())
                            Text(session.start.formatted(date: .long, time: .shortened)).foregroundStyle(.secondary)
                            Text("\(session.completedSets) \(session.completedSets == 1 ? "set" : "sets") · \(store.unit.text(session.volume)) \(store.unit.rawValue) volume").font(.headline).padding(.top, 6)
                            if let note = session.notes { Text(note).font(.subheadline).foregroundStyle(.secondary).padding(.top, 8) }
                            if session.isSample { Text("SAMPLE WORKOUT").font(.caption.bold()).foregroundStyle(.orange) }
                        }
                        if session.watchTracking != nil && !store.isDemo { WatchWorkoutCard(session: session) }
                        ForEach(session.logs) { log in
                            Panel {
                                Text(log.exercise.name).font(.headline)
                                Text(log.exercise.muscle).font(.caption).foregroundStyle(.secondary)
                                if let target = log.target { Text("Target: \(target.text)").font(.caption).foregroundStyle(.teal) }
                                if let partner = session.supersets?.first(where: { $0.contains(log.id) })?.partner(of: log.id),
                                   let other = session.logs.first(where: { $0.id == partner }) { Label("Superset with \(other.exercise.name)", systemImage: "link").font(.caption).foregroundStyle(.teal) }
                                if let note = log.notes { Text(note).font(.subheadline).foregroundStyle(.secondary) }
                                ForEach(Array(log.sets.enumerated()), id: \.element.id) { index, set in
                                    HStack {
                                        Text("Set \(index + 1)").foregroundStyle(.secondary)
                                        Spacer()
                                        Text("\(store.unit.text(set.weightKg)) \(store.unit.rawValue) × \(set.reps)").monospacedDigit()
                                        Image(systemName: set.completed ? "checkmark.circle.fill" : "circle.dashed").foregroundStyle(set.completed ? session.dayType.color : .secondary)
                                    }.font(.subheadline).padding(.top, 4)
                                    if let reserve = set.repsInReserve {
                                        Text("Set \(index + 1): \(reserve == 10 ? "10+" : String(reserve)) reps left").font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    if let health = session.health, session.watchTracking == nil { HealthSummaryView(summary: health) }
                    if !session.isSample && !store.isDemo && session.watchTracking == nil {
                        Panel {
                            Text("Apple Watch").font(.title3.bold())
                            WorkoutHealthStatus(session: session)
                            Button {
                                matching = true
                                Task {
                                    if !store.health.hasRequestedAccess { await store.health.authorize() }
                                    if store.health.hasRequestedAccess { await store.matchHealth(sessionID) }
                                    matching = false
                                }
                            } label: {
                                Label(matching ? "Checking Health…" : "Match / refresh Watch workout", systemImage: "arrow.clockwise")
                                    .frame(minHeight: 44)
                            }.disabled(matching || store.matchingSessions.contains(sessionID) || !store.health.enabled)
                            Text("For automatic recording on future routines, enable Use Apple Watch for workouts in Settings. This older session can still be matched to an existing Watch workout.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                } else { ContentUnavailableView("Workout removed", systemImage: "trash") }
            }.padding()
        }.background(Color(uiColor: .systemGroupedBackground)).navigationTitle("Workout").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $notes) { WorkoutNotesEditor(sessionID: sessionID) }
            .toolbar {
                Button("Notes", systemImage: "note.text") { notes = true }
                Button(editing ? "Done" : "Edit sets") { editing.toggle() }
            }
    }
}

struct HealthSummaryView: View {
    let summary: HealthSummary
    var body: some View {
        Panel {
            Label(summary.isSample ? "Sample Watch workout" : "Apple Watch workout", systemImage: "heart.fill").font(.title3.bold()).foregroundStyle(.pink)
            Text("\(Int(summary.duration / 60)) min · \(summary.calories.map { String(Int($0.rounded())) } ?? "—") active kcal")
                .font(.headline).padding(.top, 4)
            Text("Average \(summary.averageHeartRate.map { String(Int($0.rounded())) } ?? "—") · Max \(summary.maxHeartRate.map { String(Int($0.rounded())) } ?? "—") bpm")
                .font(.subheadline).foregroundStyle(.secondary)
            if summary.heartRate.isEmpty {
                Text("Heart-rate samples are missing or not shared with Gym Log.").font(.caption).padding(.top, 8)
            } else {
                Chart(summary.heartRate) { point in
                    LineMark(x: .value("Time", point.date), y: .value("bpm", point.value)).foregroundStyle(.pink)
                }.frame(height: 150).padding(.top, 12)
                Text("Heart rate is the sample average across the matched Watch workout.").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}

struct HistoryFilterSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Binding var filter: HistoryFilter
    private var routineNames: [String] { Array(Set(store.finished.map(\.title))).sorted() }
    private var exercises: [ExerciseRecord] {
        var seen: Set<UUID> = []
        return store.finished.flatMap(\.logs).map(\.exercise).filter { seen.insert($0.id).inserted }.sorted { $0.name < $1.name }
    }
    var body: some View {
        NavigationStack {
            Form {
                Picker("Routine name", selection: $filter.routineTitle) {
                    Text("All routines").tag(Optional<String>.none)
                    ForEach(routineNames, id: \.self) { Text($0).tag(Optional($0)) }
                }
                Picker("Exercise", selection: $filter.exerciseID) {
                    Text("All exercises").tag(Optional<UUID>.none)
                    ForEach(exercises) { Text($0.name).tag(Optional($0.id)) }
                }
                Section {
                    Toggle("Filter by date", isOn: Binding(get: { filter.from != nil }, set: { enabled in
                        filter.from = enabled ? Calendar.current.date(byAdding: .day, value: -30, to: Calendar.current.startOfDay(for: .now)) : nil
                        filter.until = enabled ? Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now)) : nil
                    }))
                    if filter.from != nil {
                        DatePicker("From", selection: Binding(get: { filter.from ?? .now }, set: { filter.from = Calendar.current.startOfDay(for: $0) }), displayedComponents: .date)
                        DatePicker("Through", selection: Binding(get: { Calendar.current.date(byAdding: .day, value: -1, to: filter.until ?? .now) ?? .now }, set: { filter.until = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: $0)) }), displayedComponents: .date)
                        if let from = filter.from, let until = filter.until, until <= from {
                            Text("Choose an end date on or after the start date.").foregroundStyle(.red)
                        }
                    }
                } footer: { Text("Dates include both selected days, using the workout’s start date. Routine names are the names saved with each workout.") }
                Button("Clear all filters and search") { filter = HistoryFilter() }
            }.navigationTitle("Filter history").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
