import AppKit
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let configManager = ConfigManager()
    let frontAppMonitor = FrontAppMonitor()
    let updaterManager = UpdaterManager()
    let permissionChecker = PermissionChecker()
    private var multitouchManager: MultitouchManager?
    private let logger = Logger(subsystem: "com.swyper.app", category: "app")

    func applicationDidFinishLaunching(_ notification: Notification) {
        permissionChecker.startChecking()

        guard let mtManager = MultitouchManager() else {
            logger.error("Failed to load MultitouchSupport framework")
            return
        }

        multitouchManager = mtManager
        mtManager.onSwipe = { [weak self] direction in
            self?.handleSwipe(direction)
        }
        mtManager.start()
        logger.info("Swyper started")
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissionChecker.stopChecking()
        multitouchManager?.stop()
    }

    private func handleSwipe(_ direction: SwipeDirection) {
        guard configManager.config.isEnabled else { return }

        let bundleID = frontAppMonitor.currentBundleID
        guard let shortcut = configManager.config.shortcut(for: direction, bundleID: bundleID) else {
            return
        }

        logger.debug("Swipe \(direction.rawValue) -> \(shortcut.displayString) (app: \(bundleID ?? "none"))")
        KeySimulator.postKeyEvent(shortcut: shortcut)
    }
}
