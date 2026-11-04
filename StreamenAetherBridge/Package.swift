// swift-tools-version: 6.2
import PackageDescription

/// A dynamic library so AetherEngine and its AetherLib* frameworks link into an
/// image of their own, apart from KSPlayer's Libav* frameworks in Streamen's.
/// Library evolution keeps the Aether C modules out of Streamen's compile; SwiftPM
/// accepts the unsafe flag because Streamen consumes this package by path.
let package = Package(
    name: "StreamenAetherBridge",
    platforms: [
        .iOS(.v18),
        .tvOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(name: "StreamenAetherBridge", type: .dynamic, targets: ["StreamenAetherBridge"])
    ],
    dependencies: [
        .package(url: "https://github.com/superuser404notfound/AetherEngine", exact: "7.54.0")
    ],
    targets: [
        .target(
            name: "StreamenAetherBridge",
            dependencies: [
                .product(name: "AetherEngine", package: "AetherEngine")
            ],
            swiftSettings: [
                .unsafeFlags(["-enable-library-evolution"]),
                .defaultIsolation(MainActor.self)
            ]
        )
    ]
)
