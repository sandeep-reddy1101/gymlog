import Foundation

struct ExerciseGuide: Identifiable {
    enum Illustration { case gobletSquat, dumbbellCurl }
    var id: String
    var title: String
    var primaryMuscles: String
    var supportingMuscles: String?
    var setup: String
    var cues: [String]
    var avoid: String
    var logging: String
    var positions: [String]
    var illustration: Illustration
    var sourceName: String
    var sourceURL: URL

    static func guide(for exercise: ExerciseRecord) -> ExerciseGuide? {
        // Don't attach a catalog guide to a renamed or repurposed custom entry.
        samples.first { $0.id == exercise.catalogKey && $0.title == exercise.name && exercise.equipment == .dumbbell }
    }
    static let samples: [ExerciseGuide] = [
        ExerciseGuide(id: "exercise-14", title: "Goblet squat", primaryMuscles: "Quadriceps · Glutes",
                      supportingMuscles: "Core · Hip stabilizers",
                      setup: "Stand in a comfortable squat stance. Hold one dumbbell vertically close to your chest, with both hands supporting its upper end.",
                      cues: ["Brace your trunk and lower by bending at your hips and knees.",
                             "Keep the weight close and your knees tracking in the direction of your toes. Use a depth you can control.",
                             "Push through your feet to return to standing, keeping your torso steady."],
                      avoid: "Avoid letting your knees collapse inward or the weight pull your chest forward.",
                      logging: "Log the weight of the single dumbbell. One descent and return equals one rep.",
                      positions: ["Stand tall", "Lower with control"], illustration: .gobletSquat,
                      sourceName: "NASM · Goblet squat", sourceURL: URL(string: "https://www.nasm.org/resource-center/exercise-library/goblet-squat")!),
        ExerciseGuide(id: "exercise-23", title: "Dumbbell curl", primaryMuscles: "Biceps",
                      supportingMuscles: nil,
                      setup: "Stand tall with a dumbbell in each hand, arms down and palms facing forward. Keep your elbows close to your sides.",
                      cues: ["Bend your elbows to raise the weights smoothly toward your shoulders.",
                             "Keep your wrists straight and your upper arms still.",
                             "Lower slowly back to the start before the next rep."],
                      avoid: "Avoid swinging your torso or moving your elbows forward to lift the weight.",
                      logging: "Log one dumbbell’s weight. Count reps per arm consistently, whether curling together or alternating.",
                      positions: ["Arms lowered", "Curl smoothly"], illustration: .dumbbellCurl,
                      sourceName: "Mayo Clinic · Dumbbell biceps curl", sourceURL: URL(string: "https://www.mayoclinic.org/healthy-lifestyle/fitness/multimedia/biceps-curl/vid-20084675")!)
    ]
}
