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

// MARK: - Swipe tracking state

struct FingerTrack: Sendable {
    var startX: Float
    var startY: Float
    var currentX: Float
    var currentY: Float
}

private struct SwipeState {
    var isTracking: Bool = false
    var hasFired: Bool = false
    var fingers: [Int32: FingerTrack] = [:]
    var swipeThreshold: Float = 0.08
}

private struct TouchInfo: Sendable {
    let id: Int32
    let state: Int32
    let x: Float
    let y: Float
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

// MARK: - MultitouchManager

final class MultitouchManager: @unchecked Sendable {
    var onSwipe: (@MainActor @Sendable (SwipeDirection) -> Void)?
    /// Fires on every frame where exactly 3 fingers are present. Invoked from the
    /// multitouch background thread — handlers must be thread-safe and cheap.
    var onThreeFingerFrame: (@Sendable () -> Void)?

    private let lock = OSAllocatedUnfairLock(initialState: SwipeState())
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
        guard fingerCount > 0 else { return }

        var touches: [TouchInfo] = []
        let rawPtr = UnsafeRawPointer(data)

        for i in 0..<fingerCount {
            let base = rawPtr + i * kTouchRecordStride
            let pathIndex = base.load(fromByteOffset: kOffsetPathIndex, as: Int32.self)
            let state = base.load(fromByteOffset: kOffsetState, as: Int32.self)

            // Accept any finger that is actively present on the trackpad.
            // macOS 26 uses state 1=start, 3=touching; older versions used 4+.
            if state > 0 {
                let x = base.load(fromByteOffset: kOffsetNormX, as: Float.self)
                let y = base.load(fromByteOffset: kOffsetNormY, as: Float.self)
                touches.append(TouchInfo(id: pathIndex, state: state, x: x, y: y))
            }
        }

        let activeTouches = touches

        if activeTouches.count == 3 {
            onThreeFingerFrame?()
            lock.withLock { state in
                updateTrackingWithThreeFingers(state: &state, touches: activeTouches)
            }
        } else {
            lock.withLock { state in
                if state.isTracking {
                    logger.debug("Tracking reset")
                    state.isTracking = false
                    state.hasFired = false
                    state.fingers.removeAll()
                }
            }
        }
    }

    private func updateTrackingWithThreeFingers(
        state: inout SwipeState,
        touches: [TouchInfo]
    ) {
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
            logger.debug("Started 3-finger tracking")
            return
        }

        guard !state.hasFired else { return }

        for touch in touches where state.fingers[touch.id] != nil {
            state.fingers[touch.id] = FingerTrack(
                startX: state.fingers[touch.id]?.startX ?? touch.x,
                startY: state.fingers[touch.id]?.startY ?? touch.y,
                currentX: touch.x,
                currentY: touch.y
            )
        }

        if let direction = detectSwipeDirection(fingers: state.fingers, threshold: state.swipeThreshold) {
            state.hasFired = true
            logger.info("Swipe detected: \(direction.rawValue)")
            fireSwipe(direction)
        }
    }

    func updateSwipeThreshold(_ threshold: Float) {
        lock.withLock { state in
            state.swipeThreshold = threshold
        }
    }

    private func detectSwipeDirection(fingers: [Int32: FingerTrack], threshold: Float) -> SwipeDirection? {
        detectSwipe(fingers: fingers, threshold: threshold)
    }

    private func fireSwipe(_ direction: SwipeDirection) {
        let handler = onSwipe
        DispatchQueue.main.async {
            handler?(direction)
        }
    }
}
