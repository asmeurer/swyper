import ApplicationServices
import Observation

@MainActor
@Observable
final class PermissionChecker {
    var onAccessibilityPermissionChanged: ((Bool) -> Void)?
    private(set) var isAccessibilityGranted = AXIsProcessTrusted()
    private var timer: Timer?

    func startChecking() {
        updateAccessibilityStatus(AXIsProcessTrusted())
        // Poll periodically so the UI updates after the user grants permission
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateAccessibilityStatus(AXIsProcessTrusted())
            }
        }
    }

    func stopChecking() {
        timer?.invalidate()
        timer = nil
    }

    private func updateAccessibilityStatus(_ isGranted: Bool) {
        let previousValue = isAccessibilityGranted
        isAccessibilityGranted = isGranted

        guard previousValue != isGranted else { return }
        onAccessibilityPermissionChanged?(isGranted)
    }
}
