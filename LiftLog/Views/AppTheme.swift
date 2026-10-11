import SwiftUI

/// Semantic colors resolve with appearance; views keep their identity when preferences change.
struct AppTheme {
    var design: DesignTheme = .studio
    private func color(_ light: UInt, _ dark: UInt) -> Color {
        Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, alpha: 1)
        })
    }
    var canvas: Color { design == .studio ? color(0xF5F2E9, 0x1C211B) : color(0xF1F3F8, 0x10151F) }
    var surface: Color { design == .studio ? color(0xE7E5D9, 0x2B3328) : color(0xE3E8F2, 0x1D2738) }
    var text: Color { design == .studio ? color(0x283529, 0xF1F3E6) : color(0x101B30, 0xEDF2FF) }
    var secondary: Color { design == .studio ? color(0x5C6658, 0xB9C3AE) : color(0x515E72, 0xB0BED4) }
    var divider: Color { design == .studio ? color(0xC8CCBC, 0x475140) : color(0xC6CCDA, 0x354056) }
    var action: Color { design == .studio ? color(0x354C27, 0xD6EF81) : color(0x234BDB, 0x9BB8FF) }
    var onAction: Color { design == .studio ? color(0xF6F8ED, 0x26331C) : color(0xFFFFFF, 0x101B30) }
    var selected: Color { design == .studio ? color(0xE1EDBB, 0x3A4629) : color(0xDCE6FF, 0x273C65) }
    var error: Color { design == .studio ? color(0xA62331, 0xFFB0B4) : color(0xAE253D, 0xFFADB9) }
    var heading: Font { .system(.title2, design: design == .studio ? .serif : .default, weight: .semibold) }
    static let panelRadius: CGFloat = 18
    static let controlRadius: CGFloat = 12
    static let panelPadding: CGFloat = 14
}
private struct AppThemeKey: EnvironmentKey { static let defaultValue = AppTheme() }
extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}
private struct StudioScreen: ViewModifier {
    @Environment(\.appTheme) private var theme
    func body(content: Content) -> some View {
        content.scrollContentBackground(.hidden).background(theme.canvas).tint(theme.action)
            .foregroundStyle(theme.text).navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(theme.canvas, for: .navigationBar)
            .toolbarBackground(theme.canvas, for: .tabBar)
    }
}
extension View { func studioScreen() -> some View { modifier(StudioScreen()) } }
