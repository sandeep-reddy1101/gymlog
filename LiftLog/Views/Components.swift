import SwiftUI

struct ActionButtonStyle: ButtonStyle {
    @Environment(\.appTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundStyle(isEnabled ? theme.onAction : theme.secondary)
            .background(isEnabled ? theme.action : theme.surface, in: RoundedRectangle(cornerRadius: AppTheme.controlRadius))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .contentShape(RoundedRectangle(cornerRadius: AppTheme.controlRadius))
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.appTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.subheadline.weight(.medium))
            .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12).frame(minHeight: 44)
            .foregroundStyle(isEnabled ? theme.action : theme.secondary)
            .background(theme.selected, in: RoundedRectangle(cornerRadius: AppTheme.controlRadius))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

extension DayType {
    var color: Color {
        Color(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255)
    }
}

struct Panel<Content: View>: View {
    @Environment(\.appTheme) private var theme
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) { content }
            .padding(AppTheme.panelPadding).frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: AppTheme.panelRadius))
    }
}

struct SetProgress: View {
    @Environment(\.appTheme) private var theme
    var completed: Int
    var total: Int
    var color: Color
    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.15), lineWidth: 10)
            Circle().trim(from: 0, to: total == 0 ? 0 : CGFloat(completed) / CGFloat(total))
                .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .round)).rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(completed)").font(.title.bold()).monospacedDigit()
                Text("of \(total)").font(.caption).foregroundStyle(theme.secondary)
            }
        }
        .frame(width: 96, height: 96)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(completed) of \(total) sets complete")
        .animation(.easeOut(duration: 0.2), value: completed)
    }
}

struct RootView: View {
    @Environment(\.appTheme) private var theme
    // Session-only navigation: backgrounding preserves selection; a fresh process starts at Today.
    @State private var selectedTab = 0
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        @Bindable var store = store
        VStack(spacing: 0) {
            if let undo = store.pendingUndo {
                HStack(spacing: 12) {
                    Text(undo.title).font(.subheadline)
                    Spacer()
                    Button("Undo") { store.undoLastAction() }.font(.subheadline.bold()).disabled(!store.editingSets.isEmpty)
                    Button { store.pendingUndo = nil } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }.accessibilityLabel("Dismiss undo")
                }.padding(.leading, 16).background(.regularMaterial)
            }
            if store.isDemo {
                Text("SAMPLE MODE · Changes are temporary").font(.caption.bold())
                    .frame(maxWidth: .infinity).padding(6).background(.yellow.opacity(0.25))
            }
            TabView(selection: $selectedTab) {
                TodayView().tabItem { Label("Train", systemImage: "dumbbell.fill") }.tag(0)
                ProgressScreen().tabItem { Label("Progress", systemImage: "chart.xyaxis.line") }.tag(1)
                HistoryView().tabItem { Label("History", systemImage: "clock.arrow.circlepath") }.tag(2)
                SettingsView().tabItem { Label("Settings", systemImage: "gearshape") }.tag(3)
            }
        }
        .environment(\.appTheme, AppTheme(design: store.data.preferences.resolvedTheme))
        .tint(AppTheme(design: store.data.preferences.resolvedTheme).action)
        .preferredColorScheme(store.data.preferences.resolvedAppearance == .system ? nil : store.data.preferences.resolvedAppearance == .dark ? .dark : .light)
        .onChange(of: scenePhase) { _, phase in if phase == .active { store.syncRestAlerts(); store.watch.reconcile(sessions: store.data.sessions) } }
        .alert("Gym Log", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("OK") { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
    }
}

#Preview("Sample app") {
    PreviewHost()
}

struct PreviewHost: View {
    @Environment(\.appTheme) private var theme
    private let store = try? AppStore(inMemory: true, demo: true)
    var body: some View {
        if let store { RootView().environment(store) }
        else { Text("Sample store could not load.") }
    }
}

struct SectionIntro: View {
    @Environment(\.appTheme) private var theme
    var eyebrow: String
    var title: String
    var detail: String
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(eyebrow).font(.caption.weight(.semibold)).tracking(2).foregroundStyle(theme.secondary)
            Text(title).font(theme.heading)
            Text(detail).font(.subheadline).foregroundStyle(theme.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 4)
    }
}
