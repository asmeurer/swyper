import Testing
@testable import Swyper

@Suite("Scroll suppression transitions")
struct ScrollSuppressionControllerTests {
    @Test("Disabling Swyper stops active scroll suppression once")
    @MainActor
    func disablingStopsSuppression() {
        let suppressor = MockScrollSuppressor()
        let controller = ScrollSuppressionController(suppressor: suppressor)

        controller.update(isEnabled: true, isAccessibilityGranted: true)
        controller.update(isEnabled: false, isAccessibilityGranted: true)
        controller.update(isEnabled: false, isAccessibilityGranted: false)

        #expect(suppressor.startCount == 1)
        #expect(suppressor.stopCount == 1)
    }

    @Test("Granting accessibility permission retries scroll suppression start")
    @MainActor
    func grantingPermissionStartsSuppression() {
        let suppressor = MockScrollSuppressor()
        let controller = ScrollSuppressionController(suppressor: suppressor)

        controller.update(isEnabled: true, isAccessibilityGranted: false)
        controller.update(isEnabled: true, isAccessibilityGranted: true)
        controller.update(isEnabled: true, isAccessibilityGranted: true)

        #expect(suppressor.startCount == 1)
        #expect(suppressor.stopCount == 0)
    }

    @Test("Failed scroll suppression start retries automatically while enabled")
    @MainActor
    func failedStartIsRetriedAutomatically() async throws {
        let suppressor = MockScrollSuppressor(results: [false, true])
        let controller = ScrollSuppressionController(
            suppressor: suppressor,
            retryDelay: .milliseconds(10)
        )

        controller.update(isEnabled: true, isAccessibilityGranted: true)
        try await Task.sleep(for: .milliseconds(50))

        #expect(suppressor.startCount == 2)
        #expect(suppressor.stopCount == 0)
    }

    @Test("Disabling Swyper cancels a pending retry")
    @MainActor
    func disablingCancelsPendingRetry() async throws {
        let suppressor = MockScrollSuppressor(results: [false, true])
        let controller = ScrollSuppressionController(
            suppressor: suppressor,
            retryDelay: .milliseconds(25)
        )

        controller.update(isEnabled: true, isAccessibilityGranted: true)
        controller.update(isEnabled: false, isAccessibilityGranted: true)
        try await Task.sleep(for: .milliseconds(60))

        #expect(suppressor.startCount == 1)
        #expect(suppressor.stopCount == 0)
    }
}

private final class MockScrollSuppressor: ScrollSuppressing {
    private let startResults: [Bool]
    private(set) var startCount = 0
    private(set) var stopCount = 0

    init(results: [Bool] = [true]) {
        self.startResults = results
    }

    func start() -> Bool {
        startCount += 1
        let index = min(startCount - 1, startResults.count - 1)
        return startResults[index]
    }

    func stop() {
        stopCount += 1
    }
}
