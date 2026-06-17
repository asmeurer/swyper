import SwiftUI
import ServiceManagement

struct MenuBarView: View {
    @Environment(ConfigManager.self) private var configManager
    @Environment(PermissionChecker.self) private var permissionChecker
    @Environment(\.openSettings) private var openSettings
    @EnvironmentObject private var updaterManager: UpdaterManager

    var body: some View {
        @Bindable var cm = configManager

        if !permissionChecker.isAccessibilityGranted {
            Button("Grant Accessibility Access...") {
                Permissions.openAccessibilitySettings()
            }

            Divider()
        }

        Toggle("Enabled", isOn: $cm.config.isEnabled)

        Divider()

        Button("Settings...") {
            openSettings()
            NSApp.activate()
        }

        Toggle("Launch at Login", isOn: Binding(
            get: { SMAppService.mainApp.status == .enabled },
            set: { newValue in
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    // Login item registration may fail when not running from .app bundle
                }
            }
        ))

        Button("Check for Updates...") {
            updaterManager.checkForUpdates()
        }
        .disabled(!updaterManager.canCheckForUpdates)

        Button("Grant App Management Access...") {
            Permissions.openAppManagementSettings()
        }

        Divider()

        Button("About Swyper") {
            showAboutPanel()
        }

        Button("Quit Swyper") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private func showAboutPanel() {
        let credits = NSAttributedString(
            string: "Maps three-finger trackpad swipe gestures to per-app keyboard shortcuts.\n\n"
                + "https://github.com/asmeurer/swyper",
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )

        let options: [NSApplication.AboutPanelOptionKey: Any] = [
            .applicationName: "Swyper",
            .applicationVersion: appVersion,
            .version: "",
            .credits: credits
        ]

        NSApp.activate()
        NSApp.orderFrontStandardAboutPanel(options: options)
    }
}
