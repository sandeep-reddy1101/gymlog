import SwiftUI
import Observation

@MainActor @Observable final class CatalogBrowserModel {
    var rows: [CatalogExercise] = []
    var muscles: [String] = []
    var bodyParts: [String] = []
    var equipments: [String] = []
    var error: String?
    var filterError: String?
    var loading = false
    var total = 0
    var cursor: String?
    private var requestID = UUID()
    private var settledQuery: CatalogQuery?

    func loadIfNeeded(_ query: CatalogQuery) async {
        guard settledQuery != query else { return }
        await search(query)
    }

    func filters() async {
        do {
            // Sequential requests also avoid a burst when first opening the library.
            muscles = try await ExerciseCatalog.shared.facets("muscles")
            bodyParts = try await ExerciseCatalog.shared.facets("bodyparts")
            equipments = try await ExerciseCatalog.shared.facets("equipments")
            filterError = nil
        } catch { filterError = error.localizedDescription }
    }
    func search(_ query: CatalogQuery, append: Bool = false) async {
        let token = UUID(); requestID = token
        loading = true; error = nil
        if !append { settledQuery = nil; rows = []; cursor = nil; total = 0 }
        defer { if requestID == token { loading = false } }
        do {
            if !append { try await Task.sleep(for: .milliseconds(500)) }
            try Task.checkCancellation()
            var request = query
            if append { request.cursor = cursor }
            let searching = !ExerciseSearch.words(query.name).isEmpty
            let fetched: [CatalogExercise]
            let next: String?
            let providerTotal: Int?
            if searching {
                let page = try await ExerciseCatalog.shared.searchPage(request)
                fetched = page.data; next = page.nextCursor; providerTotal = nil
            } else {
                let page = try await ExerciseCatalog.shared.page(request)
                fetched = page.data
                providerTotal = page.meta.total
                next = page.meta.hasNextPage && page.meta.nextCursor != request.cursor ? page.meta.nextCursor : nil
            }
            try Task.checkCancellation()
            guard token == requestID else { return }
            if let providerTotal { total = providerTotal }
            var existing = Set(rows.map(\.id))
            rows += fetched.filter { existing.insert($0.id).inserted }
            if searching { rows = ExerciseSearch.sorted(rows, query: query.name); total = rows.count }
            cursor = next
            settledQuery = query
        } catch is CancellationError {} catch {
            if token == requestID { self.error = error.localizedDescription; settledQuery = query }
        }
    }
}

/// Shared browser for adding exercises and replacing one during a workout.
struct ExerciseCatalogBrowser: View {
    @Environment(AppStore.self) private var store
    var unavailable: Set<UUID>
    var selected: Set<UUID>
    var selectionFull = false
    var onSelect: (ExerciseRecord) -> Void
    @State private var model = CatalogBrowserModel()
    @State private var search = ""
    @State private var muscle = ""
    @State private var bodyPart = ""
    @State private var equipment = ""
    @State private var savedOnly = false
    @State private var guide: ExerciseRecord?
    @State private var showingFilters = false
    @FocusState private var searching: Bool
    private var filterCount: Int { [muscle, bodyPart, equipment].filter { !$0.isEmpty }.count }
    private var query: CatalogQuery { CatalogQuery(name: search, muscle: muscle, bodyPart: bodyPart, equipment: equipment) }
    private var saved: [ExerciseRecord] {
        let used = Set(store.days.flatMap(\.exerciseIDs) + store.sessions.flatMap { $0.logs.map(\.id) })
        var records: [UUID: ExerciseRecord] = [:]
        for session in store.sessions.reversed() { for log in session.logs { records[log.id] = log.exercise } }
        for exercise in store.exercises where exercise.catalogKey == nil || used.contains(exercise.id) { records[exercise.id] = exercise }
        return records.values.filter { ExerciseSearch.matches($0.name, query: search) }
            .sorted {
                let first = ExerciseSearch.rank($0.name, query: search), second = ExerciseSearch.rank($1.name, query: search)
                return first == second ? $0.name < $1.name : first < second
            }
    }
    var body: some View {
        let savedRecords = saved
        let recordsBySource = Dictionary(savedRecords.compactMap { record in record.exerciseDBID.map { ($0, record) } }, uniquingKeysWith: { first, _ in first })
        return VStack(spacing: 0) {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField(savedOnly ? "Search saved exercises" : "Search, e.g. dumbbell row", text: $search)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .focused($searching).submitLabel(.search).onSubmit { searching = false }
                        .accessibilityLabel("Search exercise names")
                    if !search.isEmpty {
                        Button { search = "" } label: { Image(systemName: "xmark.circle.fill").frame(width: 44, height: 44) }
                            .foregroundStyle(.secondary).accessibilityLabel("Clear search")
                    }
                }.padding(.leading, 14).padding(.trailing, 4).frame(minHeight: 52)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                HStack(spacing: 12) {
                    Picker("Browse", selection: $savedOnly) {
                        Text("All exercises").tag(false)
                        Text("Saved").tag(true)
                    }.pickerStyle(.segmented)
                    if !savedOnly {
                        Button { searching = false; showingFilters = true } label: {
                            Label(filterCount == 0 ? "Filters" : "Filters (\(filterCount))", systemImage: "line.3.horizontal.decrease")
                                .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                        }.accessibilityLabel("Filters, \(filterCount) active")
                    }
                }
                if !savedOnly && filterCount > 0 {
                    HStack {
                        Text([muscle, bodyPart, equipment].filter { !$0.isEmpty }.map { $0.capitalized }.joined(separator: " · "))
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("Clear filters") { muscle = ""; bodyPart = ""; equipment = "" }.font(.caption).frame(minHeight: 44)
                    }
                }
            }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 4)
            List {
                if savedOnly {
                    Section("Your saved exercises") {
                        ForEach(savedRecords) { row($0) }
                        if savedRecords.isEmpty { Text("Exercises you add or log will appear here. Saved exercises work offline.").foregroundStyle(.secondary) }
                    }
                } else {
                    Section {
                        ForEach(model.rows) { entry in
                            row(recordsBySource[entry.id] ?? entry.record)
                        }
                        if model.loading { ProgressView("Loading exercises…") }
                        if let error = model.error {
                            Text(error).foregroundStyle(.secondary)
                            Button("Retry") { Task { await model.search(query, append: !model.rows.isEmpty) } }.disabled(model.loading)
                        } else if model.rows.isEmpty && !model.loading {
                            ContentUnavailableView(model.cursor == nil ? "No matching exercises" : "No matches in these results",
                                                   systemImage: "magnifyingglass",
                                                   description: Text(model.cursor == nil ? "Check the name or clear a filter. Search matches all words in the exercise name." : "More provider results are available. Tap Load more exercises to keep searching."))
                        }
                        if model.cursor != nil {
                            Button("Load more exercises") { Task { await model.search(query, append: true) } }.disabled(model.loading)
                        }
                    } header: { Text(ExerciseSearch.words(search).isEmpty ? "\(model.rows.count) of \(model.total) exercises" : "\(model.rows.count) matching exercises\(model.cursor == nil ? "" : " · more available")") }
                    Section {
                        Link("Exercise data & animations by AscendAPI", destination: URL(string: "https://ascendapi.com")!)
                            .font(.footnote)
                        Text("Recent results are kept for one hour. Saved exercises stay available for logging offline.").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollDismissesKeyboard(.interactively)
            .refreshable { if !savedOnly { await model.search(query) } }
        }.background(Color(uiColor: .systemGroupedBackground))
        .sheet(isPresented: $showingFilters) {
            CatalogFiltersView(muscles: model.muscles, bodyParts: model.bodyParts, equipments: model.equipments,
                               error: model.filterError, muscle: muscle, bodyPart: bodyPart, equipment: equipment,
                               retry: { Task { await model.filters() } }) { m, b, e in
                muscle = m; bodyPart = b; equipment = e
            }
        }
        .task { await model.filters() }
        .task(id: query) { if !savedOnly { await model.loadIfNeeded(query) } }
        .onChange(of: savedOnly) { _, value in if !value { Task { await model.loadIfNeeded(query) } } }
        .sheet(item: $guide) { ExerciseGuideView(exercise: $0) }
    }
    private func row(_ exercise: ExerciseRecord) -> some View {
        let used = unavailable.contains(exercise.id)
        let picked = selected.contains(exercise.id)
        return HStack(spacing: 12) {
            Button { searching = false; onSelect(exercise) } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(exercise.name.capitalized).font(.headline).foregroundStyle(Color(uiColor: .label))
                        Text("\(exercise.muscle.capitalized) · \(exercise.equipmentLabel.capitalized)").font(.caption).foregroundStyle(Color(uiColor: .secondaryLabel))
                    }
                    Spacer(minLength: 8)
                    VStack(spacing: 4) {
                        Image(systemName: used ? "checkmark.circle.fill" : picked ? "checkmark.circle.fill" : "plus.circle")
                            .font(.title2)
                        Text(used ? "Added" : picked ? "Selected" : "Select").font(.caption2.weight(.semibold))
                    }.foregroundStyle(used ? Color(uiColor: .secondaryLabel) : AppColors.action)
                        .frame(minWidth: 54, minHeight: 52)
                }.padding(.vertical, 6).contentShape(Rectangle())
            }.buttonStyle(.plain).disabled(used || (selectionFull && !picked))
                .accessibilityLabel("\(exercise.name), \(used ? "already added" : picked ? "selected" : "select")")
            if exercise.exerciseDBID != nil {
                Button { searching = false; guide = exercise } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "figure.strengthtraining.traditional").font(.title3)
                        Text("Guide").font(.caption2.weight(.semibold))
                    }.frame(minWidth: 44, minHeight: 52)
                }
                    .buttonStyle(.borderless).accessibilityLabel("Instructions and animation for \(exercise.name)")
            }
        }
    }
}

private struct CatalogFiltersView: View {
    @Environment(\.dismiss) private var dismiss
    let muscles: [String]
    let bodyParts: [String]
    let equipments: [String]
    let error: String?
    @State var muscle: String
    @State var bodyPart: String
    @State var equipment: String
    let retry: () -> Void
    let apply: (String, String, String) -> Void
    var body: some View {
        NavigationStack {
            Form {
                if (muscles.isEmpty || bodyParts.isEmpty || equipments.isEmpty) && error == nil {
                    ProgressView("Loading filters…")
                }
                Section {
                    facet("Muscle", selection: $muscle, values: muscles)
                    facet("Body part", selection: $bodyPart, values: bodyParts)
                    facet("Equipment", selection: $equipment, values: equipments)
                } footer: { Text("Combine filters to narrow your exercise search.") }
                if let error {
                    Section { Text(error); Button("Retry loading filters", action: retry) }
                }
                Button("Reset filters") { muscle = ""; bodyPart = ""; equipment = "" }
            }.navigationTitle("Filter exercises").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
                .safeAreaInset(edge: .bottom) {
                    Button { apply(muscle, bodyPart, equipment); dismiss() } label: {
                        Text("Show exercises").font(.headline)
                    }.buttonStyle(ActionButtonStyle()).padding().background(.regularMaterial)
                }
        }
    }
    private func facet(_ title: String, selection: Binding<String>, values: [String]) -> some View {
        Picker(title, selection: selection) {
            Text("All").tag("")
            ForEach(values, id: \.self) { Text($0.capitalized).tag($0) }
        }.disabled(values.isEmpty)
    }
}
