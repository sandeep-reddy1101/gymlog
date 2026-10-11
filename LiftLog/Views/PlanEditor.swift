import SwiftUI

struct PlanEditor: View {
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
                                Text("\(day.scheduleDescription) · \(day.exerciseIDs.count) exercises").font(.caption).foregroundStyle(.secondary)
                            }
                        }.padding(.vertical, 5)
                    }.swipeActions { Button("Delete", role: .destructive) { deleting = day } }
                        .swipeActions(edge: .leading) {
                            Button("Duplicate", systemImage: "plus.square.on.square") { duplicate = WorkoutLogic.duplicate(day) }
                                .tint(.blue).disabled(store.days.count >= 100)
                        }
                }
                .onMove { offsets, target in _ = store.commit { $0.days.move(fromOffsets: offsets, toOffset: target) } }
                Button("Create routine", systemImage: "plus") { creating = true }.disabled(store.days.count >= 100)
            }.navigationTitle("Your routines")
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
                    } footer: { Text("Changes apply to future workouts. Saved sessions keep their original names and sets.") }
                    Section {
                        Text("Tap an exercise for rep targets and supersets. Tap Edit to reorder.").font(.caption).foregroundStyle(.secondary)
                    }
                    Section("Exercises · \(day.exerciseIDs.count)") {
                        if day.exerciseIDs.isEmpty { Text("No exercises assigned yet.").foregroundStyle(.secondary) }
                        ForEach(day.exerciseIDs, id: \.self) { id in
                            if let exercise = store.exercises.first(where: { $0.id == id }) {
                                Button { editingExercise = exercise } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(exercise.name).foregroundStyle(.primary)
                                        if let range = day.targets?.first(where: { $0.exerciseID == id })?.range {
                                            Text("Target: \(range.text)").font(.caption).foregroundStyle(.secondary)
                                        }
                                        if let partner = day.supersets?.first(where: { $0.contains(id) })?.partner(of: id),
                                           let name = store.exercises.first(where: { $0.id == partner })?.name {
                                            Label("Paired with \(name)", systemImage: "link").font(.caption).foregroundStyle(.teal)
                                        }
                                        Text("\(exercise.muscle) · \(exercise.equipmentLabel)").font(.caption).foregroundStyle(.secondary)
                                    }.padding(.vertical, 4)
                                }
                            }
                        }
                        .onDelete { offsets in var next = day; next.exerciseIDs.remove(atOffsets: offsets); save(next) }
                        .onMove { offsets, target in var next = day; next.exerciseIDs.move(fromOffsets: offsets, toOffset: target); save(next) }
                        Button("Browse exercise library", systemImage: "magnifyingglass") { adding = true }
                    }
                }.navigationTitle(day.title).toolbar { EditButton() }
                    .sheet(item: $duplicate) { RoutineForm(day: $0) }
                    .sheet(isPresented: $adding) { AddExerciseView(dayID: dayID) }
                    .sheet(isPresented: $editingRoutine) { RoutineForm(day: day) }
                    .sheet(item: $editingExercise) { RoutineExerciseOptions(dayID: dayID, exercise: $0) }
            } else { ContentUnavailableView("Routine removed", systemImage: "calendar") }
        }
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
                }
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
                } header: { Text("Weekly schedule") } footer: { Text("Choose any days, or leave all off for an on-demand routine. Multiple routines can share a day.") }
            }.navigationTitle(store.days.contains { $0.id == day.id } ? "Edit routine" : "New routine")
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
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var dayID: UUID
    @State private var selection: [ExerciseRecord] = []
    @State private var creating = false
    @State private var addConfirmation: String?
    @State private var reviewingSelection = false
    private var day: DayRecord? { store.days.first { $0.id == dayID } }
    var body: some View {
        NavigationStack {
            ExerciseCatalogBrowser(unavailable: Set(day?.exerciseIDs ?? []), selected: Set(selection.map(\.id)),
                                   selectionFull: selection.count + (day?.exerciseIDs.count ?? 0) >= 100) { exercise in
                addConfirmation = nil
                if selection.contains(where: { $0.id == exercise.id }) { selection.removeAll { $0.id == exercise.id } }
                else { selection.append(exercise) }
            }
            .navigationTitle("Exercise library").navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(addConfirmation ?? (selection.isEmpty ? "Select exercises for \(day?.title ?? "your routine")" : "\(selection.count) selected · \(day?.title ?? "Your routine")"))
                            .font(.subheadline.weight(.medium)).foregroundStyle(Color(uiColor: .label))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if !selection.isEmpty {
                            Button("Review") { reviewingSelection = true }.font(.subheadline.bold()).frame(minHeight: 44)
                        }
                    }
                    Button {
                        guard let day else { return }
                        let addedCount = selection.count
                        if store.commit({ backup in
                            if let index = backup.days.firstIndex(where: { $0.id == dayID }) {
                                let known = Set(backup.exercises.map(\.id))
                                backup.exercises += selection.filter { !known.contains($0.id) }
                                backup.days[index] = ExerciseLibrary.adding(selection.map(\.id), to: backup.days[index])
                            }
                        }) {
                            selection.removeAll()
                            addConfirmation = "Added \(addedCount) \(addedCount == 1 ? "exercise" : "exercises") to \(day.title)."
                            UIAccessibility.post(notification: .announcement, argument: addConfirmation)
                        }
                    } label: { Label(selection.isEmpty ? "Select exercises above" : "Add \(selection.count) \(selection.count == 1 ? "exercise" : "exercises")", systemImage: "plus").font(.headline) }
                        .buttonStyle(ActionButtonStyle())
                        .disabled(selection.isEmpty || day == nil || selection.count + (day?.exerciseIDs.count ?? 0) > 100)
                }.padding().background(.regularMaterial)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { Button("Custom", systemImage: "plus") { creating = true }.disabled((day?.exerciseIDs.count ?? 0) >= 100) }
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
                            if selection.isEmpty { Text("No exercises selected.").foregroundStyle(.secondary) }
                        } footer: { Text("These exercises will be added in this order when you tap Add.") }
                    }.navigationTitle("Your selection").navigationBarTitleDisplayMode(.inline)
                        .toolbar { Button("Done") { reviewingSelection = false } }
                }
            }
            .sheet(isPresented: $creating) { ExerciseForm(exercise: ExerciseRecord(name: "", muscle: "", equipment: .other), addToDay: dayID) }
        }
    }
}

struct ExerciseForm: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var exercise: ExerciseRecord
    var addToDay: UUID?
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
                    .font(.caption).foregroundStyle(.secondary)
            }.navigationTitle(addToDay == nil ? "Edit exercise" : "New exercise")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            exercise.name = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !store.exercises.contains(where: { $0.id != exercise.id && ExerciseLibrary.normalized($0.name) == ExerciseLibrary.normalized(exercise.name) }) else { duplicate = true; return }
                            let saved = store.commit { backup in
                                if let index = backup.exercises.firstIndex(where: { $0.id == exercise.id }) { backup.exercises[index] = exercise }
                                else { backup.exercises.append(exercise) }
                                if let addToDay, let index = backup.days.firstIndex(where: { $0.id == addToDay }) {
                                    backup.days[index] = ExerciseLibrary.adding([exercise.id], to: backup.days[index])
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
