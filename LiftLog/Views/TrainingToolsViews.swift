import SwiftUI

struct WorkoutNotesEditor: View {
    @Environment(\.appTheme) private var theme
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var sessionID: UUID
    var exerciseID: UUID? = nil
    @State private var text = ""
    private var limit: Int { exerciseID == nil ? 4000 : 2000 }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $text).frame(minHeight: 180).accessibilityLabel("Notes")
                    Text("\(text.count) / \(limit)").font(.caption).foregroundStyle(text.count > limit ? .red : .secondary)
                } header: { Text(exerciseID == nil ? "How did the workout go?" : "Technique, equipment, or adjustments") } footer: {
                    Text("Notes belong to this workout. Exercise notes also appear as a reference next time you log that exercise.")
                }.listRowBackground(theme.surface)
            }.studioScreen().navigationTitle(exerciseID == nil ? "Workout notes" : "Exercise notes").navigationBarTitleDisplayMode(.inline)
                .onAppear {
                    if let session = store.session(sessionID) {
                        text = exerciseID.map { id in session.logs.first { $0.id == id }?.notes ?? "" } ?? session.notes ?? ""
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            guard var session = store.session(sessionID) else { dismiss(); return }
                            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                            if let exerciseID {
                                guard let index = session.logs.firstIndex(where: { $0.id == exerciseID }) else { return }
                                session.logs[index].notes = trimmed.isEmpty ? nil : trimmed
                            } else { session.notes = trimmed.isEmpty ? nil : trimmed }
                            if store.updateSession(session) { dismiss() }
                        }.disabled(text.count > limit)
                    }
                }
        }
    }
}

struct RoutineExerciseOptions: View {
    @Environment(\.appTheme) private var theme
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var dayID: UUID
    var exercise: ExerciseRecord
    @State private var hasTarget = false
    @State private var lower = 8
    @State private var upper = 12
    @State private var partnerID: UUID?
    @State private var editingShared = false
    @State private var loaded = false
    private var day: DayRecord? { store.days.first { $0.id == dayID } }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Set a rep target", isOn: $hasTarget)
                    if hasTarget {
                        Stepper("Minimum: \(lower) reps", value: $lower, in: 1...1000)
                        Stepper("Maximum: \(upper) reps", value: $upper, in: 1...1000)
                        if lower > upper { Text("Maximum must be at least the minimum.").foregroundStyle(.red) }
                    }
                } header: { Text("Rep range") } footer: { Text("A target for this exercise in this routine. Actual reps are logged separately and may be outside the range.") }.listRowBackground(theme.surface)
                Section {
                    Picker("Pair with", selection: $partnerID) {
                        Text("No superset").tag(Optional<UUID>.none)
                        if let day {
                            ForEach(day.exerciseIDs.filter { $0 != exercise.id }, id: \.self) { id in
                                if let other = store.exercises.first(where: { $0.id == id }) {
                                    let pairedElsewhere = day.supersets?.contains { $0.contains(id) && !$0.contains(exercise.id) } ?? false
                                    Text(other.name + (pairedElsewhere ? " (already paired)" : "")).tag(Optional(id)).disabled(pairedElsewhere)
                                }
                            }
                        }
                    }
                } header: { Text("Superset") } footer: {
                    Text("Alternate one set of each exercise, then rest. Each exercise can belong to one pair. Different set counts are supported; remaining sets are logged on their own. Changes apply to your next workout.")
                }.listRowBackground(theme.surface)
                Section {
                    Button("Edit shared exercise details") { editingShared = true }
                } footer: { Text("Names and equipment are shared across routines. Targets and pairs are specific to this routine.") }.listRowBackground(theme.surface)
            }.studioScreen().navigationTitle(exercise.name).navigationBarTitleDisplayMode(.inline)
                .onAppear {
                    guard !loaded else { return }; loaded = true
                    if let range = day?.targets?.first(where: { $0.exerciseID == exercise.id })?.range {
                        hasTarget = true; lower = range.lower; upper = range.upper
                    }
                    partnerID = day?.supersets?.first { $0.contains(exercise.id) }?.partner(of: exercise.id)
                }
                .sheet(isPresented: $editingShared) { ExerciseForm(exercise: store.exercises.first { $0.id == exercise.id } ?? exercise) }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            if store.commit({ backup in
                                guard let index = backup.days.firstIndex(where: { $0.id == dayID }) else { return }
                                var next = backup.days[index]
                                var targets = next.targets ?? []
                                targets.removeAll { $0.exerciseID == exercise.id }
                                if hasTarget { targets.append(RepTarget(exerciseID: exercise.id, range: RepRange(lower: lower, upper: upper))) }
                                next.targets = targets.isEmpty ? nil : targets
                                var pairs = next.supersets ?? []
                                let existing = pairs.first { $0.contains(exercise.id) }
                                pairs.removeAll { $0.contains(exercise.id) }
                                if let partnerID {
                                    if let existing, existing.partner(of: exercise.id) == partnerID { pairs.append(existing) }
                                    else { pairs.append(SupersetPair(first: exercise.id, second: partnerID)) }
                                }
                                next.supersets = pairs.isEmpty ? nil : pairs
                                backup.days[index] = next
                            }) { dismiss() }
                        }.disabled(day == nil || (hasTarget && lower > upper))
                    }
                }
        }
    }
}

struct PlateCalculatorView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var unit: WeightUnit
    @State private var target: String
    @State private var bar: String
    @State private var stock: [PlateStock]
    @State private var result: PlateResult?
    @State private var error: String?
    init(unit: WeightUnit, targetWeight: Double? = nil) {
        _unit = State(initialValue: unit)
        _target = State(initialValue: (targetWeight ?? (unit == .kg ? 60 : 135)).formatted(.number.grouping(.never)))
        _bar = State(initialValue: unit == .kg ? "20" : "45")
        _stock = State(initialValue: PlateCalculator.standard(unit))
    }
    private func number(_ text: String) -> Double? {
        let formatter = NumberFormatter(); formatter.locale = .current; formatter.numberStyle = .decimal
        return formatter.number(from: text)?.doubleValue
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Units", selection: $unit) { ForEach(WeightUnit.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
                    HStack { Text("Target total"); TextField("Total", text: $target).multilineTextAlignment(.trailing).keyboardType(.decimalPad); Text(unit.rawValue) }
                    HStack { Text("Bar weight"); TextField("Bar", text: $bar).multilineTextAlignment(.trailing).keyboardType(.decimalPad); Text(unit.rawValue) }
                } footer: { Text("Target includes the bar. Set the actual bar weight; collars are excluded. Changing units resets the example and plate inventory.") }.listRowBackground(theme.surface)
                Section {
                    ForEach($stock) { $plate in
                        Stepper("\(plate.weight.formatted()) \(unit.rawValue): \(plate.pairs) pairs", value: $plate.pairs, in: 0...12)
                    }
                } header: { Text("Available plates") } footer: { Text("One pair means one matching plate for each side. Set unavailable sizes to zero.") }.listRowBackground(theme.surface)
                Button("Calculate plates", systemImage: "equal.circle") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    guard let targetValue = number(target), let barValue = number(bar) else { error = "Enter numeric target and bar weights."; return }
                    do { result = try PlateCalculator.calculate(target: targetValue, bar: barValue, stock: stock); error = nil }
                    catch { result = nil; self.error = error.localizedDescription }
                }.frame(minHeight: 44)
                if let error { Text(error).foregroundStyle(.red) }
                if let result {
                    Section("Load this on EACH side") {
                        if result.perSide.isEmpty { Text("Bar only") }
                        else {
                            Text(result.perSide.map { $0.formatted() }.joined(separator: " + ") + " \(unit.rawValue)").font(.title3.bold())
                            Text("Largest plates first. Mirror the same plates on the other side.").font(.caption).foregroundStyle(theme.secondary)
                        }
                        LabeledContent("Total including bar", value: "\(result.total.formatted()) \(unit.rawValue)")
                        if result.shortfall > 0.00001 {
                            Text("Closest available load below your target: \(result.shortfall.formatted()) \(unit.rawValue) short. It does not round up.").foregroundStyle(theme.secondary)
                        } else { Label("Exact target", systemImage: "checkmark.circle").foregroundStyle(.green) }
                    }.listRowBackground(theme.surface)
                }
            }.studioScreen().navigationTitle("Plate calculator").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .onChange(of: unit) { _, unit in
                    bar = unit == .kg ? "20" : "45"; target = unit == .kg ? "60" : "135"
                    stock = PlateCalculator.standard(unit); result = nil; error = nil
                }
                .onChange(of: target) { _, _ in result = nil; error = nil }
                .onChange(of: bar) { _, _ in result = nil; error = nil }
                .onChange(of: stock) { _, _ in result = nil; error = nil }
        }
    }
}
