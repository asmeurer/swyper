// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Swyper",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Swyper",
            path: "Sources",
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        )
    ]
)
