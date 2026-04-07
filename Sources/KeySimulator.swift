import CoreGraphics

enum KeySimulator {
    static func postKeyEvent(shortcut: KeyShortcut) {
        let source = CGEventSource(stateID: .hidSystemState)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: shortcut.keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: shortcut.keyCode, keyDown: false) else {
            return
        }

        keyDown.flags = shortcut.cgEventFlags
        keyUp.flags = shortcut.cgEventFlags

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
