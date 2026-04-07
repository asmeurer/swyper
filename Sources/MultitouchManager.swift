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
private typealias MTRegisterContactFrameCallbackWithRefconFn = @convention(c) (
    MTDeviceRef, MTContactFrameCallback, UnsafeMutableRawPointer?
) -> Void
private typealias MTDeviceStartFn = @convention(c) (MTDeviceRef, Int32) -> Int32
private typealias MTDeviceStopFn = @convention(c) (MTDeviceRef) -> Void

// Known field offsets in the MTTouch struct (arm64, macOS 14+)
// These are read field-by-field to avoid stride issues.
private let kOffsetPathIndex: Int = 8     // Int32 at byte 8
private let kOffsetState: Int = 12        // Int32 at byte 12
private let kOffsetNormX: Int = 24        // Float at byte 24
private let kOffsetNormY: Int = 28        // Float at byte 28

// MARK: - Swipe tracking state

private struct FingerTrack {
    var startX: Float
    var startY: Float
    var currentX: Float
    var currentY: Float
}

private struct SwipeState {
    var isTracking: Bool = false
    var hasFired: Bool = false
    var fingers: [Int32: FingerTrack] = [:]
    var touchStride: Int = 0
}

// MARK: - File-scope C callback

private let touchCallback: MTContactFrameCallback = {
    device, data, nFingers, timestamp, frame, refcon in
    guard let refcon else { return 0 }
    let manager = Unmanaged<MultitouchManager>.fromOpaque(refcon).takeUnretainedValue()
    manager.processFrame(data: data, fingerCount: Int(nFingers))
    return 0
}

// MARK: - MultitouchManager

final class MultitouchManager: @unchecked Sendable {
    var onSwipe: (@MainActor @Sendable (SwipeDirection) -> Void)?

    private let lock = OSAllocatedUnfairLock(initialState: SwipeState())
    private let logger = Logger(subsystem: "com.swyper.app", category: "multitouch")

    // Dynamic function pointers
    private let fnCreateList: MTDeviceCreateListFn
    private let fnRegisterCallback: MTRegisterContactFrameCallbackWithRefconFn
    private let fnStart: MTDeviceStartFn
    private let fnStop: MTDeviceStopFn

    private let handle: UnsafeMutableRawPointer
    private var devices: [MTDeviceRef] = []
    private var isRunning = false

    private let swipeThreshold: Float = 0.08

    init?() {
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
        fnRegisterCallback = unsafeBitCast(pRegister, to: MTRegisterContactFrameCallbackWithRefconFn.self)
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
        let stride = resolveStride(data: data, fingerCount: fingerCount)
        guard stride > 0 else { return }

        // Read touch data for all fingers
        var touches: [(id: Int32, x: Float, y: Float)] = []
        let rawPtr = UnsafeRawPointer(data)

        for i in 0..<fingerCount {
            let base = rawPtr + i * stride
            let pathIndex = base.load(fromByteOffset: kOffsetPathIndex, as: Int32.self)
            let state = base.load(fromByteOffset: kOffsetState, as: Int32.self)

            // State 4 = actively touching the trackpad
            if state == 4 {
                let x = base.load(fromByteOffset: kOffsetNormX, as: Float.self)
                let y = base.load(fromByteOffset: kOffsetNormY, as: Float.self)
                touches.append((id: pathIndex, x: x, y: y))
            }
        }

        let activeTouches = touches

        lock.withLock { state in
            if activeTouches.count == 3 {
                if !state.isTracking {
                    // Start tracking: record starting positions
                    state.isTracking = true
                    state.hasFired = false
                    state.fingers.removeAll()
                    for touch in activeTouches {
                        state.fingers[touch.id] = FingerTrack(
                            startX: touch.x, startY: touch.y,
                            currentX: touch.x, currentY: touch.y
                        )
                    }
                } else if !state.hasFired {
                    // Update current positions
                    for touch in activeTouches {
                        if state.fingers[touch.id] != nil {
                            state.fingers[touch.id]!.currentX = touch.x
                            state.fingers[touch.id]!.currentY = touch.y
                        }
                    }

                    // Check for swipe
                    if let direction = detectSwipe(fingers: state.fingers) {
                        state.hasFired = true
                        fireSwipe(direction)
                    }
                }
            } else {
                // Reset when not exactly 3 fingers
                if state.isTracking {
                    state.isTracking = false
                    state.hasFired = false
                    state.fingers.removeAll()
                }
            }
        }
    }

    private func resolveStride(data: UnsafeMutableRawPointer, fingerCount: Int) -> Int {
        let cached = lock.withLock { $0.touchStride }
        if cached > 0 { return cached }

        // Need at least 2 touches to empirically detect stride
        guard fingerCount >= 2 else { return 0 }

        let rawPtr = UnsafeRawPointer(data)
        let firstPathIndex = rawPtr.load(fromByteOffset: kOffsetPathIndex, as: Int32.self)

        // Try common stride values
        for candidate in [64, 72, 80, 88, 96, 104, 112, 120, 128] {
            let secondPathIndex = rawPtr.load(fromByteOffset: candidate + kOffsetPathIndex, as: Int32.self)
            // The second finger should have a different path index and it should be a small positive value
            if secondPathIndex != firstPathIndex && secondPathIndex >= 0 && secondPathIndex < 100 {
                lock.withLock { $0.touchStride = candidate }
                logger.info("Detected MTTouch stride: \(candidate) bytes")
                return candidate
            }
        }

        // Fallback
        let fallback = 96
        lock.withLock { $0.touchStride = fallback }
        logger.warning("Using fallback MTTouch stride: \(fallback) bytes")
        return fallback
    }

    private func detectSwipe(fingers: [Int32: FingerTrack]) -> SwipeDirection? {
        guard fingers.count == 3 else { return nil }

        var totalDX: Float = 0
        var totalDY: Float = 0

        for (_, track) in fingers {
            totalDX += track.currentX - track.startX
            totalDY += track.currentY - track.startY
        }

        let avgDX = totalDX / 3.0
        let avgDY = totalDY / 3.0

        let absDX = abs(avgDX)
        let absDY = abs(avgDY)

        // Must exceed threshold in the dominant axis
        if absDX > absDY && absDX > swipeThreshold {
            return avgDX > 0 ? .right : .left
        } else if absDY > absDX && absDY > swipeThreshold {
            return avgDY > 0 ? .up : .down
        }

        return nil
    }

    private func fireSwipe(_ direction: SwipeDirection) {
        let handler = onSwipe
        DispatchQueue.main.async {
            handler?(direction)
        }
    }
}
