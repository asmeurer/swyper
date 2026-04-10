import Foundation

let appVersion = resolveAppVersion()

private func resolveAppVersion() -> String {
    if let bundledDisplayVersion = Bundle.main.object(
        forInfoDictionaryKey: "SwyperDisplayVersion"
    ) as? String {
        return bundledDisplayVersion
    }

    if let bundledVersion = Bundle.main.object(
        forInfoDictionaryKey: "CFBundleShortVersionString"
    ) as? String {
        return bundledVersion
    }

    return sourceCheckoutVersion() ?? "0.3.0"
}

private func sourceCheckoutVersion() -> String? {
    let sourceFile = URL(fileURLWithPath: #filePath)
    let versionFile = sourceFile
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("VERSION")

    guard let rawVersion = try? String(
        contentsOf: versionFile,
        encoding: .utf8
    ) else {
        return nil
    }

    let version = rawVersion.trimmingCharacters(in: .whitespacesAndNewlines)
    return version.isEmpty ? nil : version
}
