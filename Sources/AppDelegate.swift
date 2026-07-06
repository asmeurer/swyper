import AppKit
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let configManager = ConfigManager()
    let frontAppMonitor = FrontAppMonitor()
    let updaterManager = UpdaterManager()
    let permissionChecker = PermissionChecker()
    private var multitouchManager: MultitouchManager?
    private var scrollSuppressor: ScrollSuppressor?
    private var scrollSuppressionController: ScrollSuppressionController?
    private let logger = Logger(subsystem: "com.swyper.app", category: "app")

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let mtManager = MultitouchManager() else {
            logger.error("Failed to load MultitouchSupport framework")
            return
        }

        multitouchManager = mtManager
        mtManager.updateSwipeThreshold(configManager.config.swipeThresholdValue)
        mtManager.onSwipe = { [weak self] direction in
            self?.handleSwipe(direction)
        }

        let suppressor = ScrollSuppressor()
        scrollSuppressor = suppressor
        scrollSuppressionController = ScrollSuppressionController(suppressor: suppressor)
        permissionChecker.onAccessibilityPermissionChanged = { [weak self] _ in
            self?.updateScrollSuppressorState()
        }
        permissionChecker.startChecking()
        mtManager.onThreeFingerFrame = { [weak suppressor] in
            suppressor?.noteThreeFingerActivity()
        }

        mtManager.start()

        configManager.onConfigChanged = { [weak self] in
            guard let self else { return }
            self.multitouchManager?.updateSwipeThreshold(self.configManager.config.swipeThresholdValue)
            self.updateScrollSuppressorState()
        }
        updateScrollSuppressorState()

        logger.info("Swyper started")
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissionChecker.stopChecking()
        multitouchManager?.stop()
        scrollSuppressionController?.stop()
    }

    private func handleSwipe(_ direction: SwipeDirection) {
        guard configManager.config.isEnabled else {
            logger.log("Swipe \(direction.rawValue, privacy: .public) ignored: Swyper is disabled")
            return
        }

        // Update swipe indicator regardless of shortcut configuration
        configManager.lastSwipeDirection = direction
        configManager.lastSwipeTime = Date()

        let bundleID = frontAppMonitor.currentBundleID
        guard let shortcut = configManager.config.shortcut(for: direction, bundleID: bundleID) else {
            logger.log("""
                Swipe \(direction.rawValue, privacy: .public) ignored: no shortcut configured \
                for \(bundleID ?? "unknown app", privacy: .public)
                """)
            return
        }

        // Skip key events when Swyper's own window is active to avoid system beep
        guard !NSApp.isActive else {
            logger.log("Swipe \(direction.rawValue, privacy: .public) ignored: Swyper window is active")
            return
        }

        logger.log("""
            Swipe \(direction.rawValue, privacy: .public) -> \
            \(shortcut.displayString, privacy: .public) \
            (app: \(bundleID ?? "none", privacy: .public))
            """)
        KeySimulator.postKeyEvent(shortcut: shortcut)
    }

    private func updateScrollSuppressorState() {
        scrollSuppressionController?.update(
            isEnabled: configManager.config.isEnabled,
            isAccessibilityGranted: permissionChecker.isAccessibilityGranted
        )
    }
}
