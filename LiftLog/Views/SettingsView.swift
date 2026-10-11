import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @State private var importPicker = false
    @State private var pendingImport: Backup?
    @State private var resetConfirmation = false
    @State private var shareURL: URL?
    @State private var sharing = false
    @State private var demo = false
    @State private var editPlan = false
    @State private var importMessage: String?
    @State private var calculator = false
    var body: some View {
        NavigationStack {
            Form {
                Section("Workout preferences") {
                    Picker("Weight unit", selection: Binding(get: { store.unit }, set: { new in _ = store.commit { $0.preferences.unit = new } })) {
                        ForEach(WeightUnit.allCases) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.segmented)
                    Stepper("Default sets: \(store.data.preferences.defaultSets)", value: Binding(get: { store.data.preferences.defaultSets }, set: { new in _ = store.commit { $0.preferences.defaultSets = new } }), in: 1...10)
                    Button("Manage routines") { editPlan = true }
                    Text("Log one dumbbell’s weight consistently. For bodyweight exercises, log only added weight. Volume is entered weight × reps.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    Toggle("Start rest after completing a set", isOn: Binding(get: { store.data.preferences.resolvedAutomaticRest }, set: { new in _ = store.commit { $0.preferences.automaticRest = new } }))
                    Stepper("Rest time: \(store.data.preferences.resolvedRestSeconds) seconds", value: Binding(get: { store.data.preferences.resolvedRestSeconds }, set: { new in _ = store.commit { $0.preferences.restSeconds = new } }), in: 15...600, step: 15)
                    Toggle("Background rest alerts", isOn: Binding(get: { store.data.preferences.restAlerts ?? false }, set: { enabled in
                        if enabled { Task { await store.enableRestAlerts() } }
                        else { _ = store.commit { $0.preferences.restAlerts = false } }
                    })).disabled(store.isDemo || store.restNotifications.isRequesting)
                    Text(store.isDemo ? "Notification permission is requested only outside sample mode." : store.restNotifications.status).font(.caption).foregroundStyle(.secondary)
                    Stepper("Weekly goal: \(store.data.preferences.resolvedWeeklyGoal) workouts", value: Binding(get: { store.data.preferences.resolvedWeeklyGoal }, set: { new in _ = store.commit { $0.preferences.weeklyGoal = new } }), in: 1...7)
                } header: { Text("Rest & consistency") } footer: {
                    Text("Rest alerts use local notifications after you grant permission. Pause, skip, finish or undo updates the scheduled alert. Your weekly goal is independent of scheduled days.")
                }
                Section("Workout tools") {
                    Button("Plate calculator", systemImage: "equal.circle") { calculator = true }
                    Text("Reps left means how many more reps you think you could have done with good form. It is optional for each completed set; 0 means none, and 10 means 10 or more.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Apple Health & Watch") {
                    HealthConnectionStatus()
                    Button(store.health.isBusy ? "Reading Health…" : "Connect / refresh Apple Health") {
                        Task { await store.health.authorize() }
                    }.disabled(store.health.isBusy || store.isDemo || !store.health.enabled)
                    Toggle("Use Apple Watch for workouts", isOn: Binding(get: { store.data.preferences.automaticWatchTracking ?? false }, set: { enabled in
                        _ = store.commit { $0.preferences.automaticWatchTracking = enabled }
                        if enabled { Task { await store.health.authorize(); store.watch.refresh() } }
                    })).disabled(store.isDemo || !store.health.enabled)
                    Text(store.watch.connectionMessage).font(.subheadline)
                    Text("Install Gym Log on your Apple Watch and open it once to connect Health. Start and Finish on your iPhone then control Watch recording. Your Watch records heart rate and estimated active calories and saves the workout to Apple Health. Resting heart rate and HRV remain read-only trends.").font(.caption)
                    if store.watch.hasUnfinishedDelivery {
                        Text("A Watch workout is still waiting to finish. Keep the devices nearby, or end recording in Gym Log on your Watch.").font(.caption).foregroundStyle(.orange)
                        Button("Retry Watch connection") { store.watch.refresh() }
                    }
                }
                Section {
                    Button("Export JSON backup", systemImage: "square.and.arrow.up") { export() }
                    Button("Import JSON backup", systemImage: "square.and.arrow.down") { importPicker = true }
                } header: { Text("Backup & restore") } footer: {
                    Text("Exports include your plan, preferences, unfinished workout, history and attached health summaries. Save a copy outside this app, such as Files on your iPhone or AirDrop to your Mac. Import replaces current data after confirmation. Deleting the app deletes its local database.")
                }
                Section("Exercise library") {
                    Link("ExerciseDB · powered by AscendAPI", destination: URL(string: "https://ascendapi.com")!)
                    Text("Search, filters, instructions and animations come from ExerciseDB. Downloads are cached for one hour. Saved routines and history work offline.").font(.caption).foregroundStyle(.secondary)
                    Text("Exercise searches are sent to ExerciseDB. Your workout history and Apple Health data are not sent.").font(.caption).foregroundStyle(.secondary)
                    Button("Clear downloaded exercises") { Task { await ExerciseCatalog.shared.clearCache() } }
                    Text("Clearing downloads keeps your routines and workout history.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Try Gym Log") {
                    Button("Open temporary sample mode") { demo = true }.disabled(store.isDemo)
                    Text("Eight weeks of sample workouts and Watch charts. Real data stays separate.").font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    Button("Reset all local data", role: .destructive) { resetConfirmation = true }
                } footer: {
                    Text("Free signing typically expires after seven days. Rebuild using the same bundle identifier and team without deleting the installed app. Keep an external JSON backup.")
                }
            }.navigationTitle("Settings")
                .sheet(isPresented: $calculator) { PlateCalculatorView(unit: store.unit) }
                .sheet(isPresented: $editPlan) { PlanEditor() }
                .sheet(isPresented: $sharing, onDismiss: cleanExport) { if let shareURL { ShareSheet(file: shareURL) } }
                .sheet(isPresented: $demo) { DemoSheet() }
                .fileImporter(isPresented: $importPicker, allowedContentTypes: [.json]) { result in
                    do {
                        let url = try result.get()
                        let access = url.startAccessingSecurityScopedResource()
                        defer { if access { url.stopAccessingSecurityScopedResource() } }
                        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                        guard size <= 50_000_000 else { throw BackupError.invalid("Backup is larger than 50 MB.") }
                        pendingImport = try Backup.decode(Data(contentsOf: url))
                    } catch { store.errorMessage = "Could not import: \(error.localizedDescription)" }
                }
                .alert("Replace current data?", isPresented: Binding(get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } })) {
                    Button("Replace and restore", role: .destructive) {
                        if let pendingImport {
                            store.importBackup(pendingImport)
                            if store.errorMessage == nil { importMessage = "Restored \(pendingImport.sessions.count) workouts and your plan." }
                        }
                        pendingImport = nil
                    }
                    Button("Cancel", role: .cancel) { pendingImport = nil }
                } message: { Text("This backup contains \(pendingImport?.sessions.count ?? 0) workouts. Export your current log first if you need to keep it.") }
                .alert("Backup restored", isPresented: Binding(get: { importMessage != nil }, set: { if !$0 { importMessage = nil } })) {
                    Button("OK") { importMessage = nil }
                } message: { Text(importMessage ?? "") }
                .alert("Reset all data?", isPresented: $resetConfirmation) {
                    Button("Reset", role: .destructive) { store.reset() }
                    Button("Cancel", role: .cancel) {}
                } message: { Text("Deletes local workouts and routines, clears saved exercises, and resets settings. Export a backup first. Apple Health data is never deleted.") }
        }
    }
    private func export() {
        do {
            var backup = store.data
            backup.exportedAt = .now
            let data = try backup.encoded()
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("LiftLog-backup.json")
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            shareURL = url; sharing = true
        } catch { store.errorMessage = "Could not export: \(error.localizedDescription)" }
    }
    private func cleanExport() {
        if let shareURL { try? FileManager.default.removeItem(at: shareURL.deletingLastPathComponent()) }
        shareURL = nil
    }
}

struct DemoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store: AppStore?
    @State private var error: String?
    var body: some View {
        VStack(spacing: 0) {
            HStack { Text("Sample mode").font(.headline); Spacer(); Button("Close") { dismiss() } }.padding()
            if let store { RootView().environment(store) }
            else if let error { Text(error) }
            else { ProgressView() }
        }.task {
            guard store == nil else { return }
            do { store = try AppStore(inMemory: true, demo: true) }
            catch { self.error = error.localizedDescription }
        }
    }
}
