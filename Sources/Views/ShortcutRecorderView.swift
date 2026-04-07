import SwiftUI
import AppKit
import Carbon.HIToolbox

struct ShortcutRecorderView: NSViewRepresentable {
    @Binding var shortcut: KeyShortcut?

    func makeNSView(context: Context) -> ShortcutRecorderNSView {
        let view = ShortcutRecorderNSView()
        view.shortcut = shortcut
        view.onShortcutChanged = { newShortcut in
            shortcut = newShortcut
        }
        return view
    }

    func updateNSView(_ nsView: ShortcutRecorderNSView, context: Context) {
        nsView.shortcut = shortcut
        nsView.needsDisplay = true
    }
}

final class ShortcutRecorderNSView: NSView {
    var shortcut: KeyShortcut?
    var onShortcutChanged: ((KeyShortcut?) -> Void)?

    private var isRecording = false
    private var pendingModifiers: CGEventFlags = []
    private var trackingArea: NSTrackingArea?

    override var acceptsFirstResponder: Bool { true }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 140, height: 24)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 6
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow],
            owner: self
        )
        trackingArea = area
        addTrackingArea(area)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let bgColor: NSColor
        if isRecording {
            bgColor = NSColor.controlAccentColor.withAlphaComponent(0.15)
        } else {
            bgColor = NSColor.controlBackgroundColor
        }
        bgColor.setFill()

        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 6, yRadius: 6)
        path.fill()

        NSColor.separatorColor.setStroke()
        path.lineWidth = 1
        path.stroke()

        let text: String
        let textColor: NSColor

        if isRecording {
            if pendingModifiers.isEmpty {
                text = "Press shortcut..."
                textColor = .secondaryLabelColor
            } else {
                text = modifierString(pendingModifiers)
                textColor = .labelColor
            }
        } else if let shortcut {
            text = shortcut.displayString
            textColor = .labelColor
        } else {
            text = "Click to record"
            textColor = .tertiaryLabelColor
        }

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: textColor
        ]
        let size = (text as NSString).size(withAttributes: attrs)
        let point = NSPoint(
            x: (bounds.width - size.width) / 2,
            y: (bounds.height - size.height) / 2
        )
        (text as NSString).draw(at: point, withAttributes: attrs)
    }

    override func mouseDown(with event: NSEvent) {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        let keyCode = event.keyCode

        // Capture the shortcut
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let cgFlags = cgEventFlags(from: modifiers)

        let newShortcut = KeyShortcut(keyCode: keyCode, modifierFlags: cgFlags.rawValue)
        onShortcutChanged?(newShortcut)
        stopRecording()
    }

    override func flagsChanged(with event: NSEvent) {
        guard isRecording else {
            super.flagsChanged(with: event)
            return
        }

        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        pendingModifiers = cgEventFlags(from: modifiers)
        needsDisplay = true
    }

    override func resignFirstResponder() -> Bool {
        if isRecording {
            stopRecording()
        }
        return super.resignFirstResponder()
    }

    private func startRecording() {
        isRecording = true
        pendingModifiers = []
        window?.makeFirstResponder(self)
        needsDisplay = true
    }

    private func stopRecording() {
        isRecording = false
        pendingModifiers = []
        window?.makeFirstResponder(nil)
        needsDisplay = true
    }

    private func cgEventFlags(from nsFlags: NSEvent.ModifierFlags) -> CGEventFlags {
        var flags = CGEventFlags()
        if nsFlags.contains(.command) { flags.insert(.maskCommand) }
        if nsFlags.contains(.shift) { flags.insert(.maskShift) }
        if nsFlags.contains(.option) { flags.insert(.maskAlternate) }
        if nsFlags.contains(.control) { flags.insert(.maskControl) }
        return flags
    }

    private func modifierString(_ flags: CGEventFlags) -> String {
        var parts: [String] = []
        if flags.contains(.maskControl) { parts.append("\u{2303}") }
        if flags.contains(.maskAlternate) { parts.append("\u{2325}") }
        if flags.contains(.maskShift) { parts.append("\u{21E7}") }
        if flags.contains(.maskCommand) { parts.append("\u{2318}") }
        return parts.joined()
    }
}
