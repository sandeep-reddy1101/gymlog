import Foundation
import ImageIO

/// Keep each source frame's own delay; summing delays into UIImage.animationDuration
/// would distribute that duration evenly and remove deliberate holds.
struct ExerciseAnimation {
    let frames: [CGImage]
    let delays: [TimeInterval]
    let width: Int
    let height: Int

    static func decode(_ data: Data) -> ExerciseAnimation? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        guard (1...300).contains(count) else { return nil }
        var frames: [CGImage] = []; var delays: [TimeInterval] = []
        var width = 0; var height = 0; var pixels = 0
        for index in 0..<count {
            guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
                  let w = properties[kCGImagePropertyPixelWidth] as? Int,
                  let h = properties[kCGImagePropertyPixelHeight] as? Int,
                  (1...2048).contains(w), (1...2048).contains(h) else { return nil }
            pixels += w * h
            guard pixels <= 20_000_000, let frame = CGImageSourceCreateImageAtIndex(source, index, nil) else { return nil }
            let gif = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            let delay = gif?[kCGImagePropertyGIFUnclampedDelayTime] as? Double ?? gif?[kCGImagePropertyGIFDelayTime] as? Double ?? 0.1
            delays.append(delay.isFinite && delay > 0 ? max(0.02, delay) : 0.1)
            frames.append(frame); width = max(width, w); height = max(height, h)
        }
        return ExerciseAnimation(frames: frames, delays: delays, width: width, height: height)
    }
}

struct ExercisePlayback: Equatable {
    var frame = 0
    var speed = 0.5
    var playing = false
    mutating func step(_ delta: Int, count: Int) {
        playing = false
        frame = min(max(0, count - 1), max(0, frame + delta))
    }
    mutating func toggle(count: Int) {
        guard count > 1 else { return }
        if !playing && frame == count - 1 { frame = 0 }
        playing.toggle()
    }
    mutating func advance(count: Int) {
        guard playing else { return }
        if frame < count - 1 { frame += 1 }
        else { playing = false }
    }
    func delay(_ sourceDelay: TimeInterval) -> TimeInterval {
        sourceDelay / (speed.isFinite && speed > 0 ? speed : 0.5)
    }
}
