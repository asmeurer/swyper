import Foundation
import os

// MARK: - MultitouchSupport C types

private typealias MTDeviceRef = UnsafeMutableRawPointer

// Callback signature for MTRegisterContactFrameCallbackWithRefcon:
// (device, touchData, numTouches, timestamp, frame, refcon) -> Int32
private typealias MTContactFrameCallback = @convention(c) (
    MTDeviceRef, UnsafeMutableRawPointer, Int32, Double, Int32, UnsafeMutableRawPointer?
) -> Int32

// Function pointer types for dynamically loaded symbols
private typealias MTDeviceCreateListFn = @convention(c) () -> Unmanaged<CFArray>
private typealias MTRegisterCallbackFn = @convention(c) (
    MTDeviceRef, MTContactFrameCallback, UnsafeMutableRawPointer?
) -> Void
private typealias MTDeviceStartFn = @convention(c) (MTDeviceRef, Int32) -> Int32
private typealias MTDeviceStopFn = @convention(c) (MTDeviceRef) -> Void

// Known MTTouch record layout for arm64.
// macOS 26 shifted all fields +8 bytes compared to macOS 14.
#if arch(arm64)
private let kTouchRecordStride: Int = 96
#else
private let kTouchRecordStride: Int = 0
#endif

private let kOffsetPathIndex: Int = 16    // Int32 — finger identifier
private let kOffsetState: Int = 20        // Int32 — touch phase (1=start, 3=touching, …)
private let kOffsetNormX: Int = 32        // Float — normalized X position [0,1]
private let kOffsetNormY: Int = 36        // Float — normalized Y position [0,1]
private let kOffsetSize: Int = 48         // Float — contact area; palms read much larger than fingertips

// A contact whose reported size is at or above this is treated as a palm or
// thumb base rather than a fingertip, and excluded from swipe detection so a
// resting palm doesn't break the three-finger count. Determined empirically by
// dumping raw touch records: fingertips measure < ~0.8 while resting palm/thumb
// contacts measure > ~1.0 (the dominant palm contact reads 4–8).
let palmSizeThreshold: Float = 0.9

/// Whether a contact of the given size should count as a fingertip (rather than
/// a palm/thumb-base contact to be ignored).
func isFingerContact(size: Float, threshold: Float = palmSizeThreshold) -> Bool {
    size < threshold
}

// MARK: - Swipe tracking state

struct FingerTrack: Sendable {
    var startX: Float
    var startY: Float
    var currentX: Float
    var currentY: Float
}

struct SwipeState {
    var isTracking: Bool = false
    var hasFired: Bool = false
    var fingers: [Int32: FingerTrack] = [:]
    var swipeThreshold: Float = 0.08
    /// Set once four or more fingertips are seen in a frame, and held until every
    /// contact lifts. While set, three-finger frames are ignored — this prevents a
    /// four-finger swipe (e.g. switching spaces), where a finger is lifted mid-swipe
    /// so the count momentarily drops to three, from registering as a three-finger
    /// swipe. The system four-finger gesture keeps running as long as one finger
    /// stays down, so we only re-arm once the trackpad is fully released.
    var suppressedUntilRelease: Bool = false
}

struct TouchInfo: Sendable {
    let id: Int32
    let state: Int32
    let x: Float
    let y: Float
}

/// Per-finger travel accumulated during a gesture, reported for diagnostics when
/// the gesture ends without firing.
struct FingerDelta: Equatable, Sendable {
    var dx: Float
    var dy: Float
}

/// Outcome of processing one multitouch frame.
struct FrameOutcome: Equatable {
    /// A genuine (non-suppressed) three-finger frame occurred this update. Callers
    /// use this to drive scroll suppression.
    var isThreeFingerFrame: Bool = false
    /// A swipe was detected this frame and should be fired.
    var firedDirection: SwipeDirection?
    /// Three-finger tracking began this frame.
    var trackingStarted: Bool = false
    /// Four or more fingertip contacts appeared this frame, arming suppression.
    var suppressionArmed: Bool = false
    /// All contacts lifted this frame, clearing four-finger suppression.
    var suppressionCleared: Bool = false
    /// Set when an in-progress three-finger gesture ended without firing: the
    /// per-finger travel accumulated before the gesture was abandoned.
    var abandonedDeltas: [FingerDelta]?
    /// The fingertip contact count that ended the abandoned gesture
    /// (see `abandonedDeltas`).
    var abandonedContactCount: Int?
}

// MARK: - File-scope C callback

private let touchCallback: MTContactFrameCallback = { _, data, nFingers, _, _, refcon in
    guard let refcon else { return 0 }
    let manager = Unmanaged<MultitouchManager>.fromOpaque(refcon).takeUnretainedValue()
    manager.processFrame(data: data, fingerCount: Int(nFingers))
    return 0
}

// MARK: - Swipe detection (internal for testability)

func detectSwipe(fingers: [Int32: FingerTrack], threshold: Float) -> SwipeDirection? {
    guard fingers.count == 3 else { return nil }

    let deltas = fingers.values.map { (dx: $0.currentX - $0.startX, dy: $0.currentY - $0.startY) }
    let avgDX = deltas.reduce(0) { $0 + $1.dx } / 3.0
    let avgDY = deltas.reduce(0) { $0 + $1.dy } / 3.0

    let absDX = abs(avgDX)
    let absDY = abs(avgDY)

    // Each finger must move in the dominant direction by at least this much. Rejects
    // false positives where a stationary contact (e.g. a resting wrist) gets averaged
    // in with two fingers that are genuinely swiping.
    let perFingerMin = threshold / 2

    if absDX > absDY && absDX > threshold {
        let sign: Float = avgDX > 0 ? 1 : -1
        guard deltas.allSatisfy({ $0.dx * sign > perFingerMin }) else { return nil }
        return avgDX > 0 ? .right : .left
    } else if absDY > absDX && absDY > threshold {
        let sign: Float = avgDY > 0 ? 1 : -1
        guard deltas.allSatisfy({ $0.dy * sign > perFingerMin }) else { return nil }
        return avgDY > 0 ? .up : .down
    }

    return nil
}

/// Clears any in-progress swipe tracking.
func resetSwipeTracking(_ state: inout SwipeState) {
    state.isTracking = false
    state.hasFired = false
    state.fingers.removeAll()
}

/// Advances three-finger tracking with the latest contacts, returning a swipe
/// direction if one is detected this frame.
func updateThreeFingerTracking(state: inout SwipeState, touches: [TouchInfo]) -> SwipeDirection? {
    if !state.isTracking {
        state.isTracking = true
        state.hasFired = false
        state.fingers.removeAll()
        for touch in touches {
            state.fingers[touch.id] = FingerTrack(
                startX: touch.x, startY: touch.y,
                currentX: touch.x, currentY: touch.y
            )
        }
        return nil
    }

    guard !state.hasFired else { return nil }

    for touch in touches where state.fingers[touch.id] != nil {
        state.fingers[touch.id] = FingerTrack(
            startX: state.fingers[touch.id]?.startX ?? touch.x,
            startY: state.fingers[touch.id]?.startY ?? touch.y,
            currentX: touch.x,
            currentY: touch.y
        )
    }

    if let direction = detectSwipe(fingers: state.fingers, threshold: state.swipeThreshold) {
        state.hasFired = true
        return direction
    }
    return nil
}

/// Clears in-progress tracking. When a live (unfired) gesture is being cut short,
/// records its per-finger travel in the outcome so the caller can log why it ended.
private func abandonTracking(_ state: inout SwipeState, contactCount: Int, outcome: inout FrameOutcome) {
    if state.isTracking && !state.hasFired && !state.fingers.isEmpty {
        outcome.abandonedDeltas = state.fingers.values.map {
            FingerDelta(dx: $0.currentX - $0.startX, dy: $0.currentY - $0.startY)
        }
        outcome.abandonedContactCount = contactCount
    }
    resetSwipeTracking(&state)
}

/// Routes a single frame of fingertip contacts through the swipe state machine,
/// applying four-finger suppression. Returns what (if anything) the frame produced.
func updateSwipeState(state: inout SwipeState, touches: [TouchInfo]) -> FrameOutcome {
    let count = touches.count
    var outcome = FrameOutcome()

    if count >= 4 {
        // A four-or-more-finger gesture (e.g. switching spaces). Arm suppression
        // until the trackpad is fully released so lifting one finger mid-gesture
        // doesn't fall through to three-finger detection.
        if !state.suppressedUntilRelease {
            state.suppressedUntilRelease = true
            outcome.suppressionArmed = true
        }
        abandonTracking(&state, contactCount: count, outcome: &outcome)
        return outcome
    }

    if count == 3 && !state.suppressedUntilRelease {
        outcome.isThreeFingerFrame = true
        outcome.trackingStarted = !state.isTracking
        outcome.firedDirection = updateThreeFingerTracking(state: &state, touches: touches)
        return outcome
    }

    // Fewer than three contacts, or a suppressed three-finger frame. Reset
    // tracking, and once every contact has lifted, re-arm for the next gesture.
    abandonTracking(&state, contactCount: count, outcome: &outcome)
    if count == 0 && state.suppressedUntilRelease {
        state.suppressedUntilRelease = false
        outcome.suppressionCleared = true
    }
    return outcome
}

// MARK: - MultitouchManager

final class MultitouchManager: @unchecked Sendable {
    var onSwipe: (@MainActor @Sendable (SwipeDirection) -> Void)?
    /// Fires on every frame where exactly 3 fingers are present. Invoked from the
    /// multitouch background thread — handlers must be thread-safe and cheap.
    var onThreeFingerFrame: (@Sendable () -> Void)?

    private struct ContactCounts: Equatable {
        var fingertips = 0
        var excluded = 0
    }

    private let lock = OSAllocatedUnfairLock(initialState: SwipeState())
    private let lastContactCounts = OSAllocatedUnfairLock(initialState: ContactCounts())
    private let logger = Logger(subsystem: "com.swyper.app", category: "multitouch")

    // Dynamic function pointers
    private let fnCreateList: MTDeviceCreateListFn
    private let fnRegisterCallback: MTRegisterCallbackFn
    private let fnStart: MTDeviceStartFn
    private let fnStop: MTDeviceStopFn

    private let handle: UnsafeMutableRawPointer
    private var devices: [MTDeviceRef] = []
    private var isRunning = false

    init?() {
        guard kTouchRecordStride > 0 else {
            return nil
        }

        guard let handle = dlopen(
            "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport",
            RTLD_LAZY
        ) else {
            return nil
        }
        self.handle = handle

        guard let pCreateList = dlsym(handle, "MTDeviceCreateList"),
              let pRegister = dlsym(handle, "MTRegisterContactFrameCallbackWithRefcon"),
              let pStart = dlsym(handle, "MTDeviceStart"),
              let pStop = dlsym(handle, "MTDeviceStop") else {
            dlclose(handle)
            return nil
        }

        fnCreateList = unsafeBitCast(pCreateList, to: MTDeviceCreateListFn.self)
        fnRegisterCallback = unsafeBitCast(pRegister, to: MTRegisterCallbackFn.self)
        fnStart = unsafeBitCast(pStart, to: MTDeviceStartFn.self)
        fnStop = unsafeBitCast(pStop, to: MTDeviceStopFn.self)
    }

    deinit {
        stop()
        dlclose(handle)
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true

        let deviceList = fnCreateList().takeUnretainedValue() as [AnyObject]
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        for device in deviceList {
            let deviceRef = Unmanaged.passUnretained(device).toOpaque()
            devices.append(deviceRef)
            fnRegisterCallback(deviceRef, touchCallback, refcon)
            _ = fnStart(deviceRef, 0)
        }

        logger.info("Started monitoring \(self.devices.count) multitouch device(s)")
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false

        for device in devices {
            fnStop(device)
        }
        devices.removeAll()
        logger.info("Stopped multitouch monitoring")
    }

    // Called from the MultitouchSupport background thread
    func processFrame(data: UnsafeMutableRawPointer, fingerCount: Int) {
        var touches: [TouchInfo] = []
        var excludedSizes: [Float] = []
        let rawPtr = UnsafeRawPointer(data)

        for i in 0..<max(0, fingerCount) {
            let base = rawPtr + i * kTouchRecordStride
            let pathIndex = base.load(fromByteOffset: kOffsetPathIndex, as: Int32.self)
            let state = base.load(fromByteOffset: kOffsetState, as: Int32.self)

            // Accept any finger that is actively present on the trackpad.
            // macOS 26 uses state 1=start, 3=touching; older versions used 4+.
            if state > 0 {
                let size = base.load(fromByteOffset: kOffsetSize, as: Float.self)
                // Skip palm/thumb-base contacts so a resting palm doesn't push
                // the contact count past three and suppress the gesture.
                guard isFingerContact(size: size) else {
                    excludedSizes.append(size)
                    continue
                }
                let x = base.load(fromByteOffset: kOffsetNormX, as: Float.self)
                let y = base.load(fromByteOffset: kOffsetNormY, as: Float.self)
                touches.append(TouchInfo(id: pathIndex, state: state, x: x, y: y))
            }
        }

        let activeTouches = touches
        let (outcome, threshold) = lock.withLock { state -> (FrameOutcome, Float) in
            (updateSwipeState(state: &state, touches: activeTouches), state.swipeThreshold)
        }

        logDiagnostics(
            outcome: outcome,
            threshold: threshold,
            fingertipCount: activeTouches.count,
            excludedSizes: excludedSizes
        )

        if outcome.isThreeFingerFrame {
            onThreeFingerFrame?()
        }
        if let direction = outcome.firedDirection {
            logger.log("Swipe detected: \(direction.rawValue, privacy: .public)")
            fireSwipe(direction)
        }
    }

    /// Logs why a gesture did (or didn't) make progress. Every message here fires
    /// on a state transition rather than per frame, so the volume stays low, and
    /// uses the default log level so `log show` can retrieve it after the fact.
    private func logDiagnostics(
        outcome: FrameOutcome,
        threshold: Float,
        fingertipCount: Int,
        excludedSizes: [Float]
    ) {
        let counts = ContactCounts(fingertips: fingertipCount, excluded: excludedSizes.count)
        let countsChanged = lastContactCounts.withLock { last in
            guard last != counts else { return false }
            last = counts
            return true
        }
        if countsChanged && !excludedSizes.isEmpty {
            let sizes = excludedSizes.map { String(format: "%.2f", $0) }.joined(separator: ", ")
            logger.log("""
                Contacts: \(counts.fingertips) fingertip(s), \
                \(counts.excluded) palm-sized excluded (sizes: \(sizes, privacy: .public))
                """)
        }

        if outcome.suppressionArmed {
            logger.log("\(fingertipCount) fingertip contacts — three-finger detection suppressed until all fingers lift")
        }
        if outcome.suppressionCleared {
            logger.log("All contacts lifted — three-finger detection re-armed")
        }
        if outcome.trackingStarted {
            logger.log("Three-finger tracking started")
        }
        if let deltas = outcome.abandonedDeltas {
            let travel = deltas
                .map { String(format: "(%+.3f, %+.3f)", $0.dx, $0.dy) }
                .joined(separator: " ")
            let thresholdText = String(format: "%.3f", threshold)
            logger.log("""
                Three-finger gesture ended without a swipe: contact count changed to \
                \(outcome.abandonedContactCount ?? -1), per-finger travel \
                \(travel, privacy: .public), threshold \(thresholdText, privacy: .public)
                """)
        }
    }

    func updateSwipeThreshold(_ threshold: Float) {
        lock.withLock { state in
            state.swipeThreshold = threshold
        }
    }

    private func fireSwipe(_ direction: SwipeDirection) {
        let handler = onSwipe
        DispatchQueue.main.async {
            handler?(direction)
        }
    }
}
