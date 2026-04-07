import CoreGraphics
import os

enum KeySimulator {
    private static let logger = Logger(subsystem: "com.swyper.app", category: "keysim")

    static func postKeyEvent(shortcut: KeyShortcut) {
        guard Permissions.isAccessibilityGranted() else {
            logger.warning("Cannot post key event — accessibility permission not granted")
            return
        }

        let source = CGEventSource(stateID: .hidSystemState)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: shortcut.keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: shortcut.keyCode, keyDown: false) else {
            logger.error("Failed to create CGEvent for keyCode=\(shortcut.keyCode)")
            return
        }

        keyDown.flags = shortcut.cgEventFlags
        keyUp.flags = shortcut.cgEventFlags

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        logger.debug("Posted key event: \(shortcut.displayString)")
    }
}
