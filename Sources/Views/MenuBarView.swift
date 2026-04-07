import SwiftUI
import ServiceManagement

struct MenuBarView: View {
    @Environment(ConfigManager.self) private var configManager

    var body: some View {
        @Bindable var cm = configManager

        Toggle("Enabled", isOn: $cm.config.isEnabled)

        Divider()

        SettingsLink {
            Text("Settings...")
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

        Divider()

        Text("Swyper v\(appVersion)")
            .foregroundStyle(.secondary)

        Button("Quit Swyper") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
