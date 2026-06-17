import SwiftUI

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
        let bodyFont = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        let credits = NSMutableAttributedString(
            string: "Maps three-finger trackpad swipe gestures to per-app keyboard shortcuts.\n\n",
            attributes: [
                .font: bodyFont,
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )

        let website = "https://www.asmeurer.com/swyper/"
        let repository = "https://github.com/asmeurer/swyper"
        guard let websiteURL = URL(string: website),
              let repositoryURL = URL(string: repository) else {
            return
        }

        credits.append(NSAttributedString(
            string: website,
            attributes: [
                .font: bodyFont,
                .link: websiteURL
            ]
        ))

        credits.append(NSAttributedString(
            string: "\n",
            attributes: [.font: bodyFont]
        ))
        credits.append(NSAttributedString(
            string: repository,
            attributes: [
                .font: bodyFont,
                .link: repositoryURL
            ]
        ))

        credits.append(NSAttributedString(
            string: "\n\nBuilt with Claude.\n© 2026 Aaron Meurer",
            attributes: [
                .font: bodyFont,
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        ))

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
