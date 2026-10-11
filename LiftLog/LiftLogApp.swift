import SwiftUI

@main struct LiftLogApp: App {
    @State private var store: AppStore?
    @State private var launchError: String?

    var body: some Scene {
        WindowGroup {
            Group {
                if let store { RootView().environment(store) }
                else if let launchError {
                    ContentUnavailableView("Couldn’t open Gym Log", systemImage: "externaldrive.badge.exclamationmark",
                                           description: Text("Your local files have not been reset.\n\(launchError)\nRestart the app or consult the setup guide."))
                } else { ProgressView("Opening your log…") }
            }
            .task {
                guard store == nil && launchError == nil else { return }
                do {
                    let demo = ProcessInfo.processInfo.arguments.contains("--demo")
                    store = try AppStore(inMemory: demo, demo: demo)
                } catch { launchError = error.localizedDescription }
            }
        }
    }
}
