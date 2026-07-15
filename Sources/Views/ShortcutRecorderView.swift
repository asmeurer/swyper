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
    private var eventMonitor: Any?

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

    // Key events arrive through a local event monitor rather than keyDown:
    // shortcuts with Command (e.g. ⌘W) are routed to the window's key-equivalent
    // handling before they reach the responder chain, so waiting for keyDown
    // lets them trigger their normal action (closing the window) mid-recording.
    // The monitor sees events first and returning nil swallows them.
    private func handleRecordingEvent(_ event: NSEvent) -> NSEvent? {
        switch event.type {
        case .flagsChanged:
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            pendingModifiers = cgEventFlags(from: modifiers)
            needsDisplay = true
            return nil
        case .keyDown:
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            // Escape with no modifiers cancels recording instead of being captured.
            if event.keyCode == UInt16(kVK_Escape) && modifiers.isEmpty {
                stopRecording()
                return nil
            }
            let cgFlags = cgEventFlags(from: modifiers)
            let newShortcut = KeyShortcut(keyCode: event.keyCode, modifierFlags: cgFlags.rawValue)
            onShortcutChanged?(newShortcut)
            stopRecording()
            return nil
        default:
            return event
        }
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
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self, self.isRecording else { return event }
            return self.handleRecordingEvent(event)
        }
        needsDisplay = true
    }

    private func stopRecording() {
        isRecording = false
        pendingModifiers = []
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
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
