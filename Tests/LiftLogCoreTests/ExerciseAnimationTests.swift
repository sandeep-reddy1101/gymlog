import XCTest
import ImageIO
import UniformTypeIdentifiers
@testable import LiftLogCore

final class ExerciseAnimationTests: XCTestCase {
    func testDecodePreservesUnequalFrameDelays() throws {
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, UTType.gif.identifier as CFString, 3, nil))
        let context = try XCTUnwrap(CGContext(data: nil, width: 2, height: 2, bitsPerComponent: 8, bytesPerRow: 8,
                                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        for (index, delay) in [0.12, 0.4, 0.2].enumerated() {
            context.setFillColor(CGColor(red: CGFloat(index) / 3, green: 0, blue: 0, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
            let frame = try XCTUnwrap(context.makeImage())
            CGImageDestinationAddImage(destination, frame, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay]] as CFDictionary)
        }
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let animation = try XCTUnwrap(ExerciseAnimation.decode(data as Data))
        XCTAssertEqual(animation.frames.count, 3)
        XCTAssertEqual(animation.width, 2)
        for (actual, expected) in zip(animation.delays, [0.12, 0.4, 0.2]) { XCTAssertEqual(actual, expected, accuracy: 0.001) }
        let player = ExercisePlayback()
        XCTAssertEqual(player.delay(animation.delays[1]), 0.8, accuracy: 0.001)
    }
    func testStartsPausedAtHalfSpeed() {
        let player = ExercisePlayback()
        XCTAssertFalse(player.playing)
        XCTAssertEqual(player.frame, 0)
        XCTAssertEqual(player.delay(0.1), 0.2)
    }
    func testPauseKeepsFrameAndResumeDoesNotReset() {
        var player = ExercisePlayback()
        player.toggle(count: 5); player.advance(count: 5); player.advance(count: 5)
        player.toggle(count: 5)
        XCTAssertFalse(player.playing); XCTAssertEqual(player.frame, 2)
        player.advance(count: 5); XCTAssertEqual(player.frame, 2)
        player.toggle(count: 5); XCTAssertEqual(player.frame, 2)
    }
    func testStopsAfterOneCycleAndReplayStartsAtBeginning() {
        var player = ExercisePlayback()
        player.toggle(count: 3)
        for _ in 0..<3 { player.advance(count: 3) }
        XCTAssertFalse(player.playing); XCTAssertEqual(player.frame, 2)
        player.toggle(count: 3)
        XCTAssertTrue(player.playing); XCTAssertEqual(player.frame, 0)
    }
    func testFrameStepsPauseAndClamp() {
        var player = ExercisePlayback(playing: true)
        player.step(-1, count: 4)
        XCTAssertFalse(player.playing); XCTAssertEqual(player.frame, 0)
        player.step(20, count: 4); XCTAssertEqual(player.frame, 3)
        player.step(-1, count: 4); XCTAssertEqual(player.frame, 2)
        player.speed = 0.25; XCTAssertEqual(player.delay(0.2), 0.8)
        player.speed = 1; XCTAssertEqual(player.delay(0.2), 0.2)
    }
    func testInvalidMediaAndSingleFrameDoNotPlay() {
        XCTAssertNil(ExerciseAnimation.decode(Data("broken gif".utf8)))
        var player = ExercisePlayback()
        player.toggle(count: 1)
        XCTAssertFalse(player.playing)
    }
}
