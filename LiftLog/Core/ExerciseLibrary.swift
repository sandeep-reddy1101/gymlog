import Foundation

enum Equipment: String, Codable, CaseIterable, Identifiable {
    case dumbbell = "Dumbbell", barbell = "Barbell", cable = "Cable", machine = "Machine"
    case bodyweight = "Bodyweight", kettlebell = "Kettlebell", band = "Resistance band", other = "Other"
    var id: String { rawValue }
}

enum MuscleGroup: String, CaseIterable, Identifiable {
    case chest = "Chest", back = "Back", shoulders = "Shoulders", biceps = "Biceps", triceps = "Triceps"
    case quads = "Quads", hamstrings = "Hamstrings", glutes = "Glutes", calves = "Calves"
    case core = "Core", forearms = "Forearms", adductors = "Inner thighs", fullBody = "Full body"
    var id: String { rawValue }
    func matches(_ text: String) -> Bool {
        let terms: [String]
        switch self {
        case .back: terms = ["back", "lats", "traps"]
        case .shoulders: terms = ["shoulder", "delt"]
        case .core: terms = ["core", "abs", "oblique"]
        default: terms = [rawValue.lowercased()]
        }
        return terms.contains { text.localizedCaseInsensitiveContains($0) }
    }
}

enum ExerciseLibrary {
    // IDs are explicit and permanent. Append new entries; never reuse a number.
    // Legacy/sample fixtures only. Live browsing uses ExerciseCatalog; never seed these on install/import.
    static let catalog: [ExerciseRecord] = {
        var result: [ExerciseRecord] = []
        func add(_ number: Int, _ name: String, _ muscle: String, _ equipment: Equipment,
                 bodyweight: Bool = false, aliases: [String] = []) {
            let suffix = String(format: "%012d", number)
            result.append(ExerciseRecord(id: UUID(uuidString: "E7E2C100-0000-4000-8000-\(suffix)")!,
                                         name: name, muscle: muscle, isBodyweight: bodyweight,
                                         equipment: equipment, aliases: aliases, catalogKey: "exercise-\(number)"))
        }
        add(1, "Incline DB press", "Chest", .dumbbell, aliases: ["Incline dumbbell bench press"])
        add(2, "Flat DB press", "Chest", .dumbbell, aliases: ["Dumbbell bench press", "Flat dumbbell press"])
        add(3, "DB shoulder press", "Shoulders", .dumbbell, aliases: ["Dumbbell overhead press", "Dumbbell military press"])
        add(4, "Lateral raises", "Side delts", .dumbbell, aliases: ["Dumbbell lateral raise", "Side raise"])
        add(5, "DB fly", "Chest", .dumbbell, aliases: ["Dumbbell fly", "Dumbbell flyes"])
        add(6, "Overhead DB extension", "Triceps", .dumbbell, aliases: ["Dumbbell overhead triceps extension"])
        add(7, "Pull-ups", "Lats", .bodyweight, bodyweight: true, aliases: ["Pull up", "Pullup"])
        add(8, "Chest-supported incline row", "Back", .dumbbell, aliases: ["Chest supported dumbbell row"])
        add(9, "DB row", "Lats", .dumbbell, aliases: ["One arm dumbbell row", "Single arm row"])
        add(10, "Rear delt reverse fly", "Rear delts", .dumbbell, aliases: ["Reverse dumbbell fly", "Rear delt fly"])
        add(11, "Seated incline curl", "Biceps", .dumbbell, aliases: ["Incline dumbbell curl"])
        add(12, "Seated incline hammer curl", "Biceps", .dumbbell, aliases: ["Incline dumbbell hammer curl"])
        add(13, "DB shrug", "Traps", .dumbbell, aliases: ["DB shrug (optional)", "Dumbbell shrug"])
        add(14, "Goblet squat", "Quads, glutes", .dumbbell)
        add(15, "DB Romanian deadlift", "Hamstrings, glutes", .dumbbell, aliases: ["Dumbbell RDL"])
        add(16, "Bulgarian split squat", "Quads, glutes", .dumbbell, aliases: ["Rear foot elevated split squat"])
        add(17, "Single-leg DB RDL", "Hamstrings, glutes", .dumbbell, aliases: ["Single leg dumbbell Romanian deadlift"])
        add(18, "DB step-ups", "Quads, glutes", .dumbbell, aliases: ["Dumbbell step up"])
        add(19, "Single-leg calf raise", "Calves", .dumbbell)
        add(20, "Bent-over row", "Back", .dumbbell, aliases: ["Bent over dumbbell row"])
        add(21, "DB hip thrust", "Glutes", .dumbbell, aliases: ["Dumbbell hip thrust"])
        add(22, "DB walking lunges", "Quads, glutes", .dumbbell, aliases: ["Dumbbell walking lunge"])
        add(23, "Dumbbell curl", "Biceps", .dumbbell, aliases: ["DB curl", "Biceps curl"])
        add(24, "Hammer curl", "Biceps, forearms", .dumbbell)
        add(25, "Concentration curl", "Biceps", .dumbbell)
        add(26, "Dumbbell preacher curl", "Biceps", .dumbbell)
        add(27, "Dumbbell triceps kickback", "Triceps", .dumbbell)
        add(28, "Dumbbell skull crusher", "Triceps", .dumbbell, aliases: ["Lying triceps extension"])
        add(29, "Arnold press", "Shoulders", .dumbbell)
        add(30, "Dumbbell front raise", "Shoulders", .dumbbell)
        add(31, "Dumbbell pullover", "Chest, lats", .dumbbell)
        add(32, "Dumbbell floor press", "Chest, triceps", .dumbbell)
        add(33, "Dumbbell squeeze press", "Chest", .dumbbell)
        add(34, "Dumbbell reverse lunge", "Quads, glutes", .dumbbell)
        add(35, "Dumbbell lateral lunge", "Quads, glutes", .dumbbell)
        add(36, "Dumbbell sumo squat", "Quads, glutes", .dumbbell)
        add(37, "Dumbbell deadlift", "Hamstrings, glutes", .dumbbell)
        add(38, "Dumbbell wrist curl", "Forearms", .dumbbell)
        add(39, "Dumbbell reverse wrist curl", "Forearms", .dumbbell)
        add(40, "Dumbbell reverse curl", "Biceps, forearms", .dumbbell)
        add(41, "Barbell bench press", "Chest", .barbell, aliases: ["Flat bench press"])
        add(42, "Incline barbell bench press", "Chest", .barbell)
        add(43, "Decline barbell bench press", "Chest", .barbell)
        add(44, "Close-grip bench press", "Triceps, chest", .barbell)
        add(45, "Barbell overhead press", "Shoulders", .barbell, aliases: ["Military press", "OHP"])
        add(46, "Barbell bent-over row", "Back", .barbell)
        add(47, "Pendlay row", "Back", .barbell)
        add(48, "Landmine row", "Back", .barbell, aliases: ["T bar row"])
        add(49, "Barbell shrug", "Traps", .barbell)
        add(50, "Barbell back squat", "Quads, glutes", .barbell, aliases: ["Back squat"])
        add(51, "Front squat", "Quads, glutes", .barbell)
        add(52, "Conventional deadlift", "Hamstrings, glutes, back", .barbell, aliases: ["Barbell deadlift"])
        add(53, "Sumo deadlift", "Glutes, hamstrings", .barbell)
        add(54, "Barbell Romanian deadlift", "Hamstrings, glutes", .barbell, aliases: ["Barbell RDL"])
        add(55, "Good morning", "Hamstrings, glutes, back", .barbell)
        add(56, "Barbell hip thrust", "Glutes", .barbell)
        add(57, "Barbell glute bridge", "Glutes", .barbell)
        add(58, "Barbell split squat", "Quads, glutes", .barbell)
        add(59, "Barbell curl", "Biceps", .barbell)
        add(60, "EZ-bar curl", "Biceps", .barbell)
        add(61, "EZ-bar preacher curl", "Biceps", .barbell)
        add(62, "EZ-bar skull crusher", "Triceps", .barbell)
        add(63, "Landmine press", "Shoulders, chest", .barbell)
        add(64, "Cable chest fly", "Chest", .cable, aliases: ["Cable crossover"])
        add(65, "Low-to-high cable fly", "Chest", .cable)
        add(66, "High-to-low cable fly", "Chest", .cable)
        add(67, "Cable chest press", "Chest", .cable)
        add(68, "Seated cable row", "Back", .cable)
        add(69, "Single-arm cable row", "Back", .cable)
        add(70, "Lat pulldown", "Lats", .cable)
        add(71, "Close-grip lat pulldown", "Lats", .cable)
        add(72, "Reverse-grip lat pulldown", "Lats, biceps", .cable)
        add(73, "Straight-arm pulldown", "Lats", .cable)
        add(74, "Cable face pull", "Rear delts, back", .cable, aliases: ["Face pulls"])
        add(75, "Cable lateral raise", "Side delts", .cable)
        add(76, "Cable rear delt fly", "Rear delts", .cable)
        add(77, "Cable curl", "Biceps", .cable)
        add(78, "Cable hammer curl", "Biceps, forearms", .cable)
        add(79, "Triceps rope pushdown", "Triceps", .cable, aliases: ["Rope pressdown"])
        add(80, "Straight-bar triceps pushdown", "Triceps", .cable)
        add(81, "Cable overhead triceps extension", "Triceps", .cable)
        add(82, "Cable glute kickback", "Glutes", .cable)
        add(83, "Cable pull-through", "Glutes, hamstrings", .cable)
        add(84, "Cable crunch", "Core", .cable)
        add(85, "Cable woodchop", "Core, obliques", .cable)
        add(86, "Pallof press", "Core", .cable)
        add(87, "Machine chest press", "Chest", .machine)
        add(88, "Machine incline chest press", "Chest", .machine)
        add(89, "Pec deck fly", "Chest", .machine, aliases: ["Butterfly machine"])
        add(90, "Machine shoulder press", "Shoulders", .machine)
        add(91, "Machine lateral raise", "Side delts", .machine)
        add(92, "Reverse pec deck", "Rear delts", .machine)
        add(93, "Machine seated row", "Back", .machine)
        add(94, "Machine high row", "Back, lats", .machine)
        add(95, "Machine pullover", "Lats", .machine)
        add(96, "Leg press", "Quads, glutes", .machine)
        add(97, "Hack squat", "Quads, glutes", .machine)
        add(98, "Belt squat", "Quads, glutes", .machine)
        add(99, "Leg extension", "Quads", .machine)
        add(100, "Seated leg curl", "Hamstrings", .machine)
        add(101, "Lying leg curl", "Hamstrings", .machine)
        add(102, "Standing leg curl", "Hamstrings", .machine)
        add(103, "Hip abduction machine", "Glutes", .machine)
        add(104, "Hip adduction machine", "Inner thighs", .machine)
        add(105, "Standing calf raise machine", "Calves", .machine)
        add(106, "Seated calf raise machine", "Calves", .machine)
        add(107, "Calf press on leg press", "Calves", .machine)
        add(108, "Machine preacher curl", "Biceps", .machine)
        add(109, "Machine triceps extension", "Triceps", .machine)
        add(110, "Machine abdominal crunch", "Core", .machine)
        add(111, "Smith machine squat", "Quads, glutes", .machine)
        add(112, "Smith machine bench press", "Chest", .machine)
        add(113, "Smith machine incline press", "Chest", .machine)
        add(114, "Smith machine hip thrust", "Glutes", .machine)
        add(115, "Chin-ups", "Lats, biceps", .bodyweight, bodyweight: true, aliases: ["Chin up", "Chinup"])
        add(116, "Neutral-grip pull-up", "Lats, biceps", .bodyweight, bodyweight: true)
        add(117, "Push-ups", "Chest, triceps", .bodyweight, bodyweight: true, aliases: ["Push up", "Pushup"])
        add(118, "Incline push-up", "Chest, triceps", .bodyweight, bodyweight: true)
        add(119, "Decline push-up", "Chest, triceps", .bodyweight, bodyweight: true)
        add(120, "Diamond push-up", "Triceps, chest", .bodyweight, bodyweight: true)
        add(121, "Parallel-bar dip", "Chest, triceps", .bodyweight, bodyweight: true, aliases: ["Dips"])
        add(122, "Inverted row", "Back", .bodyweight, bodyweight: true, aliases: ["Bodyweight row"])
        add(123, "Bodyweight squat", "Quads, glutes", .bodyweight, bodyweight: true, aliases: ["Air squat"])
        add(124, "Bodyweight reverse lunge", "Quads, glutes", .bodyweight, bodyweight: true)
        add(125, "Bodyweight split squat", "Quads, glutes", .bodyweight, bodyweight: true)
        add(126, "Glute bridge", "Glutes", .bodyweight, bodyweight: true)
        add(127, "Single-leg glute bridge", "Glutes", .bodyweight, bodyweight: true)
        add(128, "Bodyweight calf raise", "Calves", .bodyweight, bodyweight: true)
        add(129, "Crunch", "Core", .bodyweight, bodyweight: true)
        add(130, "Reverse crunch", "Core", .bodyweight, bodyweight: true)
        add(131, "Bicycle crunch", "Core, obliques", .bodyweight, bodyweight: true)
        add(132, "Hanging knee raise", "Core", .bodyweight, bodyweight: true)
        add(133, "Hanging leg raise", "Core", .bodyweight, bodyweight: true)
        add(134, "Lying leg raise", "Core", .bodyweight, bodyweight: true)
        add(135, "Dead bug", "Core", .bodyweight, bodyweight: true)
        add(136, "Bird dog", "Core", .bodyweight, bodyweight: true)
        add(137, "Back extension", "Back, glutes, hamstrings", .bodyweight, bodyweight: true)
        add(138, "Kettlebell swing", "Glutes, hamstrings", .kettlebell)
        add(139, "Kettlebell goblet squat", "Quads, glutes", .kettlebell)
        add(140, "Kettlebell deadlift", "Hamstrings, glutes", .kettlebell)
        add(141, "Kettlebell clean", "Full body", .kettlebell)
        add(142, "Kettlebell press", "Shoulders", .kettlebell)
        add(143, "Kettlebell row", "Back", .kettlebell)
        add(144, "Kettlebell Turkish get-up", "Full body, core", .kettlebell)
        add(145, "Band pull-apart", "Rear delts, back", .band)
        add(146, "Band row", "Back", .band)
        add(147, "Band chest press", "Chest", .band)
        add(148, "Band overhead press", "Shoulders", .band)
        add(149, "Band curl", "Biceps", .band)
        add(150, "Band triceps extension", "Triceps", .band)
        add(151, "Band lateral raise", "Side delts", .band)
        add(152, "Band glute kickback", "Glutes", .band)
        add(153, "Band lateral walk", "Glutes", .band)
        add(154, "Band face pull", "Rear delts, back", .band)
        add(155, "Ab wheel rollout", "Core", .other, bodyweight: true)
        add(156, "Medicine ball Russian twist", "Core, obliques", .other)
        add(157, "Trap bar deadlift", "Quads, glutes, hamstrings", .other, aliases: ["Hex bar deadlift"])
        return result
    }()

    static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: " ")
    }

    static func filtered(_ exercises: [ExerciseRecord], search: String, muscle: MuscleGroup?, equipment: Equipment?) -> [ExerciseRecord] {
        let tokens = normalized(search).split(separator: " ")
        return exercises.filter { exercise in
            if let equipment, exercise.equipment != equipment { return false }
            if let muscle, !muscle.matches(exercise.muscle) { return false }
            let searchable = normalized(([exercise.name, exercise.muscle, exercise.equipment?.rawValue ?? ""] + (exercise.aliases ?? [])).joined(separator: " "))
            return tokens.allSatisfy { searchable.contains($0) }
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    // Upgrade old libraries without changing routine membership, snapshots, or IDs.
    static func mergingCatalog(into exercises: [ExerciseRecord]) -> [ExerciseRecord] {
        var result = exercises
        for item in catalog {
            if result.contains(where: { $0.catalogKey == item.catalogKey || $0.id == item.id }) { continue }
            let names = ([item.name] + (item.aliases ?? [])).map(normalized)
            if let index = result.firstIndex(where: { $0.catalogKey == nil && names.contains(normalized($0.name)) }) {
                result[index].catalogKey = item.catalogKey
                if result[index].equipment == nil { result[index].equipment = item.equipment }
                result[index].aliases = Array(Set((result[index].aliases ?? []) + (item.aliases ?? []))).sorted()
            } else { result.append(item) }
        }
        return result
    }

    static func adding(_ ids: [UUID], to day: DayRecord) -> DayRecord {
        var next = day
        for id in ids where !next.exerciseIDs.contains(id) { next.exerciseIDs.append(id) }
        return next
    }
}
