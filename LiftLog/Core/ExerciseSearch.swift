import Foundation

/// Search language only: all exercise names and available equipment still come from the API.
enum ExerciseSearch {
    static func words(_ value: String) -> [String] {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.map {
                switch $0 {
                case "db", "dumbbells": return "dumbbell"
                case "bb", "barbells": return "barbell"
                case "rows": return "row"
                case "presses": return "press"
                case "curls": return "curl"
                case "raises": return "raise"
                case "squats": return "squat"
                case "lunges": return "lunge"
                case "pullups": return "pullup"
                default: return $0
                }
            }
    }
    static func matches(_ name: String, query: String) -> Bool {
        let requested = words(query)
        let actual = Set(words(name))
        return requested.allSatisfy { actual.contains($0) }
    }
    static func rank(_ name: String, query: String) -> Int {
        let requested = words(query); let actual = words(name)
        if actual == requested { return 0 }
        if actual.starts(with: requested) { return 1 }
        if actual.joined(separator: " ").contains(requested.joined(separator: " ")) { return 2 }
        return 3 + max(0, actual.count - requested.count)
    }
    static func sorted(_ exercises: [CatalogExercise], query: String) -> [CatalogExercise] {
        exercises.filter { matches($0.name, query: query) }.sorted {
            let first = rank($0.name, query: query); let second = rank($1.name, query: query)
            if first != second { return first < second }
            if $0.name != $1.name { return $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            return $0.id < $1.id
        }
    }
    static func providerQuery(_ query: CatalogQuery, equipments: [String]) -> CatalogQuery {
        var result = query
        var tokens = words(query.name)
        guard !tokens.isEmpty else { return result }
        // Use live equipment taxonomy, not a built-in catalog or a guessed equipment type.
        if let inferred = equipments.sorted(by: { words($0).count > words($1).count }).first(where: { equipment in
            let terms = words(equipment)
            return !terms.isEmpty && terms.allSatisfy { tokens.contains($0) }
        }) {
            if result.equipment.isEmpty { result.equipment = inferred }
            let equipmentWords = Set(words(inferred))
            tokens.removeAll { equipmentWords.contains($0) }
        }
        // A whole phrase is loosely fuzzy-matched by this API. One movement term plus
        // a strict equipment filter retrieves useful candidates; AND matching happens locally.
        let qualifiers: Set<String> = ["single", "one", "two", "arm", "leg", "over", "with", "on", "the"]
        let meaningful = tokens.filter { !qualifiers.contains($0) }
        result.name = (meaningful.isEmpty ? tokens : meaningful).sorted { $0.count > $1.count }.first ?? ""
        return result
    }
}

struct CatalogSearchPage: Sendable {
    let data: [CatalogExercise]
    let nextCursor: String?
}
