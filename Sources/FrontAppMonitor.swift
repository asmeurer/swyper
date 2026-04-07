import AppKit

@Observable
@MainActor
final class FrontAppMonitor {
    var currentBundleID: String?
    var currentAppName: String?

    private var observer: (any NSObjectProtocol)?

    init() {
        let frontApp = NSWorkspace.shared.frontmostApplication
        currentBundleID = frontApp?.bundleIdentifier
        currentAppName = frontApp?.localizedName

        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }
            MainActor.assumeIsolated {
                self?.currentBundleID = app.bundleIdentifier
                self?.currentAppName = app.localizedName
            }
        }
    }
}
