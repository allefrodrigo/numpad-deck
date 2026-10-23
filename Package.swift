// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NumpadDeck",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "NumpadDeck",
            path: "Sources/NumpadDeck",
            swiftSettings: [.unsafeFlags(["-parse-as-library"])]
        )
    ]
)
