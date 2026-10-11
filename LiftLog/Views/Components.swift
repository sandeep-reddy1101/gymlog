import SwiftUI

enum AppColors {
    static let coral = Color(red: 1, green: 0.42, blue: 0.37)
    static let buttonInk = Color(red: 0.10, green: 0.07, blue: 0.07)
    static let action = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1, green: 0.57, blue: 0.53, alpha: 1)
            : UIColor(red: 0.66, green: 0.16, blue: 0.13, alpha: 1)
    })
}

/// Specify both sides of the contrast pair; `.primary` as a tint can produce
/// a white background with a white system button label in dark appearance.
struct ActionButtonStyle: ButtonStyle {
    var fill: Color = AppColors.coral
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundStyle(isEnabled ? AppColors.buttonInk : Color(uiColor: .secondaryLabel))
            .background(isEnabled ? fill : Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                if configuration.isPressed && isEnabled {
                    RoundedRectangle(cornerRadius: 16).fill(.black.opacity(0.08))
                        .allowsHitTesting(false)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 16))
    }
}

extension DayType {
    var color: Color {
        Color(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255)
    }
}

struct Panel<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) { content }
            .padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.primary.opacity(0.05), lineWidth: 1))
    }
}

struct SetProgress: View {
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
                Text("of \(total)").font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(width: 96, height: 96)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(completed) of \(total) sets complete")
        .animation(.easeOut(duration: 0.2), value: completed)
    }
}

struct RootView: View {
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
                TodayView().tabItem { Label("Today", systemImage: "dumbbell.fill") }.tag(0)
                ProgressScreen().tabItem { Label("Progress", systemImage: "chart.xyaxis.line") }.tag(1)
                HistoryView().tabItem { Label("History", systemImage: "clock.arrow.circlepath") }.tag(2)
                SettingsView().tabItem { Label("Settings", systemImage: "gearshape") }.tag(3)
            }
        }
        .tint(AppColors.action)
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
    private let store = try? AppStore(inMemory: true, demo: true)
    var body: some View {
        if let store { RootView().environment(store) }
        else { Text("Sample store could not load.") }
    }
}

struct SectionIntro: View {
    var eyebrow: String
    var title: String
    var detail: String
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(eyebrow).font(.caption.weight(.semibold)).tracking(2).foregroundStyle(.secondary)
            Text(title).font(.title2.bold())
            Text(detail).font(.subheadline).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 4)
    }
}
