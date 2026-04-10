import Foundation

@Observable
@MainActor
final class ConfigManager {
    var onConfigChanged: (() -> Void)?

    // Transient UI state for swipe feedback (not persisted)
    var lastSwipeDirection: SwipeDirection?
    var lastSwipeTime: Date?

    var config: SwyperConfig {
        didSet {
            save()
            onConfigChanged?()
        }
    }

    private let fileURL: URL

    init() {
        // swiftlint:disable:next force_unwrapping
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let swyperDir = appSupport.appendingPathComponent("Swyper", isDirectory: true)
        try? FileManager.default.createDirectory(at: swyperDir, withIntermediateDirectories: true)
        self.fileURL = swyperDir.appendingPathComponent("config.json")
        self.config = SwyperConfig()
        load()
    }

    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        if let loaded = try? decoder.decode(SwyperConfig.self, from: data) {
            self.config = loaded
        }
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(config) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
