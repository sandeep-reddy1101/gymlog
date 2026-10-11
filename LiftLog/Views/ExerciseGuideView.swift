import SwiftUI
import ImageIO

struct ExerciseGuideView: View {
    @Environment(\.dismiss) private var dismiss
    let exercise: ExerciseRecord
    var body: some View {
        NavigationStack {
            ExerciseGuideContent(exercise: exercise)
                .toolbar { Button("Done") { dismiss() } }
        }
    }
}

struct ExerciseGuideContent: View {
    let exercise: ExerciseRecord
    @State private var detail: CatalogExercise?
    @State private var animation: ExerciseAnimation?
    @State private var loading = false
    @State private var error: String?
    @State private var mediaError: String?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text((detail?.name ?? exercise.name).capitalized).font(.title2.bold())
                if loading { ProgressView("Loading guide…") }
                if let animation {
                    ExerciseMotionPlayer(animation: animation, name: exercise.name)
                }
                if let mediaError {
                    Text(mediaError).font(.callout).foregroundStyle(.secondary)
                    Button("Retry animation") { Task { await loadAnimation() } }.disabled(loading)
                }
                if let detail {
                    Text("\(detail.targetMuscles.joined(separator: ", ").capitalized) · \(detail.equipments.joined(separator: ", ").capitalized)").foregroundStyle(.secondary)
                    if !detail.secondaryMuscles.isEmpty { Text("Also works: \(detail.secondaryMuscles.joined(separator: ", "))").font(.subheadline) }
                    Text("How to do it").font(.headline)
                    ForEach(Array(detail.instructions.enumerated()), id: \.offset) { _, step in Text(step).frame(maxWidth: .infinity, alignment: .leading) }
                }
                if let error {
                    Text(error).foregroundStyle(.secondary)
                    Button("Retry guide") { Task { await load() } }.disabled(loading)
                }
                Link("Exercise data & animations by AscendAPI", destination: URL(string: "https://ascendapi.com")!).font(.footnote)
            }.padding()
        }.navigationTitle("Exercise guide").navigationBarTitleDisplayMode(.inline)
            .task(id: exercise.exerciseDBID) { await load() }
    }
    private func load() async {
        guard let id = exercise.exerciseDBID else { return }
        loading = true; error = nil
        defer { loading = false }
        do {
            detail = try await ExerciseCatalog.shared.detail(id)
            try Task.checkCancellation()
            await loadAnimation()
        } catch is CancellationError {} catch { self.error = error.localizedDescription }
    }
    private func loadAnimation() async {
        guard let detail else { return }
        mediaError = nil
        do {
            let bytes = try await ExerciseCatalog.shared.animation(detail.gifUrl)
            try Task.checkCancellation()
            guard let image = ExerciseAnimation.decode(bytes) else { throw CatalogError.invalidResponse }
            animation = image
        } catch is CancellationError {} catch { mediaError = "Animation unavailable. \(error.localizedDescription)" }
    }
}

private struct ExerciseMotionPlayer: View {
    let animation: ExerciseAnimation
    let name: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var playback = ExercisePlayback()
    private struct Tick: Equatable {
        let frame: Int
        let speed: Double
        let playing: Bool
    }
    var body: some View {
        VStack(spacing: 14) {
            // Avoid stretching a 180px preview into the old 300pt-tall image.
            Image(decorative: animation.frames[playback.frame], scale: 1)
                .resizable().interpolation(.high).scaledToFit()
                .frame(maxWidth: min(CGFloat(animation.width), 300), maxHeight: 240)
                .frame(maxWidth: .infinity, minHeight: 220)
                .background(.white).clipShape(RoundedRectangle(cornerRadius: 18))
                .accessibilityLabel("\(name), frame \(playback.frame + 1) of \(animation.frames.count)")
            Text("Watch slowly, or move through the frames yourself.")
                .font(.subheadline).foregroundStyle(.secondary)
            if animation.frames.count > 1 {
                Picker("Playback speed", selection: $playback.speed) {
                    Text("¼×").tag(0.25)
                    Text("½×").tag(0.5)
                    Text("1×").tag(1.0)
                }.pickerStyle(.segmented).accessibilityLabel("Playback speed")
                Button { playback.toggle(count: animation.frames.count) } label: {
                    Label(playback.playing ? "Pause" : playback.frame == animation.frames.count - 1 ? "Replay demonstration" : "Play demonstration",
                          systemImage: playback.playing ? "pause.fill" : "play.fill")
                        .foregroundStyle(AppColors.buttonInk)
                }.buttonStyle(ActionButtonStyle())
                Slider(value: Binding(get: { Double(playback.frame) }, set: {
                    playback.playing = false; playback.frame = Int($0)
                }), in: 0...Double(animation.frames.count - 1), step: 1)
                    .accessibilityLabel("Exercise frame")
                    .accessibilityValue("\(playback.frame + 1) of \(animation.frames.count)")
                HStack {
                    Button { playback.step(-1, count: animation.frames.count) } label: {
                        Image(systemName: "backward.frame.fill").frame(minWidth: 44, minHeight: 44)
                    }.disabled(playback.frame == 0).accessibilityLabel("Previous frame")
                    Spacer()
                    Text("Frame \(playback.frame + 1) / \(animation.frames.count)").font(.caption.monospacedDigit())
                    Spacer()
                    Button { playback.step(1, count: animation.frames.count) } label: {
                        Image(systemName: "forward.frame.fill").frame(minWidth: 44, minHeight: 44)
                    }.disabled(playback.frame == animation.frames.count - 1).accessibilityLabel("Next frame")
                }
            }
            Text("Source preview: \(animation.width) × \(animation.height). Playback controls cannot add missing image detail.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .task(id: Tick(frame: playback.frame, speed: playback.speed, playing: playback.playing)) {
            guard playback.playing, scenePhase == .active else { return }
            do {
                try await Task.sleep(for: .seconds(playback.delay(animation.delays[playback.frame])))
                try Task.checkCancellation()
                playback.advance(count: animation.frames.count)
            } catch {}
        }
        .onChange(of: reduceMotion) { _, value in if value { playback.playing = false } }
        .onChange(of: scenePhase) { _, phase in if phase != .active { playback.playing = false } }
        .onDisappear { playback.playing = false }
    }
}
