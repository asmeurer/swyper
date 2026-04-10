import SwiftUI
import ServiceManagement

struct MenuBarView: View {
    @Environment(ConfigManager.self) private var configManager
    @Environment(PermissionChecker.self) private var permissionChecker
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
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
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

        Text("Swyper v\(appVersion)")
            .foregroundStyle(.secondary)

        Button("Quit Swyper") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
