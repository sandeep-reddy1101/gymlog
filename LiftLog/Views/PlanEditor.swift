import SwiftUI

struct PlanEditor: View {
    @Environment(\.appTheme) private var theme
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var creating = false
    @State private var deleting: DayRecord?
    @State private var duplicate: DayRecord?
    var body: some View {
        NavigationStack {
            List {
                if store.days.isEmpty {
                    ContentUnavailableView("Your routine, your choice", systemImage: "calendar.badge.plus",
                                           description: Text("Create a routine, pick its days, then choose your exercises."))
                }
                ForEach(store.days) { day in
                    NavigationLink { RoutineDetail(dayID: day.id) } label: {
                        HStack {
                            Circle().fill(day.type.color).frame(width: 10, height: 10)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(day.title).font(.headline)
                                Text("\(day.scheduleDescription) · \(day.exerciseIDs.count) exercises").font(.caption).foregroundStyle(theme.secondary)
                            }
                        }.padding(.vertical, 5)
                    }.listRowBackground(theme.surface).swipeActions { Button("Delete", role: .destructive) { deleting = day } }
                        .swipeActions(edge: .leading) {
                            Button("Duplicate", systemImage: "plus.square.on.square") { duplicate = WorkoutLogic.duplicate(day) }
                                .tint(.blue).disabled(store.days.count >= 100)
                        }
                }
                .onMove { offsets, target in _ = store.commit { $0.days.move(fromOffsets: offsets, toOffset: target) } }
                NavigationLink { RecommendedRoutineList() } label: {
                    Label("Recommended routines", systemImage: "calendar.badge.plus")
                }.listRowBackground(theme.surface)
                Button("Create routine", systemImage: "plus") { creating = true }.disabled(store.days.count >= 100)
            }.studioScreen().navigationTitle("Your routines")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { Button("Done") { dismiss() } }
                    ToolbarItem(placement: .topBarTrailing) { EditButton() }
                }
                .sheet(item: $duplicate) { RoutineForm(day: $0) }
                .sheet(isPresented: $creating) { RoutineForm(day: DayRecord(type: .push, exerciseIDs: [], name: "", weekdays: [])) }
                .alert("Delete routine?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
                    Button("Delete", role: .destructive) {
                        if let deleting { _ = store.commit { $0.days.removeAll { $0.id == deleting.id } } }
                        deleting = nil
                    }
                    Button("Cancel", role: .cancel) { deleting = nil }
                } message: { Text("Saved workouts and any workout in progress are kept. The exercise library is unchanged.") }
        }
    }
}

struct RoutineDetail: View {
    @Environment(\.appTheme) private var theme
    @Environment(AppStore.self) private var store
    var dayID: UUID
    @State private var adding = false
    @State private var editingRoutine = false
    @State private var editingExercise: ExerciseRecord?
    @State private var duplicate: DayRecord?
    private var day: DayRecord? { store.days.first { $0.id == dayID } }
    var body: some View {
        Group {
            if let day {
                List {
                    Section {
                        LabeledContent("Schedule", value: day.scheduleDescription)
                        Button("Edit name, days & color") { editingRoutine = true }
                        Button("Duplicate routine", systemImage: "plus.square.on.square") { duplicate = WorkoutLogic.duplicate(day) }
                            .disabled(store.days.count >= 100)
                    } footer: { Text("Changes apply to future workouts. Saved sessions keep their original names and sets.") }.listRowBackground(theme.surface)
                    Section {
                        Text("Tap an exercise for rep targets and supersets. Tap Edit to reorder.").font(.caption).foregroundStyle(theme.secondary)
                    }.listRowBackground(theme.surface)
                    Section("Exercises · \(day.exerciseIDs.count)") {
                        if day.exerciseIDs.isEmpty { Text("No exercises assigned yet.").foregroundStyle(theme.secondary) }
                        ForEach(day.exerciseIDs, id: \.self) { id in
                            if let exercise = store.exercises.first(where: { $0.id == id }) {
                                Button { editingExercise = exercise } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(exercise.name).foregroundStyle(.primary)
                                        if let range = day.targets?.first(where: { $0.exerciseID == id })?.range {
                                            Text("Target: \(range.text)").font(.caption).foregroundStyle(theme.secondary)
                                        }
                                        if let partner = day.supersets?.first(where: { $0.contains(id) })?.partner(of: id),
                                           let name = store.exercises.first(where: { $0.id == partner })?.name {
                                            Label("Paired with \(name)", systemImage: "link").font(.caption).foregroundStyle(.teal)
                                        }
                                        Text("\(exercise.muscle) · \(exercise.equipmentLabel)").font(.caption).foregroundStyle(theme.secondary)
                                    }.padding(.vertical, 4)
                                }
                                .accessibilityAction(named: "Move up") { moveExercise(id, by: -1) }
                                .accessibilityAction(named: "Move down") { moveExercise(id, by: 1) }
                            }
                        }
                        .onDelete { offsets in var next = day; next.exerciseIDs.remove(atOffsets: offsets); save(next) }
                        .onMove { offsets, target in var next = day; next.exerciseIDs.move(fromOffsets: offsets, toOffset: target); save(next) }
                        Button("Browse exercise library", systemImage: "magnifyingglass") { adding = true }
                    }.listRowBackground(theme.surface)
                }.studioScreen().navigationTitle(day.title).toolbar { EditButton() }
                    .sheet(item: $duplicate) { RoutineForm(day: $0) }
                    .sheet(isPresented: $adding) { AddExerciseView(dayID: dayID) }
                    .sheet(isPresented: $editingRoutine) { RoutineForm(day: day) }
                    .sheet(item: $editingExercise) { RoutineExerciseOptions(dayID: dayID, exercise: $0) }
            } else { ContentUnavailableView("Routine removed", systemImage: "calendar") }
        }
    }
    private func moveExercise(_ id: UUID, by offset: Int) {
        guard var day, let index = day.exerciseIDs.firstIndex(of: id), day.exerciseIDs.indices.contains(index + offset) else { return }
        day.exerciseIDs.swapAt(index, index + offset)
        save(day)
    }
    private func save(_ day: DayRecord) {
        var day = day
        day.targets = day.targets?.filter { day.exerciseIDs.contains($0.exerciseID) }
        day.supersets = day.supersets?.filter { day.exerciseIDs.contains($0.first) && day.exerciseIDs.contains($0.second) }
        _ = store.commit { backup in
            if let index = backup.days.firstIndex(where: { $0.id == dayID }) { backup.days[index] = day }
        }
    }
}

struct RoutineForm: View {
    @Environment(\.appTheme) private var theme
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var day: DayRecord
    init(day: DayRecord) {
        var draft = day
        draft.name = day.title
        draft.weekdays = day.scheduledWeekdays
        _day = State(initialValue: draft)
    }
    private var name: Binding<String> { Binding(get: { day.name ?? day.type.title }, set: { day.name = $0 }) }
    var body: some View {
        NavigationStack {
            Form {
                Section("Routine") {
                    TextField("Name, e.g. Full body A", text: name)
                    Picker("Color", selection: $day.type) {
                        ForEach(DayType.allCases) { type in
                            Label { Text(type.colorName) } icon: { Circle().fill(type.color) }.tag(type)
                        }
                    }
                }.listRowBackground(theme.surface)
                Section {
                    ForEach([2,3,4,5,6,7,1], id: \.self) { weekday in
                        Toggle(Calendar.current.weekdaySymbols[weekday - 1], isOn: Binding(get: {
                            day.scheduledWeekdays.contains(weekday)
                        }, set: { selected in
                            var days = day.scheduledWeekdays
                            if selected { if !days.contains(weekday) { days.append(weekday) } }
                            else { days.removeAll { $0 == weekday } }
                            day.weekdays = days
                        }))
                    }
                } header: { Text("Weekly schedule") } footer: { Text("Choose any days, or leave all off for an on-demand routine. Multiple routines can share a day.") }.listRowBackground(theme.surface)
            }.studioScreen().navigationTitle(store.days.contains { $0.id == day.id } ? "Edit routine" : "New routine")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            day.name = day.title.trimmingCharacters(in: .whitespacesAndNewlines)
                            day.weekdays = day.scheduledWeekdays
                            if store.commit({ backup in
                                if let index = backup.days.firstIndex(where: { $0.id == day.id }) { backup.days[index] = day }
                                else { backup.days.append(day) }
                            }) { dismiss() }
                        }.disabled(day.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || day.title.count > 60)
                    }
                }
        }
    }
}

struct AddExerciseView: View {
    @Environment(\.appTheme) private var theme
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var dayID: UUID? = nil
    var sessionID: UUID? = nil
    @State private var selection: [ExerciseRecord] = []
    @State private var creating = false
    @State private var addConfirmation: String?
    @State private var reviewingSelection = false
    private var day: DayRecord? { store.days.first { $0.id == dayID } }
    private var session: SessionRecord? { sessionID.flatMap { store.session($0) } }
    private var existingIDs: [UUID] { session?.logs.map(\.id) ?? day?.exerciseIDs ?? [] }
    private var targetTitle: String { session?.title ?? day?.title ?? "your workout" }
    private var targetAvailable: Bool { sessionID != nil ? session != nil && session?.end == nil : day != nil }
    var body: some View {
        NavigationStack {
            ExerciseCatalogBrowser(unavailable: Set(existingIDs), selected: Set(selection.map(\.id)),
                                   selectionFull: selection.count + existingIDs.count >= 100,
                                   showsRecommendations: true, recommendationDayID: dayID, recommendationSessionID: sessionID) { exercise in
                addConfirmation = nil
                if selection.contains(where: { $0.id == exercise.id }) { selection.removeAll { $0.id == exercise.id } }
                else { selection.append(exercise) }
            }
            .onChange(of: existingIDs) { _, ids in selection.removeAll { ids.contains($0.id) } }
            .studioScreen().navigationTitle("Exercise library").navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(addConfirmation ?? (selection.isEmpty ? "Select exercises for \(targetTitle)" : "\(selection.count) selected · \(targetTitle)"))
                            .font(.subheadline.weight(.medium)).foregroundStyle(Color(uiColor: .label))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if !selection.isEmpty {
                            Button("Review") { reviewingSelection = true }.font(.subheadline.bold()).frame(minHeight: 44)
                        }
                    }
                    Button {
                        let addedCount = selection.count
                        if store.addExercises(selection, dayID: dayID, sessionID: sessionID) {
                            selection.removeAll()
                            addConfirmation = "Added \(addedCount) \(addedCount == 1 ? "exercise" : "exercises") to \(targetTitle)."
                            UIAccessibility.post(notification: .announcement, argument: addConfirmation)
                        }
                    } label: { Label(selection.isEmpty ? "Select exercises above" : "Add \(selection.count) \(selection.count == 1 ? "exercise" : "exercises")", systemImage: "plus").font(.headline) }
                        .buttonStyle(ActionButtonStyle())
                        .disabled(selection.isEmpty || !targetAvailable || selection.count + existingIDs.count > 100)
                }.padding().background(.regularMaterial)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { Button("Custom", systemImage: "plus") { creating = true }.disabled(existingIDs.count >= 100) }
            }
            .sheet(isPresented: $reviewingSelection) {
                NavigationStack {
                    List {
                        Section {
                            ForEach(selection) { exercise in
                                HStack {
                                    Text(exercise.name.capitalized)
                                    Spacer()
                                    Button { selection.removeAll { $0.id == exercise.id } } label: {
                                        Image(systemName: "minus.circle").frame(width: 44, height: 44)
                                    }.accessibilityLabel("Remove \(exercise.name) from selection")
                                }
                            }
                            if selection.isEmpty { Text("No exercises selected.").foregroundStyle(theme.secondary) }
                        } footer: { Text("These exercises will be added in this order when you tap Add.") }.listRowBackground(theme.surface)
                    }.studioScreen().navigationTitle("Your selection").navigationBarTitleDisplayMode(.inline)
                        .toolbar { Button("Done") { reviewingSelection = false } }
                }
            }
            .sheet(isPresented: $creating) { ExerciseForm(exercise: ExerciseRecord(name: "", muscle: "", equipment: .other), addToDay: dayID, addToSession: sessionID) }
        }
    }
}

struct ExerciseForm: View {
    @Environment(\.appTheme) private var theme
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var exercise: ExerciseRecord
    var addToDay: UUID?
    var addToSession: UUID? = nil
    @State private var duplicate = false
    var body: some View {
        NavigationStack {
            Form {
                if exercise.exerciseDBID != nil {
                    NavigationLink("View exercise guide") { ExerciseGuideContent(exercise: exercise) }
                }
                TextField("Exercise name", text: $exercise.name)
                TextField("Muscle group", text: $exercise.muscle)
                Picker("Equipment", selection: Binding(get: { exercise.equipment ?? .other }, set: { exercise.equipment = $0 })) {
                    ForEach(Equipment.allCases) { Text($0.rawValue).tag($0) }
                }
                Toggle("Bodyweight exercise", isOn: $exercise.isBodyweight)
                Text("Edits update this shared exercise across your routines. Saved workouts keep their original labels. For dumbbells, enter one dumbbell’s weight consistently; for barbells and machines, enter the total indicated load.")
                    .font(.caption).foregroundStyle(theme.secondary)
            }.studioScreen().navigationTitle(addToDay == nil && addToSession == nil ? "Edit exercise" : "New exercise")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            exercise.name = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !store.exercises.contains(where: { $0.id != exercise.id && ExerciseLibrary.normalized($0.name) == ExerciseLibrary.normalized(exercise.name) }) else { duplicate = true; return }
                            let saved: Bool
                            if addToSession != nil || addToDay != nil {
                                saved = store.addExercises([exercise], dayID: addToDay, sessionID: addToSession)
                            } else {
                                saved = store.commit { backup in
                                    if let index = backup.exercises.firstIndex(where: { $0.id == exercise.id }) { backup.exercises[index] = exercise }
                                    else { backup.exercises.append(exercise) }
                                }
                            }
                            if saved { dismiss() }
                        }.disabled(exercise.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || exercise.name.count > 200 || exercise.muscle.count > 200)
                    }
                }
                .alert("Exercise already exists", isPresented: $duplicate) { Button("OK") {} } message: { Text("Choose it from the library to keep one shared history, or use a more specific name for a different variation.") }
        }
    }
}
