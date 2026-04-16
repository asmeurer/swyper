import os

protocol ScrollSuppressing: AnyObject {
    func start() -> Bool
    func stop()
}

extension ScrollSuppressor: ScrollSuppressing {}

@MainActor
final class ScrollSuppressionController {
    private static let defaultRetryDelay: Duration = .seconds(1)

    private let suppressor: any ScrollSuppressing
    private let retryDelay: Duration
    private let logger = Logger(subsystem: "com.swyper.app", category: "scrollsuppressioncontroller")
    private var isRunning = false
    private var shouldRun = false
    private var retryTask: Task<Void, Never>?

    init(
        suppressor: any ScrollSuppressing,
        retryDelay: Duration = ScrollSuppressionController.defaultRetryDelay
    ) {
        self.suppressor = suppressor
        self.retryDelay = retryDelay
    }

    func update(isEnabled: Bool, isAccessibilityGranted: Bool) {
        let previousShouldRun = shouldRun
        shouldRun = isEnabled && isAccessibilityGranted

        guard shouldRun else {
            cancelRetry()
            if isRunning {
                isRunning = false
                suppressor.stop()
            }
            return
        }

        guard !isRunning else { return }
        guard !previousShouldRun else { return }

        attemptStart()
    }

    func stop() {
        shouldRun = false
        cancelRetry()
        if isRunning {
            suppressor.stop()
            isRunning = false
        }
    }

    private func attemptStart() {
        guard shouldRun, !isRunning else { return }

        isRunning = suppressor.start()
        guard !isRunning else {
            cancelRetry()
            return
        }

        scheduleRetryIfNeeded()
    }

    private func scheduleRetryIfNeeded() {
        guard shouldRun, !isRunning, retryTask == nil else { return }

        logger.warning("Scroll suppressor start failed; scheduling retry")
        retryTask = Task { @MainActor [weak self, retryDelay] in
            try? await Task.sleep(for: retryDelay)
            guard !Task.isCancelled else { return }
            self?.retryStart()
        }
    }

    private func retryStart() {
        retryTask = nil
        attemptStart()
    }

    private func cancelRetry() {
        retryTask?.cancel()
        retryTask = nil
    }
}
