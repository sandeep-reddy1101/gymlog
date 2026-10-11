import SwiftUI
import Observation

struct RecommendedRoutineList: View {
    @Environment(AppStore.self) private var store
    @Environment(\.appTheme) private var theme
    var dayID: UUID? = nil
    var sessionID: UUID? = nil
    private var remaining: [RecommendedRoutine] {
        RecommendedRoutine.all.filter { template in !store.days.contains { $0.recommendedTemplateID == template.id } }
    }
    var body: some View {
        List {
            Section {
                Text("Your five-day dumbbell plan").font(.headline)
                Text("Dumbbells, flat/incline bench and pull-up bar. Preview the exercises, then create a routine in one step. Nothing is added automatically.")
                    .font(.subheadline).foregroundStyle(theme.secondary)
                if !remaining.isEmpty {
                    NavigationLink {
                        RecommendedRoutinePreview(templates: remaining)
                    } label: { Label(remaining.count == 5 ? "Preview all 5 routines" : "Preview \(remaining.count) remaining routines", systemImage: "calendar.badge.plus") }
                }
            }.listRowBackground(theme.surface)
            Section("Recommended routines") {
                ForEach(RecommendedRoutine.all) { template in
                    NavigationLink {
                        RecommendedRoutinePreview(templates: [template], dayID: dayID, sessionID: sessionID)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(template.title).font(.headline)
                                Spacer()
                                if !remaining.contains(where: { $0.id == template.id }) { Text("Added").font(.caption).foregroundStyle(theme.secondary) }
                            }
                            Text("\(template.type.shortDay) · \(template.moves.filter { !$0.optional }.count) exercises\(template.moves.contains(where: \.optional) ? " + optional shrug" : "")")
                                .font(.caption).foregroundStyle(theme.secondary)
                            if template.moves.contains(where: { $0.providerID == nil }) {
                                Text("2 exercises need your choice").font(.caption).foregroundStyle(theme.secondary)
                            }
                        }.padding(.vertical, 4)
                    }
                }
            }.listRowBackground(theme.surface)
            Section {
                Text("Thursday and Sunday are rest days in this plan. Names, days and exercise order remain editable. Sets use your current default; past performance still fills in when you start.")
                    .font(.footnote).foregroundStyle(theme.secondary)
                Link("Exercise data & animations by AscendAPI", destination: URL(string: "https://ascendapi.com")!)
            }.listRowBackground(theme.surface)
        }.studioScreen().navigationTitle("Recommended")
    }
}

struct RecommendedRoutinePreview: View {
    @Environment(AppStore.self) private var store
    @Environment(\.appTheme) private var theme
    @State private var model: RecommendedPreviewModel
    @State private var choosing: Choice?
    @State private var guide: ExerciseRecord?
    var dayID: UUID?
    var sessionID: UUID?
    private struct Choice: Identifiable { let id: String; let title: String }
    init(templates: [RecommendedRoutine], dayID: UUID? = nil, sessionID: UUID? = nil) {
        _model = State(initialValue: RecommendedPreviewModel(templates))
        self.dayID = dayID; self.sessionID = sessionID
    }
    private var targetTitle: String? {
        if let sessionID, let session = store.session(sessionID), session.end == nil { return session.title }
        if sessionID == nil, let dayID { return store.days.first { $0.id == dayID }?.title }
        return nil
    }
    private var alreadyCreated: Bool { model.templates.contains { t in store.days.contains { $0.recommendedTemplateID == t.id } } }
    var body: some View {
        @Bindable var model = model
        Form {
            Section {
                Toggle("Use suggested weekdays", isOn: $model.scheduled)
                Text("Preview each match below. You can rename routines, exclude exercises or choose another exercise. Edit days and order after adding.")
                    .font(.caption).foregroundStyle(theme.secondary)
            }.listRowBackground(theme.surface).disabled(model.loading || model.savedMessage != nil)
            ForEach(model.templates) { template in
                Section {
                    TextField("Routine name", text: Binding(get: { model.names[template.id] ?? template.title }, set: { model.names[template.id] = $0 }))
                        .accessibilityLabel("\(template.title) routine name")
                    ForEach(template.moves) { move in moveRow(template, move) }
                } header: { Text("\(template.title) · \(model.scheduled ? template.type.shortDay : "Any day")") }
                    .listRowBackground(theme.surface).disabled(model.loading || model.savedMessage != nil)
            }
            Section {
                if model.loading { ProgressView("Loading exercise details…") }
                if let error = model.error { Text(error).foregroundStyle(theme.secondary) }
                if !model.ready && !model.loading && model.savedMessage == nil {
                    Text("Include at least one unique, verified exercise per routine and a name of 1–60 characters. Choose any missing matches above or switch off those movements.")
                        .font(.caption).foregroundStyle(theme.secondary)
                    Button("Retry loading exercises") { Task { await model.refresh() } }
                }
                if let message = model.savedMessage {
                    Label(message, systemImage: "checkmark.circle.fill")
                    ForEach(model.createdIDs, id: \.self) { id in
                        if let day = store.days.first(where: { $0.id == id }) {
                            NavigationLink("Open \(day.title)") { RoutineDetail(dayID: id) }
                        }
                    }
                } else {
                    Button(model.templates.count == 1 ? "Create \(model.names[model.templates[0].id] ?? "") routine" : "Create \(model.templates.count) routines") {
                        save(create: true)
                    }.buttonStyle(ActionButtonStyle()).disabled(!model.ready || alreadyCreated || store.days.count + model.templates.count > 100)
                    if alreadyCreated { Text("Already added. Open Routines to edit or duplicate it.").font(.caption).foregroundStyle(theme.secondary) }
                    if model.templates.count == 1, let targetTitle {
                        Button("Add \(model.count) exercises to \(targetTitle)") { save(create: false) }
                            .buttonStyle(SecondaryButtonStyle()).disabled(!model.ready)
                        Text("Adds only the exercises to your current routine or workout. Its name and schedule stay the same.").font(.caption).foregroundStyle(theme.secondary)
                    }
                }
            }.listRowBackground(theme.surface)
            Section {
                Text("Provider details use the shared one-hour cache. No workout or Health data is sent to AscendAPI.")
                    .font(.caption).foregroundStyle(theme.secondary)
            }.listRowBackground(theme.surface)
        }.scrollDismissesKeyboard(.interactively).studioScreen().navigationTitle(model.templates.count == 1 ? "Preview \(model.templates[0].title)" : "Preview plan")
        .task { if model.resolved.isEmpty && model.savedMessage == nil { await model.refresh() } }
        .sheet(item: $choosing) { choice in
            RecommendedExerciseChoice(title: choice.title) { entry in
                model.replacements[choice.id] = entry
                model.excluded.remove(choice.id)
                choosing = nil
                Task { await model.refresh() }
            }
        }
        .sheet(item: $guide) { ExerciseGuideView(exercise: $0) }
    }
    private func moveRow(_ template: RecommendedRoutine, _ move: RecommendedMove) -> some View {
        let key = RecommendedPreviewModel.key(template, move)
        let included = !model.excluded.contains(key)
        return VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(get: { !model.excluded.contains(key) }, set: { value in
                if value { model.excluded.remove(key) } else { model.excluded.insert(key) }
                Task { await model.refresh() }
            })) { Text(move.title + (move.optional ? " · optional" : "")).font(.headline) }
                .accessibilityLabel("Include \(move.title)")
            if included {
                if let entry = model.resolved[key] {
                    Text(entry.name.capitalized).font(.subheadline)
                    Text("\(entry.equipments.joined(separator: ", ").capitalized) · \(entry.targetMuscles.joined(separator: ", ").capitalized)")
                        .font(.caption).foregroundStyle(theme.secondary)
                    if model.replacements[key] != nil { Text("Your chosen replacement").font(.caption).foregroundStyle(theme.secondary) }
                    else if let note = move.note { Text(note).font(.caption).foregroundStyle(theme.secondary) }
                } else if let issue = model.issues[key] { Text(issue).font(.caption).foregroundStyle(theme.secondary) }
                HStack {
                    Button("Choose exercise") { choosing = Choice(id: key, title: move.title) }.buttonStyle(.borderless).frame(minHeight: 44)
                        .accessibilityLabel("Choose exercise for \(move.title)")
                    Spacer()
                    if let entry = model.resolved[key] {
                        Button("Guide") { guide = entry.record }.buttonStyle(.borderless).frame(minHeight: 44)
                            .accessibilityLabel("Guide for \(move.title)")
                    }
                }
            } else { Text(move.optional ? "Optional · not included" : "Not included").font(.caption).foregroundStyle(theme.secondary) }
        }.padding(.vertical, 4)
    }
    private func save(create: Bool) {
        Task {
            // Revalidates expired details; fresh responses require no network requests.
            await model.refresh()
            guard model.ready else { return }
            let drafts = model.drafts()
            if create {
                let previous = Set(store.days.map(\.id))
                if store.addRecommendedRoutines(drafts) {
                    model.createdIDs = store.days.filter { !previous.contains($0.id) }.map(\.id)
                    model.savedMessage = "Added \(drafts.count) \(drafts.count == 1 ? "routine" : "routines")."
                } else { model.error = store.errorMessage ?? "Could not save the routines. Please try again." }
            } else {
                let records = RecommendedRoutineImport.records(drafts.flatMap(\.exercises), in: store.data)
                if store.addExercises(records, dayID: dayID, sessionID: sessionID) { model.savedMessage = "Exercises added. Your search is still here when you go back." }
                else { model.error = store.errorMessage ?? "Could not add exercises. Please try again." }
            }
        }
    }
}

private struct RecommendedExerciseChoice: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let onChoose: (CatalogExercise) -> Void
    @State private var loading = false
    @State private var error: String?
    @State private var selectedID: String?
    var body: some View {
        NavigationStack {
            ExerciseCatalogBrowser(unavailable: [], selected: [], apiOnly: true) { record in
                guard !loading, let id = record.exerciseDBID else { return }
                loading = true; error = nil; selectedID = id
            }.disabled(loading).studioScreen().navigationTitle(title)
                .task(id: selectedID) {
                    guard let selectedID else { return }
                    defer { loading = false }
                    do {
                        let entry = try await ExerciseCatalog.shared.detail(selectedID)
                        try Task.checkCancellation()
                        onChoose(entry)
                    } catch is CancellationError {} catch { self.error = error.localizedDescription; self.selectedID = nil }
                }
                .safeAreaInset(edge: .bottom) {
                    if loading { ProgressView("Checking exercise…").padding().frame(maxWidth: .infinity).background(.regularMaterial) }
                    else if let error { Text(error).padding().background(.regularMaterial) }
                }
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}
