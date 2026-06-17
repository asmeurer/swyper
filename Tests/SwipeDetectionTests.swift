import Testing
@testable import Swyper

/// Helper to build a 3-finger track dictionary from arrays of start/current positions.
private func makeFingers(
    starts: [(Float, Float)],
    currents: [(Float, Float)]
) -> [Int32: FingerTrack] {
    var fingers: [Int32: FingerTrack] = [:]
    for i in 0..<starts.count {
        fingers[Int32(i)] = FingerTrack(
            startX: starts[i].0,
            startY: starts[i].1,
            currentX: currents[i].0,
            currentY: currents[i].1
        )
    }
    return fingers
}

private let defaultThreshold: Float = 0.08

@Suite("Swipe Detection")
struct SwipeDetectionTests {

    @Test("Three fingers moving right detects right swipe")
    func threeFingersMoveRight() {
        let fingers = makeFingers(
            starts: [(0.3, 0.5), (0.3, 0.5), (0.3, 0.5)],
            currents: [(0.5, 0.5), (0.5, 0.5), (0.5, 0.5)]
        )
        #expect(detectSwipe(fingers: fingers, threshold: defaultThreshold) == .right)
    }

    @Test("Three fingers moving left detects left swipe")
    func threeFingersMoveLeft() {
        let fingers = makeFingers(
            starts: [(0.5, 0.5), (0.5, 0.5), (0.5, 0.5)],
            currents: [(0.3, 0.5), (0.3, 0.5), (0.3, 0.5)]
        )
        #expect(detectSwipe(fingers: fingers, threshold: defaultThreshold) == .left)
    }

    @Test("Three fingers moving up detects up swipe")
    func threeFingersMoveUp() {
        let fingers = makeFingers(
            starts: [(0.5, 0.3), (0.5, 0.3), (0.5, 0.3)],
            currents: [(0.5, 0.5), (0.5, 0.5), (0.5, 0.5)]
        )
        #expect(detectSwipe(fingers: fingers, threshold: defaultThreshold) == .up)
    }

    @Test("Three fingers moving down detects down swipe")
    func threeFingersMoveDown() {
        let fingers = makeFingers(
            starts: [(0.5, 0.5), (0.5, 0.5), (0.5, 0.5)],
            currents: [(0.5, 0.3), (0.5, 0.3), (0.5, 0.3)]
        )
        #expect(detectSwipe(fingers: fingers, threshold: defaultThreshold) == .down)
    }

    @Test("Movement below threshold returns nil")
    func belowThreshold() {
        // Move by 0.02, well below the 0.08 threshold
        let fingers = makeFingers(
            starts: [(0.5, 0.5), (0.5, 0.5), (0.5, 0.5)],
            currents: [(0.52, 0.5), (0.52, 0.5), (0.52, 0.5)]
        )
        #expect(detectSwipe(fingers: fingers, threshold: defaultThreshold) == nil)
    }

    @Test("Equal horizontal and vertical movement returns nil")
    func ambiguousMovement() {
        // Same magnitude in both axes
        let fingers = makeFingers(
            starts: [(0.5, 0.5), (0.5, 0.5), (0.5, 0.5)],
            currents: [(0.6, 0.6), (0.6, 0.6), (0.6, 0.6)]
        )
        #expect(detectSwipe(fingers: fingers, threshold: defaultThreshold) == nil)
    }

    @Test("Fewer than 3 finger tracks returns nil")
    func fewerThanThreeFingers() {
        let fingers: [Int32: FingerTrack] = [
            0: FingerTrack(startX: 0.3, startY: 0.5, currentX: 0.5, currentY: 0.5),
            1: FingerTrack(startX: 0.3, startY: 0.5, currentX: 0.5, currentY: 0.5)
        ]
        #expect(detectSwipe(fingers: fingers, threshold: defaultThreshold) == nil)
    }

    @Test("Diagonal movement with dominant horizontal axis returns horizontal direction")
    func diagonalDominantHorizontal() {
        // Move right by 0.2, up by 0.05
        let fingers = makeFingers(
            starts: [(0.3, 0.5), (0.3, 0.5), (0.3, 0.5)],
            currents: [(0.5, 0.55), (0.5, 0.55), (0.5, 0.55)]
        )
        #expect(detectSwipe(fingers: fingers, threshold: defaultThreshold) == .right)
    }

    @Test("Diagonal movement with dominant vertical axis returns vertical direction")
    func diagonalDominantVertical() {
        // Move up by 0.2, right by 0.05
        let fingers = makeFingers(
            starts: [(0.5, 0.3), (0.5, 0.3), (0.5, 0.3)],
            currents: [(0.55, 0.5), (0.55, 0.5), (0.55, 0.5)]
        )
        #expect(detectSwipe(fingers: fingers, threshold: defaultThreshold) == .up)
    }

    @Test("Empty finger dictionary returns nil")
    func emptyFingers() {
        let fingers: [Int32: FingerTrack] = [:]
        #expect(detectSwipe(fingers: fingers, threshold: defaultThreshold) == nil)
    }

    @Test("Single finger returns nil")
    func singleFinger() {
        let fingers: [Int32: FingerTrack] = [
            0: FingerTrack(startX: 0.3, startY: 0.5, currentX: 0.5, currentY: 0.5)
        ]
        #expect(detectSwipe(fingers: fingers, threshold: defaultThreshold) == nil)
    }

    @Test("Four fingers returns nil")
    func fourFingers() {
        let fingers = makeFingers(
            starts: [(0.3, 0.5), (0.3, 0.5), (0.3, 0.5), (0.3, 0.5)],
            currents: [(0.5, 0.5), (0.5, 0.5), (0.5, 0.5), (0.5, 0.5)]
        )
        #expect(detectSwipe(fingers: fingers, threshold: defaultThreshold) == nil)
    }

    @Test("Movement exactly at threshold returns nil (must exceed)")
    func exactlyAtThreshold() {
        // avgDX = 0.08 exactly, which is not > threshold
        let fingers = makeFingers(
            starts: [(0.5, 0.5), (0.5, 0.5), (0.5, 0.5)],
            currents: [(0.58, 0.5), (0.58, 0.5), (0.58, 0.5)]
        )
        // absDX == threshold, not >, so nil
        #expect(detectSwipe(fingers: fingers, threshold: 0.08) == nil)
    }

    @Test("Stationary wrist plus two swiping fingers returns nil")
    func stationaryWristRejected() {
        // Simulates a resting wrist (at the bottom of the trackpad, not moving) plus
        // two fingers from the other hand doing a two-finger swipe. Average deltas
        // would cross the threshold, but one contact has not moved at all.
        let fingers = makeFingers(
            starts: [(0.3, 0.5), (0.3, 0.5), (0.5, 0.05)],
            currents: [(0.55, 0.5), (0.55, 0.5), (0.5, 0.05)]
        )
        #expect(detectSwipe(fingers: fingers, threshold: defaultThreshold) == nil)
    }

    @Test("Two swiping fingers plus barely-moving contact returns nil")
    func laggingContactRejected() {
        // Two fingers move past the threshold, third barely twitches — still looks
        // like a swipe by the old average but the third contact hasn't really moved.
        let fingers = makeFingers(
            starts: [(0.3, 0.5), (0.3, 0.5), (0.5, 0.1)],
            currents: [(0.55, 0.5), (0.55, 0.5), (0.51, 0.1)]
        )
        #expect(detectSwipe(fingers: fingers, threshold: defaultThreshold) == nil)
    }

    @Test("Three fingers moving together with slight variation detects swipe")
    func threeFingersModestVariationAccepted() {
        // Realistic swipe: fingers don't move identical amounts, but all clearly move
        // in the swipe direction past the per-finger floor (threshold/2 = 0.04).
        let fingers = makeFingers(
            starts: [(0.3, 0.5), (0.3, 0.5), (0.3, 0.5)],
            currents: [(0.5, 0.5), (0.55, 0.5), (0.45, 0.5)]
        )
        #expect(detectSwipe(fingers: fingers, threshold: defaultThreshold) == .right)
    }
}

@Suite("Four-Finger Suppression")
struct FourFingerSuppressionTests {

    /// Builds touches at the given normalized positions with sequential ids.
    private func touches(_ positions: [(Float, Float)]) -> [TouchInfo] {
        positions.enumerated().map { index, pos in
            TouchInfo(id: Int32(index), state: 3, x: pos.0, y: pos.1)
        }
    }

    /// Drives a sequence of frames through the state machine, returning the
    /// outcome of the final frame.
    @discardableResult
    private func run(_ state: inout SwipeState, frames: [[TouchInfo]]) -> FrameOutcome {
        var outcome = FrameOutcome()
        for frame in frames {
            outcome = updateSwipeState(state: &state, touches: frame)
        }
        return outcome
    }

    @Test("Four fingers dropping to three does not fire a swipe")
    func fourThenThreeSuppressed() {
        var state = SwipeState()
        // Start with four fingers near the left, then lift one and keep swiping right.
        let start: [(Float, Float)] = [(0.2, 0.5), (0.3, 0.5), (0.4, 0.5), (0.5, 0.5)]
        let threeMoved: [(Float, Float)] = [(0.5, 0.5), (0.6, 0.5), (0.7, 0.5)]
        let outcome = run(&state, frames: [touches(start), touches(threeMoved)])
        #expect(outcome.firedDirection == nil)
        #expect(outcome.isThreeFingerFrame == false)
        #expect(state.suppressedUntilRelease)
    }

    @Test("Suppression persists across a three-finger swipe until release")
    func suppressionPersistsUntilRelease() {
        var state = SwipeState()
        let four: [(Float, Float)] = [(0.2, 0.5), (0.3, 0.5), (0.4, 0.5), (0.5, 0.5)]
        // Four fingers, then a full three-finger swipe to the right — still suppressed.
        let threeStart: [(Float, Float)] = [(0.3, 0.5), (0.3, 0.5), (0.3, 0.5)]
        let threeEnd: [(Float, Float)] = [(0.6, 0.5), (0.6, 0.5), (0.6, 0.5)]
        let outcome = run(&state, frames: [touches(four), touches(threeStart), touches(threeEnd)])
        #expect(outcome.firedDirection == nil)
        #expect(state.suppressedUntilRelease)
    }

    @Test("Lifting all fingers re-arms three-finger detection")
    func releaseClearsSuppression() {
        var state = SwipeState()
        run(&state, frames: [
            touches([(0.2, 0.5), (0.3, 0.5), (0.4, 0.5), (0.5, 0.5)]),  // four fingers
            []                                                          // all lifted
        ])
        #expect(state.suppressedUntilRelease == false)

        // A genuine three-finger swipe now fires normally.
        let outcome = run(&state, frames: [
            touches([(0.3, 0.5), (0.3, 0.5), (0.3, 0.5)]),
            touches([(0.6, 0.5), (0.6, 0.5), (0.6, 0.5)])
        ])
        #expect(outcome.firedDirection == .right)
        #expect(outcome.isThreeFingerFrame)
    }

    @Test("Three-finger swipe without any four-finger frame fires normally")
    func threeFingerSwipeFires() {
        var state = SwipeState()
        let outcome = run(&state, frames: [
            touches([(0.3, 0.5), (0.3, 0.5), (0.3, 0.5)]),
            touches([(0.6, 0.5), (0.6, 0.5), (0.6, 0.5)])
        ])
        #expect(outcome.firedDirection == .right)
        #expect(outcome.isThreeFingerFrame)
        #expect(state.suppressedUntilRelease == false)
    }

    @Test("Dropping to two fingers does not clear suppression mid-gesture")
    func twoFingersKeepsSuppression() {
        var state = SwipeState()
        run(&state, frames: [
            touches([(0.2, 0.5), (0.3, 0.5), (0.4, 0.5), (0.5, 0.5)]),  // four fingers
            touches([(0.5, 0.5), (0.6, 0.5)])                           // down to two
        ])
        #expect(state.suppressedUntilRelease)
    }
}

@Suite("Palm Contact Classification")
struct PalmContactTests {
    // Observed sizes from raw touch-record dumps: fingertips read < ~0.8,
    // resting palm/thumb contacts read 1.0–8.7.

    @Test("Typical fingertip sizes count as fingers", arguments: [Float(0.0), 0.18, 0.5, 0.77])
    func fingertipSizesAccepted(size: Float) {
        #expect(isFingerContact(size: size))
    }

    @Test("Resting palm sizes are rejected", arguments: [Float(1.0), 1.4, 2.4, 8.7])
    func palmSizesRejected(size: Float) {
        #expect(!isFingerContact(size: size))
    }

    @Test("Classification splits exactly at the threshold")
    func boundaryAtThreshold() {
        #expect(isFingerContact(size: palmSizeThreshold - 0.0001))
        #expect(!isFingerContact(size: palmSizeThreshold))
    }
}
