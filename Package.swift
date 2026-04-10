// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Swyper",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "Swyper",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources",
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        ),
        .testTarget(
            name: "SwyperTests",
            dependencies: ["Swyper"],
            path: "Tests"
        )
    ]
)
