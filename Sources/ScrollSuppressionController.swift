protocol ScrollSuppressing: AnyObject {
    func start()
    func stop()
}

extension ScrollSuppressor: ScrollSuppressing {}

final class ScrollSuppressionController {
    private let suppressor: any ScrollSuppressing
    private var isRunning = false

    init(suppressor: any ScrollSuppressing) {
        self.suppressor = suppressor
    }

    func update(isEnabled: Bool, isAccessibilityGranted: Bool) {
        let shouldRun = isEnabled && isAccessibilityGranted
        guard shouldRun != isRunning else { return }

        isRunning = shouldRun
        if shouldRun {
            suppressor.start()
        } else {
            suppressor.stop()
        }
    }

    func stop() {
        isRunning = false
        suppressor.stop()
    }
}
