import CoreGraphics
import Foundation
import os

/// Suppresses horizontal trackpad scroll events around 3-finger gestures. When a
/// user performs a 3-finger swipe, individual fingers often land or lift slightly
/// out of sync, producing a brief 2-finger phase that apps like Chrome interpret
/// as a back/forward navigation swipe. This component installs a session-level
/// `CGEventTap` and drops horizontal-dominant continuous scroll events while a
/// 3-finger gesture is active or within a short cooldown window afterward.
final class ScrollSuppressor: @unchecked Sendable {
    /// How long after the last 3-finger frame to keep blocking horizontal scroll.
    /// Tuning: too short and stray 2-finger navigation leaks through; too long and
    /// the user can't 2-finger-scroll horizontally right after a 3-finger swipe.
    static let cooldown: TimeInterval = 0.2

    private let suppressUntil = OSAllocatedUnfairLock<CFAbsoluteTime>(initialState: 0)
    private let isActive = OSAllocatedUnfairLock(initialState: false)
    private let logger = Logger(subsystem: "com.swyper.app", category: "scrollsuppressor")

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// Called from the multitouch thread whenever 3 fingers are observed. Extends
    /// the suppression deadline to `now + cooldown`.
    func noteThreeFingerActivity(cooldown: TimeInterval = ScrollSuppressor.cooldown) {
        guard isActive.withLock({ $0 }) else { return }

        let deadline = CFAbsoluteTimeGetCurrent() + cooldown
        suppressUntil.withLock { current in
            if current < deadline { current = deadline }
        }
    }

    func start() -> Bool {
        guard eventTap == nil else { return true }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let mask: CGEventMask = 1 << CGEventType.scrollWheel.rawValue

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: scrollTapCallback,
            userInfo: refcon
        ) else {
            logger.error("Failed to create scroll event tap — check accessibility permission")
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.eventTap = tap
        self.runLoopSource = source
        isActive.withLock { $0 = true }
        logger.info("Scroll suppressor started")
        return true
    }

    func stop() {
        let wasActive = isActive.withLock { state in
            let previousValue = state
            state = false
            return previousValue
        }
        guard eventTap != nil || runLoopSource != nil || wasActive else { return }

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        suppressUntil.withLock { $0 = 0 }
        logger.info("Scroll suppressor stopped")
    }

    /// Returns nil to drop the event, or the event itself to pass it through.
    fileprivate func handle(event: CGEvent) -> CGEvent? {
        let now = CFAbsoluteTimeGetCurrent()
        let until = suppressUntil.withLock { $0 }
        guard now < until else { return event }

        // Only suppress continuous (trackpad) scrolls; leave discrete mouse-wheel ticks alone.
        let isContinuous = event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
        guard isContinuous else { return event }

        let dy = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1)
        let dx = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis2)

        if abs(dx) > abs(dy) {
            logger.debug("Suppressed horizontal trackpad scroll dx=\(dx) dy=\(dy)")
            return nil
        }
        return event
    }

    fileprivate func reenable() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
            logger.warning("Event tap re-enabled after system disable")
        }
    }
}

private let scrollTapCallback: CGEventTapCallBack = { _, type, event, refcon in
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let refcon {
            Unmanaged<ScrollSuppressor>.fromOpaque(refcon).takeUnretainedValue().reenable()
        }
        return Unmanaged.passUnretained(event)
    }

    guard let refcon else { return Unmanaged.passUnretained(event) }
    let suppressor = Unmanaged<ScrollSuppressor>.fromOpaque(refcon).takeUnretainedValue()
    if let passed = suppressor.handle(event: event) {
        return Unmanaged.passUnretained(passed)
    }
    return nil
}
