import SwiftUI

struct TodayView: View {
    @ScaledMetric(relativeTo: .caption) private var ordinalWidth = 25.0
    @Environment(\.appTheme) private var theme
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var selectedID: UUID?
    @State private var didSelectInitialRoutine = false
    @State private var showingActive = true
    @State private var editingPlan = false
    @State private var creatingRoutine = false
    @State private var browsing: DayRecord?
    @State private var discard = false
    private var selected: DayRecord? { store.days.first { $0.id == selectedID } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if store.active == nil || !showingActive { dayPicker }
                    if let active = store.active, showingActive {
                        WorkoutLineupView(sessionID: active.id)
                        Button("Discard unfinished workout", role: .destructive) { discard = true }.font(.footnote).padding()
                    } else {
                        if let active = store.active {
                            Panel {
                                Label("\(active.title) is in progress", systemImage: "pause.circle.fill").font(.headline)
                                Button("Resume workout") { showingActive = true }.buttonStyle(ActionButtonStyle())
                                Text("Finish or discard it before starting another routine.").font(.caption).foregroundStyle(theme.secondary)
                            }
                        }
                        if let selected { workoutOverview(selected) }
                        else if store.days.isEmpty {
                            Panel {
                                Image(systemName: "dumbbell.fill")
                                    .font(.largeTitle).foregroundStyle(theme.action)
                                Text("Build your first routine").font(.title2.bold())
                                Text("Choose your exercises, give your routine a name, and set the days that work for you.")
                                    .foregroundStyle(theme.secondary)
                                Button("Create routine") { creatingRoutine = true }
                                    .buttonStyle(ActionButtonStyle()).padding(.top, 8)
                            }
                        } else {
                            ContentUnavailableView {
                                Label("A day at your pace", systemImage: "leaf.fill")
                            } description: {
                                Text("Nothing scheduled today. Pick any routine above whenever you want to train.")
                            }.padding(.top, 24)
                        }
                    }
                }.padding()
            }
            .studioScreen().navigationTitle("Gym Log")
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if store.active?.restTimer != nil && showingActive && store.editingSets.isEmpty { WorkoutDock() }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Routines", systemImage: "slider.horizontal.3") { editingPlan = true } }
                ToolbarItem(placement: .topBarLeading) {
                    if store.active != nil && showingActive { Button("Plan") { showingActive = false } }
                }
            }
            .sheet(isPresented: $editingPlan) { PlanEditor() }
            .sheet(isPresented: $creatingRoutine) { RoutineForm(day: DayRecord(type: .push, exerciseIDs: [], name: "", weekdays: [])) }
            .sheet(item: $browsing) { AddExerciseView(dayID: $0.id) }
            .onAppear {
                guard !didSelectInitialRoutine else { return }
                didSelectInitialRoutine = true
                if let active = store.active { selectedID = active.routineID; showingActive = true }
                else if selectedID == nil { selectToday() }
            }
            .onChange(of: store.days) { old, new in
                if let added = new.first(where: { day in !old.contains { $0.id == day.id } }) { selectedID = added.id }
                else if !new.contains(where: { $0.id == selectedID }) { selectToday() }
            }
            .onChange(of: store.active?.id) { _, id in showingActive = id != nil }
            .alert("Discard this workout?", isPresented: $discard) {
                Button("Discard", role: .destructive) { if let active = store.active { store.delete(active.id) } }
                Button("Keep logging", role: .cancel) {}
            } message: { Text("Its sets will be removed. Finished workouts are kept.") }
            .sheet(isPresented: Binding(get: { store.completedSessionID != nil }, set: { if !$0 { store.completedSessionID = nil; store.celebration = nil } })) {
                if let id = store.completedSessionID {
                    NavigationStack {
                        SessionDetail(sessionID: id)
                            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Done") { store.completedSessionID = nil; store.celebration = nil } } }
                    }
                }
            }
        }
    }
    private func selectToday() { selectedID = store.days.first { $0.isScheduled() }?.id }
    private var dayPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(store.days) { day in
                    Button {
                        selectedID = day.id
                        showingActive = store.active?.routineID == day.id
                    } label: {
                        VStack(spacing: 3) {
                            Text(day.scheduleDescription).font(.caption.weight(.medium))
                            Text(day.title).font(.subheadline.bold())
                        }.frame(minWidth: 74, minHeight: 44).padding(.horizontal, 12).padding(.vertical, 4)
                            .foregroundStyle(theme.text)
                            .background(selectedID == day.id ? theme.selected : theme.surface, in: RoundedRectangle(cornerRadius: 12))
                    }.buttonStyle(.plain)
                        .accessibilityLabel("\(day.title), \(day.scheduleDescription)")
                        .accessibilityAddTraits(selectedID == day.id ? .isSelected : [])
                }
                if !store.days.isEmpty {
                    Button { creatingRoutine = true } label: { Label("New", systemImage: "plus").frame(minHeight: 44).padding(.horizontal, 10) }
                        .disabled(store.days.count >= 100)
                }
            }
        }
    }
    private func workoutOverview(_ day: DayRecord) -> some View {
        VStack(spacing: 16) {
            Panel {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(day.title).font(theme.heading)
                        Text("\(day.exerciseIDs.count) exercises · \(day.scheduleDescription)").font(.subheadline).foregroundStyle(theme.secondary)
                    }
                    Spacer()
                    Circle().fill(day.type.color).frame(width: 9, height: 9).padding(.top, 9)
                }
                if day.exerciseIDs.isEmpty {
                    Text("Make this routine yours. Choose exercises from the library to get started.").foregroundStyle(theme.secondary).padding(.top, 12)
                } else {
                    Button { store.start(day); showingActive = true } label: {
                        Text("Start workout")
                    }.buttonStyle(ActionButtonStyle()).padding(.top, 6).disabled(store.active != nil)
                }
                Button { browsing = day } label: {
                    Label(day.exerciseIDs.isEmpty ? "Choose exercises" : "Add exercises", systemImage: "magnifyingglass")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }.buttonStyle(SecondaryButtonStyle())
            }
            if !day.exerciseIDs.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(day.exerciseIDs.enumerated()), id: \.element) { index, id in
                        if let exercise = store.exercises.first(where: { $0.id == id }) {
                            HStack(alignment: .top, spacing: 12) {
                                Text(String(format: "%02d", index + 1)).font(.caption.monospacedDigit()).foregroundStyle(theme.secondary).frame(width: ordinalWidth).padding(.top, 3)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(exercise.name).font(.subheadline.weight(.semibold))
                                    Text(lastTime(exercise.id)).font(.caption).foregroundStyle(theme.secondary)
                                }
                                Spacer(minLength: 0)
                            }.padding(14).frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
                            if index < day.exerciseIDs.count - 1 { Divider().padding(.leading, 51) }
                        }
                    }
                }.background(theme.surface, in: RoundedRectangle(cornerRadius: AppTheme.panelRadius))
                Text("Open Routines to edit targets, supersets or the order for future workouts.").font(.caption).foregroundStyle(theme.secondary)
            }
        }
    }
    private func lastTime(_ id: UUID) -> String {
        guard let log = store.finished.compactMap({ $0.logs.first { $0.id == id && $0.sets.contains(where: \.completed) } }).first else {
            return "First session · Set your starting weight"
        }
        return "Last time: " + log.sets.filter(\.completed).map { "\(store.unit.text($0.weightKg))×\($0.reps)" }.joined(separator: ", ") + " \(store.unit.rawValue)"
    }
}

struct SessionEditor: View {
    @Environment(\.appTheme) private var theme
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    let sessionID: UUID
    @State private var confirmFinish = false
    @State private var notes = false
    @FocusState private var editing: Bool

    var body: some View {
        if let session = store.session(sessionID) {
            VStack(spacing: 16) {
                if session.watchTracking != nil && !store.isDemo { WatchWorkoutCard(session: session) }
                Panel {
                    Text(session.title).font(theme.heading)
                    Text("\(session.completedSets) of \(session.totalSets) sets · " + session.start.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline).foregroundStyle(theme.secondary)
                    if session.isSample { Text("Sample workout").font(.caption.bold()).foregroundStyle(.orange) }
                }
                Panel {
                    Button(session.notes == nil ? "Add workout notes" : "Edit workout notes", systemImage: "note.text") { notes = true }
                        .frame(minHeight: 44)
                    if let text = session.notes { Text(text).font(.subheadline).foregroundStyle(theme.secondary) }
                }
                ForEach(session.logs) { log in
                    ExerciseCard(sessionID: sessionID, exerciseID: log.id)
                }
                if session.end == nil {
                    Button {
                        editing = false
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        if session.completedSets < session.totalSets { confirmFinish = true }
                        else { store.finish(sessionID) }
                    } label: {
                        Label("Finish workout", systemImage: "checkmark.flag.fill")
                            .font(.headline)
                    }.buttonStyle(ActionButtonStyle()).disabled(session.completedSets == 0)
                    Text("Entries save as you type. Tap Complete for each finished set; only completed sets count toward progress.").font(.caption).foregroundStyle(theme.secondary)
                }
            }
            .sheet(isPresented: $notes) { WorkoutNotesEditor(sessionID: sessionID) }
            .confirmationDialog("Finish with \(session.completedSets) of \(session.totalSets) sets complete?", isPresented: $confirmFinish, titleVisibility: .visible) {
                Button("Save completed sets") { store.finish(sessionID) }
            }
        }
    }
}

struct ExerciseCard: View {
    @Environment(\.appTheme) private var theme
    @Environment(AppStore.self) private var store
    var sessionID: UUID
    var exerciseID: UUID
    private var session: SessionRecord? { store.session(sessionID) }
    @State private var swapping = false
    @State private var guiding = false
    @State private var notes = false
    @State private var calculator = false
    private var log: ExerciseLog? { session?.logs.first { $0.id == exerciseID } }

    var body: some View {
        if let log, let session {
            Panel {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        Text(log.exercise.name).font(.title3.bold())
                        Spacer()
                        Menu {
                            Button("Exercise notes", systemImage: "note.text") { notes = true }
                            if log.exercise.equipment == .barbell {
                                Button("Plate calculator", systemImage: "equal.circle") { calculator = true }
                            }
                            if log.exercise.exerciseDBID != nil {
                                Button("Exercise guide", systemImage: "figure.strengthtraining.traditional") { guiding = true }
                            }
                            if session.end == nil {
                                Button("Swap for this workout", systemImage: "arrow.triangle.2.circlepath") { swapping = true }
                                    .disabled(log.sets.contains(where: \.completed))
                            }
                        } label: { Image(systemName: "ellipsis.circle").font(.title3).frame(width: 44, height: 44) }
                            .accessibilityLabel("Options for \(log.exercise.name)")
                    }
                    HStack(alignment: .top) {
                        Text(log.exercise.muscle.capitalized + (log.exercise.isBodyweight ? " · Added weight only" : ""))
                            .font(.caption).foregroundStyle(theme.secondary)
                        Spacer()
                        Text("\(log.sets.filter(\.completed).count)/\(log.sets.count) sets")
                            .font(.caption.weight(.semibold).monospacedDigit()).foregroundStyle(theme.secondary)
                    }
                    if log.exercise.exerciseDBID != nil {
                        Button("View form guide", systemImage: "figure.strengthtraining.traditional") { guiding = true }
                            .font(.subheadline).frame(minHeight: 44)
                    }
                    if let target = log.target { Text("Target: \(target.text)").font(.subheadline.bold()).foregroundStyle(.teal) }
                    if let partner = session.supersets?.first(where: { $0.contains(log.id) })?.partner(of: log.id),
                       let other = session.logs.first(where: { $0.id == partner }) {
                        Label("Superset with \(other.exercise.name)", systemImage: "link").font(.caption).foregroundStyle(.teal)
                    }
                    if let text = log.notes { Text(text).font(.subheadline).foregroundStyle(theme.secondary) }
                    if let previous = store.finished.filter({ $0.start < session.start }).compactMap({ $0.logs.first { $0.id == exerciseID && $0.sets.contains(where: \.completed) } }).first {
                        Text("Last time: " + previous.sets.filter(\.completed).map { "\(store.unit.text($0.weightKg))×\($0.reps)" }.joined(separator: ", ") + " \(store.unit.rawValue)")
                            .font(.caption).foregroundStyle(theme.secondary)
                        if let note = previous.notes { Text("Previous note: \(note)").font(.caption).foregroundStyle(theme.secondary) }
                    }
                    ForEach(Array(log.sets.enumerated()), id: \.element.id) { index, set in
                        SetRow(number: index + 1, value: set, unit: store.unit, color: session.dayType.color) { updated in
                            store.updateSet(sessionID: sessionID, exerciseID: exerciseID, set: updated)
                        } remove: {
                            mutate { $0.sets.removeAll { $0.id == set.id } }
                        }
                    }
                    Button {
                        mutate { log in
                            let last = log.sets.last
                            log.sets.append(LoggedSet(weightKg: last?.weightKg ?? 0, reps: last?.reps ?? 10))
                        }
                    } label: { Label("Add another set", systemImage: "plus.circle").frame(maxWidth: .infinity, minHeight: 44) }
                        .disabled(log.sets.count >= 100)
                }
            }
            .sheet(isPresented: $notes) { WorkoutNotesEditor(sessionID: sessionID, exerciseID: exerciseID) }
            .sheet(isPresented: $calculator) { PlateCalculatorView(unit: store.unit, targetWeight: log.sets.first.map { store.unit.display($0.weightKg) }) }
            .sheet(isPresented: $swapping) { SwapExerciseView(sessionID: sessionID, exerciseID: exerciseID) }
            .sheet(isPresented: $guiding) {
                ExerciseGuideView(exercise: log.exercise)
            }
        }
    }
    private func mutate(_ action: (inout ExerciseLog) -> Void) {
        guard var value = session, let index = value.logs.firstIndex(where: { $0.id == exerciseID }) else { return }
        action(&value.logs[index])
        _ = store.updateSession(value)
    }
}

struct SetRow: View {
    @Environment(\.appTheme) private var theme
    var number: Int
    var value: LoggedSet
    var unit: WeightUnit
    var color: Color
    var update: (LoggedSet) -> Void
    var remove: () -> Void
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var weightText = ""
    @State private var repsText = ""
    @State private var deleting = false
    @State private var showingEffort = false
    @FocusState private var focus: Field?
    private enum Field { case weight, reps }
    private var parsedWeight: Double? {
        // Keep the stored precision when accepting quick-fill or editing only reps.
        if weightText == unit.text(value.weightKg) { return value.weightKg }
        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.numberStyle = .decimal
        guard !weightText.isEmpty, let number = formatter.number(from: weightText) else { return nil }
        let result = unit.kilograms(number.doubleValue)
        return result.isFinite && (0...2000).contains(result) ? result : nil
    }
    private var parsedReps: Int? { Int(repsText).flatMap { (1...1000).contains($0) ? $0 : nil } }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Set \(number)").font(.subheadline.bold())
                Spacer()
                if value.completed {
                    Label("Completed", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold)).foregroundStyle(theme.text)
                } else {
                    Text("Ready to log").font(.caption).foregroundStyle(theme.secondary)
                }
                Menu {
                    Button("Remove set", systemImage: "trash", role: .destructive) { deleting = true }
                } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }
                    .accessibilityLabel("More options for set \(number)")
            }
            let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(alignment: .bottom, spacing: 10))
            layout {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Weight · \(unit.rawValue)").font(.caption.weight(.semibold)).foregroundStyle(theme.secondary)
                    TextField("Weight", text: $weightText).keyboardType(.decimalPad).focused($focus, equals: .weight)
                        .font(.title2.weight(.semibold).monospacedDigit())
                        .padding(.horizontal, 10).frame(minHeight: 52)
                        .background(theme.canvas, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(focus == .weight ? theme.action : theme.divider, lineWidth: focus == .weight ? 2 : 0.5))
                        .accessibilityLabel("Set \(number) weight in \(unit.rawValue)")
                        .onChange(of: weightText) { _, _ in saveNumbers() }
                }.frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Reps").font(.caption.weight(.semibold)).foregroundStyle(theme.secondary)
                    TextField("Reps", text: $repsText).keyboardType(.numberPad).focused($focus, equals: .reps)
                        .font(.title2.weight(.semibold).monospacedDigit())
                        .padding(.horizontal, 10).frame(minHeight: 52)
                        .background(theme.canvas, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(focus == .reps ? theme.action : theme.divider, lineWidth: focus == .reps ? 2 : 0.5))
                        .accessibilityLabel("Set \(number) reps")
                        .onChange(of: repsText) { _, _ in saveNumbers() }
                }.frame(maxWidth: .infinity)
                Button {
                    guard let weight = parsedWeight, let reps = parsedReps else { return }
                    var next = value; next.weightKg = weight; next.reps = reps; next.completed.toggle()
                    store.entryDrafts.removeValue(forKey: value.id)
                    update(next); focus = nil
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: value.completed ? "arrow.uturn.backward" : "checkmark").font(.headline)
                        Text(value.completed ? "Undo" : "Complete").font(.caption.weight(.semibold))
                    }.foregroundStyle(parsedWeight == nil || parsedReps == nil ? Color(uiColor: .secondaryLabel) : value.completed ? theme.text : theme.onAction)
                        .frame(width: typeSize.isAccessibilitySize ? nil : 84)
                        .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : nil, minHeight: 52)
                        .background(parsedWeight == nil || parsedReps == nil || value.completed ? Color(uiColor: .tertiarySystemFill) : theme.action, in: RoundedRectangle(cornerRadius: 10))
                }.buttonStyle(.plain).disabled(parsedWeight == nil || parsedReps == nil)
                    .accessibilityLabel("Set \(number), \(value.completed ? "undo completion" : "complete set")")
            }
            if value.completed {
                DisclosureGroup(isExpanded: $showingEffort) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How many more reps could you have done? This is optional; your weight and reps are already entered.")
                            .font(.caption).foregroundStyle(theme.secondary)
                        Picker("Reps left", selection: Binding(get: { value.repsInReserve }, set: { reserve in
                            var next = value; next.repsInReserve = reserve; update(next)
                        })) {
                            Text("Not set · optional").tag(Optional<Int>.none)
                            ForEach(0...10, id: \.self) { Text($0 == 10 ? "10+ left" : "\($0) left").tag(Optional($0)) }
                        }.pickerStyle(.menu).accessibilityLabel("Set \(number) optional reps left")
                    }.padding(.top, 6)
                } label: {
                    Text(value.repsInReserve.map { "Effort · \($0 == 10 ? "10+" : String($0)) reps left" } ?? "Add effort · optional")
                        .font(.caption.weight(.medium)).foregroundStyle(theme.secondary)
                }
            }
            if parsedWeight == nil || parsedReps == nil {
                Text("Enter a valid weight and 1–1,000 reps.").font(.caption).foregroundStyle(theme.error)
            }
        }
        .padding(12)
        .background(value.completed ? theme.selected : theme.canvas, in: RoundedRectangle(cornerRadius: 12))
        .onAppear { reload() }
        .onChange(of: focus) { _, field in
            if field == nil { store.editingSets.remove(value.id) }
            else { store.editingSets.insert(value.id) }
        }
        .onDisappear { store.editingSets.remove(value.id) }
        .onChange(of: unit) { _, _ in reload() }
        .onChange(of: value) { _, _ in if focus == nil { reload() } }
        .toolbar {
            if focus != nil {
                ToolbarItemGroup(placement: .keyboard) {
                    if focus == .weight { Button("Next: reps") { focus = .reps } }
                    else { Button("Back: weight") { focus = .weight } }
                    Spacer()
                    Button("Done") { focus = nil; reload() }
                }
            }
        }
        .confirmationDialog("Remove set \(number)?", isPresented: $deleting, titleVisibility: .visible) {
            Button("Remove set", role: .destructive, action: remove)
        }
    }
    private func reload() {
        if let draft = store.entryDrafts[value.id], draft.applies(to: value, unit: unit) {
            weightText = draft.weight; repsText = draft.reps
        } else {
            weightText = unit.text(value.weightKg); repsText = String(value.reps)
            store.entryDrafts.removeValue(forKey: value.id)
        }
    }
    private func saveNumbers() {
        guard focus != nil else { return }
        var baseline = value
        let valid = parsedWeight != nil && parsedReps != nil
        if let weight = parsedWeight, let reps = parsedReps {
            baseline.weightKg = weight; baseline.reps = reps
            update(baseline)
        }
        store.entryDrafts[value.id] = SetEntryDraft(weight: weightText, reps: repsText, baseline: baseline, unit: unit, isValid: valid)
    }
}
