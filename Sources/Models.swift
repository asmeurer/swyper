import CoreGraphics
import Carbon.HIToolbox

enum SwipeDirection: String, Codable, CaseIterable, Sendable {
    case up, down, left, right

    var displayName: String {
        switch self {
        case .up: "Swipe Up"
        case .down: "Swipe Down"
        case .left: "Swipe Left"
        case .right: "Swipe Right"
        }
    }

    var symbolName: String {
        switch self {
        case .up: "arrow.up"
        case .down: "arrow.down"
        case .left: "arrow.left"
        case .right: "arrow.right"
        }
    }
}

struct KeyShortcut: Codable, Equatable, Hashable, Sendable {
    var keyCode: UInt16
    var modifierFlags: UInt64

    var cgEventFlags: CGEventFlags {
        CGEventFlags(rawValue: modifierFlags)
    }

    var displayString: String {
        var parts: [String] = []
        let flags = cgEventFlags
        if flags.contains(.maskControl) { parts.append("\u{2303}") }
        if flags.contains(.maskAlternate) { parts.append("\u{2325}") }
        if flags.contains(.maskShift) { parts.append("\u{21E7}") }
        if flags.contains(.maskCommand) { parts.append("\u{2318}") }
        parts.append(Self.keyName(for: keyCode))
        return parts.joined()
    }

    // swiftlint:disable:next cyclomatic_complexity
    static func keyName(for keyCode: UInt16) -> String {
        let code = Int(keyCode)
        switch code {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        case kVK_Return: return "\u{21A9}"
        case kVK_Tab: return "\u{21E5}"
        case kVK_Space: return "\u{2423}"
        case kVK_Delete: return "\u{232B}"
        case kVK_ForwardDelete: return "\u{2326}"
        case kVK_Escape: return "\u{238B}"
        case kVK_LeftArrow: return "\u{2190}"
        case kVK_RightArrow: return "\u{2192}"
        case kVK_UpArrow: return "\u{2191}"
        case kVK_DownArrow: return "\u{2193}"
        case kVK_Home: return "\u{2196}"
        case kVK_End: return "\u{2198}"
        case kVK_PageUp: return "\u{21DE}"
        case kVK_PageDown: return "\u{21DF}"
        case kVK_ANSI_Minus: return "-"
        case kVK_ANSI_Equal: return "="
        case kVK_ANSI_LeftBracket: return "["
        case kVK_ANSI_RightBracket: return "]"
        case kVK_ANSI_Backslash: return "\\"
        case kVK_ANSI_Semicolon: return ";"
        case kVK_ANSI_Quote: return "'"
        case kVK_ANSI_Comma: return ","
        case kVK_ANSI_Period: return "."
        case kVK_ANSI_Slash: return "/"
        case kVK_ANSI_Grave: return "`"
        default: return "Key\(keyCode)"
        }
    }
}

struct AppMapping: Codable, Sendable, Identifiable {
    var id: String { bundleID ?? "default" }
    var bundleID: String?
    var displayName: String
    var shortcuts: [SwipeDirection: KeyShortcut]

    init(bundleID: String? = nil, displayName: String = "Default", shortcuts: [SwipeDirection: KeyShortcut] = [:]) {
        self.bundleID = bundleID
        self.displayName = displayName
        self.shortcuts = shortcuts
    }
}

struct SwyperConfig: Codable, Sendable {
    var isEnabled: Bool = true
    var defaultMapping: AppMapping = AppMapping()
    var appMappings: [AppMapping] = []

    func mapping(for bundleID: String?) -> AppMapping {
        if let bundleID,
           let appMapping = appMappings.first(where: { $0.bundleID == bundleID }) {
            return appMapping
        }
        return defaultMapping
    }

    func shortcut(for direction: SwipeDirection, bundleID: String?) -> KeyShortcut? {
        let m = mapping(for: bundleID)
        if let shortcut = m.shortcuts[direction] {
            return shortcut
        }
        if m.bundleID != nil {
            return defaultMapping.shortcuts[direction]
        }
        return nil
    }
}
