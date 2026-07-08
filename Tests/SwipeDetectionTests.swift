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

    /// A four-finger frame repeated enough times to pass the suppression debounce.
    private func sustainedFour(_ positions: [(Float, Float)]) -> [[TouchInfo]] {
        Array(repeating: touches(positions), count: kFourFingerDebounceFrames)
    }

    @Test("Four fingers dropping to three does not fire a swipe")
    func fourThenThreeSuppressed() {
        var state = SwipeState()
        // Start with four fingers near the left, then lift one and keep swiping right.
        let start: [(Float, Float)] = [(0.2, 0.5), (0.3, 0.5), (0.4, 0.5), (0.5, 0.5)]
        let threeMoved: [(Float, Float)] = [(0.5, 0.5), (0.6, 0.5), (0.7, 0.5)]
        let outcome = run(&state, frames: sustainedFour(start) + [touches(threeMoved)])
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
        let outcome = run(&state, frames: sustainedFour(four) + [touches(threeStart), touches(threeEnd)])
        #expect(outcome.firedDirection == nil)
        #expect(state.suppressedUntilRelease)
    }

    @Test("Lifting all fingers re-arms three-finger detection")
    func releaseClearsSuppression() {
        var state = SwipeState()
        run(&state, frames: sustainedFour([(0.2, 0.5), (0.3, 0.5), (0.4, 0.5), (0.5, 0.5)]) + [
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
        run(&state, frames: sustainedFour([(0.2, 0.5), (0.3, 0.5), (0.4, 0.5), (0.5, 0.5)]) + [
            touches([(0.5, 0.5), (0.6, 0.5)])                           // down to two
        ])
        #expect(state.suppressedUntilRelease)
    }

    @Test("Transient four-finger frames do not arm suppression or kill tracking")
    func transientFourthContactTolerated() {
        var state = SwipeState()
        // Three fingers start swiping right, a fourth contact appears for fewer
        // frames than the debounce (a landing thumb misread as a fingertip), then
        // the swipe continues and completes.
        let outcome = run(&state, frames: [
            touches([(0.3, 0.5), (0.3, 0.5), (0.3, 0.5)]),
            touches([(0.35, 0.5), (0.35, 0.5), (0.35, 0.5)]),
            touches([(0.35, 0.5), (0.35, 0.5), (0.35, 0.5), (0.7, 0.1)]),
            touches([(0.35, 0.5), (0.35, 0.5), (0.35, 0.5), (0.7, 0.1)]),
            touches([(0.6, 0.5), (0.6, 0.5), (0.6, 0.5)])
        ])
        #expect(state.suppressedUntilRelease == false)
        #expect(outcome.firedDirection == .right)
    }

    @Test("Four-finger frames during the debounce window do not fire swipes")
    func noFireDuringDebounceWindow() {
        var state = SwipeState()
        // Four fingers all sweep right together; the three-finger tracker must not
        // fire during the frames before suppression arms.
        let outcomes: [FrameOutcome] = [
            touches([(0.2, 0.5), (0.3, 0.5), (0.4, 0.5), (0.5, 0.5)]),
            touches([(0.4, 0.5), (0.5, 0.5), (0.6, 0.5), (0.7, 0.5)]),
            touches([(0.6, 0.5), (0.7, 0.5), (0.8, 0.5), (0.9, 0.5)])
        ].map { updateSwipeState(state: &state, touches: $0) }
        #expect(outcomes.allSatisfy { $0.firedDirection == nil && !$0.isThreeFingerFrame })
        #expect(state.suppressedUntilRelease)
    }
}

@Suite("Frame Diagnostics")
struct FrameDiagnosticsTests {

    private func touches(_ positions: [(Float, Float)]) -> [TouchInfo] {
        positions.enumerated().map { index, pos in
            TouchInfo(id: Int32(index), state: 3, x: pos.0, y: pos.1)
        }
    }

    @Test("Tracking start is reported once per gesture")
    func trackingStartedOnce() {
        var state = SwipeState()
        let first = updateSwipeState(state: &state, touches: touches([(0.3, 0.5), (0.3, 0.5), (0.3, 0.5)]))
        #expect(first.trackingStarted)
        let second = updateSwipeState(state: &state, touches: touches([(0.32, 0.5), (0.32, 0.5), (0.32, 0.5)]))
        #expect(!second.trackingStarted)
    }

    @Test("Gesture cut short mid-swipe reports accumulated travel")
    func abandonedGestureReportsDeltas() throws {
        var state = SwipeState()
        // Three fingers move right, but not far enough to fire, then one lifts.
        _ = updateSwipeState(state: &state, touches: touches([(0.3, 0.5), (0.3, 0.5), (0.3, 0.5)]))
        _ = updateSwipeState(state: &state, touches: touches([(0.35, 0.5), (0.35, 0.5), (0.35, 0.5)]))
        let outcome = updateSwipeState(state: &state, touches: touches([(0.35, 0.5), (0.35, 0.5)]))

        #expect(outcome.abandonedContactCount == 2)
        let deltas = try #require(outcome.abandonedDeltas)
        #expect(deltas.count == 3)
        #expect(deltas.allSatisfy { abs($0.dx - 0.05) < 0.001 && abs($0.dy) < 0.001 })
    }

    @Test("Release after a fired swipe is not reported as abandoned")
    func firedGestureNotAbandoned() {
        var state = SwipeState()
        _ = updateSwipeState(state: &state, touches: touches([(0.3, 0.5), (0.3, 0.5), (0.3, 0.5)]))
        let fired = updateSwipeState(state: &state, touches: touches([(0.6, 0.5), (0.6, 0.5), (0.6, 0.5)]))
        #expect(fired.firedDirection == .right)

        let released = updateSwipeState(state: &state, touches: [])
        #expect(released.abandonedDeltas == nil)
        #expect(released.abandonedContactCount == nil)
    }

    @Test("Suppression arm and clear are reported on transitions only")
    func suppressionTransitions() {
        var state = SwipeState()
        let four = touches([(0.2, 0.5), (0.3, 0.5), (0.4, 0.5), (0.5, 0.5)])
        for _ in 0..<(kFourFingerDebounceFrames - 1) {
            let outcome = updateSwipeState(state: &state, touches: four)
            #expect(!outcome.suppressionArmed)
        }
        let arming = updateSwipeState(state: &state, touches: four)
        #expect(arming.suppressionArmed)
        let afterArming = updateSwipeState(state: &state, touches: four)
        #expect(!afterArming.suppressionArmed)

        let released = updateSwipeState(state: &state, touches: [])
        #expect(released.suppressionCleared)
        let stillReleased = updateSwipeState(state: &state, touches: [])
        #expect(!stillReleased.suppressionCleared)
    }

    @Test("Sustained four-finger frames during tracking report the abandoned gesture")
    func fourFingersAbandonsTracking() {
        var state = SwipeState()
        _ = updateSwipeState(state: &state, touches: touches([(0.3, 0.5), (0.3, 0.5), (0.3, 0.5)]))
        _ = updateSwipeState(state: &state, touches: touches([(0.35, 0.5), (0.35, 0.5), (0.35, 0.5)]))
        let four = touches([(0.35, 0.5), (0.35, 0.5), (0.35, 0.5), (0.5, 0.5)])
        var outcome = FrameOutcome()
        for _ in 0..<kFourFingerDebounceFrames {
            outcome = updateSwipeState(state: &state, touches: four)
        }
        #expect(outcome.suppressionArmed)
        #expect(outcome.abandonedContactCount == 4)
        #expect(outcome.abandonedDeltas?.count == 3)
    }
}

@Suite("Palm Filter Stickiness")
struct PalmFilterTests {

    @Test("A contact that ever reads palm-sized stays excluded when its size dips")
    func stickyPalmClassification() {
        var filter = PalmFilter()
        #expect(filter.effectiveSize(id: 1, size: 0.95) == 0.95)
        // Size dips below the 0.9 threshold; the lifetime maximum still governs.
        #expect(filter.effectiveSize(id: 1, size: 0.88) == 0.95)
        #expect(!isFingerContact(size: filter.effectiveSize(id: 1, size: 0.85)))
    }

    @Test("Fingertip-sized contacts are unaffected")
    func fingertipPassesThrough() {
        var filter = PalmFilter()
        #expect(filter.effectiveSize(id: 1, size: 0.3) == 0.3)
        #expect(filter.effectiveSize(id: 1, size: 0.5) == 0.5)
        #expect(isFingerContact(size: filter.effectiveSize(id: 1, size: 0.4)))
    }

    @Test("Contacts are classified independently")
    func independentContacts() {
        var filter = PalmFilter()
        _ = filter.effectiveSize(id: 1, size: 0.95)
        #expect(filter.effectiveSize(id: 2, size: 0.3) == 0.3)
    }

    @Test("Lifting a contact resets its classification")
    func liftResetsClassification() {
        var filter = PalmFilter()
        _ = filter.effectiveSize(id: 1, size: 0.95)
        filter.retainOnly(ids: [])
        #expect(filter.effectiveSize(id: 1, size: 0.3) == 0.3)
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
