import SwiftUI

@main
struct SwyperApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        MenuBarExtra("Swyper", systemImage: "hand.point.up.braille") {
            MenuBarView()
                .environment(appDelegate.configManager)
        }

        Settings {
            SettingsView()
                .environment(appDelegate.configManager)
                .environment(appDelegate.frontAppMonitor)
        }
    }
}
