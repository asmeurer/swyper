import Testing
import Foundation
import CoreGraphics
import Carbon.HIToolbox
@testable import Swyper

@Suite("Config Serialization")
struct ConfigSerializationTests {

    private let encoder: JSONEncoder = {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        return enc
    }()

    private let decoder = JSONDecoder()

    // MARK: - Round-trip SwyperConfig

    @Test("Full SwyperConfig round-trips through JSON")
    func fullConfigRoundTrip() throws {
        var config = SwyperConfig()
        config.isEnabled = false
        config.swipeSensitivity = 0.7
        config.defaultMapping = AppMapping(
            displayName: "Default",
            shortcuts: [
                .left: KeyShortcut(keyCode: UInt16(kVK_ANSI_H), modifierFlags: CGEventFlags.maskCommand.rawValue),
                .right: KeyShortcut(keyCode: UInt16(kVK_ANSI_L), modifierFlags: CGEventFlags.maskCommand.rawValue)
            ]
        )
        config.appMappings = [
            AppMapping(
                bundleID: "com.apple.Safari",
                displayName: "Safari",
                shortcuts: [
                    .left: KeyShortcut(
                        keyCode: UInt16(kVK_LeftArrow),
                        modifierFlags: CGEventFlags.maskCommand.rawValue
                    ),
                    .right: KeyShortcut(
                        keyCode: UInt16(kVK_RightArrow),
                        modifierFlags: CGEventFlags.maskCommand.rawValue
                    ),
                    .up: KeyShortcut(
                        keyCode: UInt16(kVK_UpArrow),
                        modifierFlags: CGEventFlags.maskCommand.rawValue
                    ),
                    .down: KeyShortcut(
                        keyCode: UInt16(kVK_DownArrow),
                        modifierFlags: CGEventFlags.maskCommand.rawValue
                    )
                ]
            )
        ]

        let data = try encoder.encode(config)
        let decoded = try decoder.decode(SwyperConfig.self, from: data)

        #expect(decoded.isEnabled == config.isEnabled)
        #expect(decoded.swipeSensitivity == config.swipeSensitivity)
        #expect(decoded.defaultMapping.displayName == config.defaultMapping.displayName)
        #expect(decoded.defaultMapping.shortcuts.count == config.defaultMapping.shortcuts.count)
        #expect(decoded.appMappings.count == 1)
        #expect(decoded.appMappings[0].bundleID == "com.apple.Safari")
        #expect(decoded.appMappings[0].shortcuts.count == 4)
    }

    // MARK: - Backward compatibility

    @Test("Decoding JSON missing swipeSensitivity defaults to 0.5")
    func backwardCompatibilityMissingSensitivity() throws {
        // JSON without swipeSensitivity field.
        // Note: [SwipeDirection: KeyShortcut] encodes as an alternating array, not a JSON object,
        // because the key type is not String. An empty dictionary encodes as [].
        let json = """
        {
            "isEnabled": true,
            "defaultMapping": {
                "displayName": "Default",
                "shortcuts": []
            },
            "appMappings": []
        }
        """
        let data = Data(json.utf8)
        let config = try decoder.decode(SwyperConfig.self, from: data)
        #expect(config.swipeSensitivity == 0.5)
        #expect(config.isEnabled == true)
    }

    // MARK: - KeyShortcut round-trip

    @Test("KeyShortcut round-trips through JSON")
    func keyShortcutRoundTrip() throws {
        let shortcut = KeyShortcut(
            keyCode: UInt16(kVK_ANSI_C),
            modifierFlags: CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue
        )

        let data = try encoder.encode(shortcut)
        let decoded = try decoder.decode(KeyShortcut.self, from: data)

        #expect(decoded == shortcut)
        #expect(decoded.keyCode == shortcut.keyCode)
        #expect(decoded.modifierFlags == shortcut.modifierFlags)
    }

    // MARK: - AppMapping round-trip

    @Test("AppMapping round-trips through JSON")
    func appMappingRoundTrip() throws {
        let mapping = AppMapping(
            bundleID: "com.test.app",
            displayName: "Test App",
            shortcuts: [
                .up: KeyShortcut(keyCode: UInt16(kVK_ANSI_K), modifierFlags: 0),
                .down: KeyShortcut(keyCode: UInt16(kVK_ANSI_J), modifierFlags: 0)
            ]
        )

        let data = try encoder.encode(mapping)
        let decoded = try decoder.decode(AppMapping.self, from: data)

        #expect(decoded.bundleID == mapping.bundleID)
        #expect(decoded.displayName == mapping.displayName)
        #expect(decoded.shortcuts.count == mapping.shortcuts.count)
        #expect(decoded.shortcuts[.up] == mapping.shortcuts[.up])
        #expect(decoded.shortcuts[.down] == mapping.shortcuts[.down])
    }

    // MARK: - SwipeDirection raw values

    @Test("SwipeDirection raw values are stable strings")
    func swipeDirectionRawValues() {
        #expect(SwipeDirection.up.rawValue == "up")
        #expect(SwipeDirection.down.rawValue == "down")
        #expect(SwipeDirection.left.rawValue == "left")
        #expect(SwipeDirection.right.rawValue == "right")
    }

    @Test("SwipeDirection round-trips through JSON encoding")
    func swipeDirectionJSONRoundTrip() throws {
        for direction in SwipeDirection.allCases {
            let data = try encoder.encode(direction)
            let decoded = try decoder.decode(SwipeDirection.self, from: data)
            #expect(decoded == direction)
        }
    }
}
