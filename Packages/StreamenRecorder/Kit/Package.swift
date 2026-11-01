// swift-tools-version: 6.0
// StreamenRecorderKit — the shared wire contract (DTOs + coding) and a tiny async
// client for the StreamenRecorder HTTP API. Foundation only: the Streamen app consumes
// this as a local package, so it must never add a dependency to the app graph.

import PackageDescription

let package = Package(
    name: "StreamenRecorderKit",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
        .tvOS(.v18),
        .visionOS(.v2),
    ],
    products: [
        .library(name: "StreamenRecorderKit", targets: ["StreamenRecorderKit"]),
    ],
    targets: [
        .target(
            name: "StreamenRecorderKit",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "StreamenRecorderKitTests",
            dependencies: ["StreamenRecorderKit"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
