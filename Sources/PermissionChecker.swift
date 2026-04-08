import ApplicationServices
import Observation

@MainActor
@Observable
final class PermissionChecker {
    private(set) var isAccessibilityGranted = AXIsProcessTrusted()
    private var timer: Timer?

    func startChecking() {
        isAccessibilityGranted = AXIsProcessTrusted()
        // Poll periodically so the UI updates after the user grants permission
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.isAccessibilityGranted = AXIsProcessTrusted()
            }
        }
    }

    func stopChecking() {
        timer?.invalidate()
        timer = nil
    }
}
