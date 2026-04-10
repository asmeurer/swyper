import Testing
import CoreGraphics
import Carbon.HIToolbox
@testable import Swyper

// MARK: - KeyShortcut.displayString

@Suite("KeyShortcut.displayString")
struct KeyShortcutDisplayStringTests {
    @Test("Cmd+C shows command symbol and C")
    func cmdC() {
        let shortcut = KeyShortcut(
            keyCode: UInt16(kVK_ANSI_C),
            modifierFlags: CGEventFlags.maskCommand.rawValue
        )
        #expect(shortcut.displayString == "\u{2318}C")
    }

    @Test("Ctrl+Alt+Delete shows all modifier symbols and delete")
    func ctrlAltDelete() {
        let shortcut = KeyShortcut(
            keyCode: UInt16(kVK_Delete),
            modifierFlags: CGEventFlags.maskControl.rawValue | CGEventFlags.maskAlternate.rawValue
        )
        #expect(shortcut.displayString == "\u{2303}\u{2325}\u{232B}")
    }

    @Test("Plain key with no modifiers shows just the key name")
    func plainKey() {
        let shortcut = KeyShortcut(keyCode: UInt16(kVK_ANSI_A), modifierFlags: 0)
        #expect(shortcut.displayString == "A")
    }

    @Test("All four modifiers in correct order")
    func allModifiers() {
        let flags = CGEventFlags.maskControl.rawValue
            | CGEventFlags.maskAlternate.rawValue
            | CGEventFlags.maskShift.rawValue
            | CGEventFlags.maskCommand.rawValue
        let shortcut = KeyShortcut(keyCode: UInt16(kVK_ANSI_X), modifierFlags: flags)
        #expect(shortcut.displayString == "\u{2303}\u{2325}\u{21E7}\u{2318}X")
    }

    @Test("Shift+Cmd+Z (redo)")
    func shiftCmdZ() {
        let flags = CGEventFlags.maskShift.rawValue | CGEventFlags.maskCommand.rawValue
        let shortcut = KeyShortcut(keyCode: UInt16(kVK_ANSI_Z), modifierFlags: flags)
        #expect(shortcut.displayString == "\u{21E7}\u{2318}Z")
    }
}

// MARK: - KeyShortcut.keyName(for:)

@Suite("KeyShortcut.keyName")
struct KeyShortcutKeyNameTests {
    @Test("Letters A through Z")
    func letters() {
        #expect(KeyShortcut.keyName(for: UInt16(kVK_ANSI_A)) == "A")
        #expect(KeyShortcut.keyName(for: UInt16(kVK_ANSI_M)) == "M")
        #expect(KeyShortcut.keyName(for: UInt16(kVK_ANSI_Z)) == "Z")
    }

    @Test("Numbers 0 through 9")
    func numbers() {
        #expect(KeyShortcut.keyName(for: UInt16(kVK_ANSI_0)) == "0")
        #expect(KeyShortcut.keyName(for: UInt16(kVK_ANSI_5)) == "5")
        #expect(KeyShortcut.keyName(for: UInt16(kVK_ANSI_9)) == "9")
    }

    @Test("F-keys")
    func fKeys() {
        #expect(KeyShortcut.keyName(for: UInt16(kVK_F1)) == "F1")
        #expect(KeyShortcut.keyName(for: UInt16(kVK_F5)) == "F5")
        #expect(KeyShortcut.keyName(for: UInt16(kVK_F12)) == "F12")
    }

    @Test("Special keys: Return, Tab, Space, arrows")
    func specialKeys() {
        #expect(KeyShortcut.keyName(for: UInt16(kVK_Return)) == "\u{21A9}")
        #expect(KeyShortcut.keyName(for: UInt16(kVK_Tab)) == "\u{21E5}")
        #expect(KeyShortcut.keyName(for: UInt16(kVK_Space)) == "\u{2423}")
        #expect(KeyShortcut.keyName(for: UInt16(kVK_LeftArrow)) == "\u{2190}")
        #expect(KeyShortcut.keyName(for: UInt16(kVK_RightArrow)) == "\u{2192}")
        #expect(KeyShortcut.keyName(for: UInt16(kVK_UpArrow)) == "\u{2191}")
        #expect(KeyShortcut.keyName(for: UInt16(kVK_DownArrow)) == "\u{2193}")
    }

    @Test("Delete keys")
    func deleteKeys() {
        #expect(KeyShortcut.keyName(for: UInt16(kVK_Delete)) == "\u{232B}")
        #expect(KeyShortcut.keyName(for: UInt16(kVK_ForwardDelete)) == "\u{2326}")
    }

    @Test("Escape")
    func escape() {
        #expect(KeyShortcut.keyName(for: UInt16(kVK_Escape)) == "\u{238B}")
    }

    @Test("Navigation keys")
    func navigationKeys() {
        #expect(KeyShortcut.keyName(for: UInt16(kVK_Home)) == "\u{2196}")
        #expect(KeyShortcut.keyName(for: UInt16(kVK_End)) == "\u{2198}")
        #expect(KeyShortcut.keyName(for: UInt16(kVK_PageUp)) == "\u{21DE}")
        #expect(KeyShortcut.keyName(for: UInt16(kVK_PageDown)) == "\u{21DF}")
    }

    @Test("Punctuation keys")
    func punctuation() {
        #expect(KeyShortcut.keyName(for: UInt16(kVK_ANSI_Minus)) == "-")
        #expect(KeyShortcut.keyName(for: UInt16(kVK_ANSI_Equal)) == "=")
        #expect(KeyShortcut.keyName(for: UInt16(kVK_ANSI_LeftBracket)) == "[")
        #expect(KeyShortcut.keyName(for: UInt16(kVK_ANSI_RightBracket)) == "]")
        #expect(KeyShortcut.keyName(for: UInt16(kVK_ANSI_Backslash)) == "\\")
        #expect(KeyShortcut.keyName(for: UInt16(kVK_ANSI_Semicolon)) == ";")
        #expect(KeyShortcut.keyName(for: UInt16(kVK_ANSI_Quote)) == "'")
        #expect(KeyShortcut.keyName(for: UInt16(kVK_ANSI_Comma)) == ",")
        #expect(KeyShortcut.keyName(for: UInt16(kVK_ANSI_Period)) == ".")
        #expect(KeyShortcut.keyName(for: UInt16(kVK_ANSI_Slash)) == "/")
        #expect(KeyShortcut.keyName(for: UInt16(kVK_ANSI_Grave)) == "`")
    }

    @Test("Unknown key code falls back to Key<code>")
    func unknownKeyCode() {
        #expect(KeyShortcut.keyName(for: 255) == "Key255")
    }
}

// MARK: - SwipeDirection

@Suite("SwipeDirection")
struct SwipeDirectionTests {
    @Test("displayName for all directions")
    func displayNames() {
        #expect(SwipeDirection.up.displayName == "Swipe Up")
        #expect(SwipeDirection.down.displayName == "Swipe Down")
        #expect(SwipeDirection.left.displayName == "Swipe Left")
        #expect(SwipeDirection.right.displayName == "Swipe Right")
    }

    @Test("symbolName for all directions")
    func symbolNames() {
        #expect(SwipeDirection.up.symbolName == "arrow.up")
        #expect(SwipeDirection.down.symbolName == "arrow.down")
        #expect(SwipeDirection.left.symbolName == "arrow.left")
        #expect(SwipeDirection.right.symbolName == "arrow.right")
    }
}

// MARK: - SwyperConfig.swipeThresholdValue

@Suite("SwyperConfig.swipeThresholdValue")
struct SwipeThresholdTests {
    @Test("Sensitivity 0.0 maps to threshold 0.13")
    func lowSensitivity() {
        var config = SwyperConfig()
        config.swipeSensitivity = 0.0
        #expect(config.swipeThresholdValue == Float(0.13))
    }

    @Test("Sensitivity 0.5 maps to threshold 0.08")
    func mediumSensitivity() {
        var config = SwyperConfig()
        config.swipeSensitivity = 0.5
        #expect(config.swipeThresholdValue == Float(0.08))
    }

    @Test("Sensitivity 1.0 maps to threshold 0.03")
    func highSensitivity() {
        var config = SwyperConfig()
        config.swipeSensitivity = 1.0
        #expect(config.swipeThresholdValue == Float(0.03))
    }
}

// MARK: - SwyperConfig.mapping(for:)

@Suite("SwyperConfig.mapping")
struct ConfigMappingTests {
    @Test("Returns app-specific mapping when bundle ID matches")
    func appSpecificMapping() {
        var config = SwyperConfig()
        let appMapping = AppMapping(
            bundleID: "com.example.app",
            displayName: "Example",
            shortcuts: [.left: KeyShortcut(keyCode: UInt16(kVK_ANSI_H), modifierFlags: 0)]
        )
        config.appMappings = [appMapping]

        let result = config.mapping(for: "com.example.app")
        #expect(result.bundleID == "com.example.app")
        #expect(result.displayName == "Example")
    }

    @Test("Falls back to default mapping when no app match")
    func fallbackToDefault() {
        var config = SwyperConfig()
        config.defaultMapping = AppMapping(displayName: "Default")
        config.appMappings = [
            AppMapping(bundleID: "com.other.app", displayName: "Other")
        ]

        let result = config.mapping(for: "com.unknown.app")
        #expect(result.bundleID == nil)
        #expect(result.displayName == "Default")
    }

    @Test("Falls back to default mapping when bundle ID is nil")
    func nilBundleID() {
        let config = SwyperConfig()
        let result = config.mapping(for: nil)
        #expect(result.bundleID == nil)
    }
}

// MARK: - SwyperConfig.shortcut(for:direction:bundleID:)

@Suite("SwyperConfig.shortcut")
struct ConfigShortcutTests {
    @Test("Returns per-app shortcut when configured")
    func perAppShortcut() {
        var config = SwyperConfig()
        let shortcut = KeyShortcut(keyCode: UInt16(kVK_ANSI_L), modifierFlags: CGEventFlags.maskCommand.rawValue)
        config.appMappings = [
            AppMapping(
                bundleID: "com.example.app",
                displayName: "Example",
                shortcuts: [.right: shortcut]
            )
        ]

        let result = config.shortcut(for: .right, bundleID: "com.example.app")
        #expect(result == shortcut)
    }

    @Test("Falls back to default when app has no shortcut for direction")
    func fallbackToDefaultShortcut() {
        var config = SwyperConfig()
        let defaultShortcut = KeyShortcut(
            keyCode: UInt16(kVK_ANSI_D),
            modifierFlags: CGEventFlags.maskCommand.rawValue
        )
        config.defaultMapping = AppMapping(
            displayName: "Default",
            shortcuts: [.left: defaultShortcut]
        )
        config.appMappings = [
            AppMapping(
                bundleID: "com.example.app",
                displayName: "Example",
                shortcuts: [.right: KeyShortcut(keyCode: UInt16(kVK_ANSI_R), modifierFlags: 0)]
            )
        ]

        let result = config.shortcut(for: .left, bundleID: "com.example.app")
        #expect(result == defaultShortcut)
    }

    @Test("Returns nil when nothing configured")
    func nilWhenUnconfigured() {
        let config = SwyperConfig()
        let result = config.shortcut(for: .up, bundleID: nil)
        #expect(result == nil)
    }

    @Test("Returns nil when no default and no app mapping")
    func nilForUnknownApp() {
        let config = SwyperConfig()
        let result = config.shortcut(for: .down, bundleID: "com.nonexistent.app")
        #expect(result == nil)
    }
}
