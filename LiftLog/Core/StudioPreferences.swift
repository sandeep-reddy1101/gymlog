import Foundation

enum DesignTheme: String, CaseIterable, Identifiable {
    case studio, velocity
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

extension Preferences {
    var resolvedTheme: DesignTheme { DesignTheme(rawValue: designTheme ?? "") ?? .studio }
    var resolvedAppearance: AppAppearance { AppAppearance(rawValue: appearance ?? "") ?? .system }
}

/// Unfinished text input is kept in memory across navigation, keyed by the stable set ID.
/// The baseline prevents old text overriding an undo, history edit, or unit change.
struct SetEntryDraft: Equatable {
    var weight: String
    var reps: String
    var baseline: LoggedSet
    var unit: WeightUnit
    var isValid: Bool
    func applies(to set: LoggedSet, unit: WeightUnit) -> Bool { baseline == set && self.unit == unit }
}
