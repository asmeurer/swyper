protocol ScrollSuppressing: AnyObject {
    func start() -> Bool
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

        if shouldRun {
            isRunning = suppressor.start()
        } else {
            isRunning = false
            suppressor.stop()
        }
    }

    func stop() {
        isRunning = false
        suppressor.stop()
    }
}
