// swift-tools-version: 6.0
import Foundation
import PackageDescription

// FFmpeg comes from a checksum-pinned xcframework attached to a GitHub release, so
// consuming this package requires nothing from build/ — SwiftPM just downloads it
// (PLAN.md §5).
//
// The artifact is versioned by the FFmpeg build it contains, not by the engine's
// release it happens to hang off: this URL only moves when build/versions.json, the
// configure flags, or the patch set change. Engine releases in between keep pointing
// at the same binary.
//
// A locally built xcframework wins when present, which is the development override —
// build/scripts/make-xcframework.sh writes exactly there, so anyone iterating on the
// FFmpeg build tests their own binary rather than silently linking the released one.
// Consumers never have that directory, so their resolution is unconditional.
let ffmpegArtifactURL = "https://github.com/bilipp/LumeEngine/releases/download/v0.3.0/FFmpeg.xcframework.zip"
let ffmpegArtifactChecksum = "4aed787a0cf05067395bb5b07f1af96c25e1314a841bc1597e37964dd009b5b0"

let localFFmpegPath = "BinaryDependencies/FFmpeg.xcframework"
let hasLocalFFmpeg = FileManager.default.fileExists(
    atPath: URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent(localFFmpegPath)
        .path
)

let ffmpegTarget: Target = hasLocalFFmpeg
    ? .binaryTarget(name: "CFFmpeg", path: localFFmpegPath)
    : .binaryTarget(name: "CFFmpeg", url: ffmpegArtifactURL, checksum: ffmpegArtifactChecksum)

// `-enable-library-evolution` is load-bearing, and it can only be expressed as an
// unsafe flag — this toolchain's SwiftSetting has no library-evolution option.
//
// Why it matters: with evolution, StreamenEngineCore's module interface does not pull the
// CFFmpeg C module into a consumer's compile. Without it, an app that links StreamenEngine
// *and* another FFmpeg-based engine compiles two conflicting definitions of the same C
// types and Clang refuses:
//
//     'AV_PIX_FMT_OHCODEC' from module 'CFFmpeg' is not present in definition of
//     'enum AVPixelFormat' in module 'Libavutil'
//
// That is precisely Streamen's configuration (StreamenEngine alongside KSPlayer/FFmpegKit), so
// dropping the flag broke it. Nesting the headers under streamen_ffmpeg/ prevents header
// path collisions but cannot prevent C-namespace type redefinition.
//
// The catch: SwiftPM rejects unsafeFlags in any package resolved as a *versioned*
// dependency, which makes `.package(url:from:)` fail outright. So the flag is applied
// everywhere except there — path dependencies (Streamen, and engine development) keep it,
// while version-resolved consumers go without.
//
// Consequence worth knowing: a consumer that adds this package by URL *and* links a
// second FFmpeg will hit the collision above. Such a consumer should vendor the package
// as a path/submodule dependency instead, which restores evolution. Revisit if SwiftPM
// ever exposes library evolution as a safe setting.
let isVersionedDependency = #filePath.contains("/checkouts/")
let evolutionSettings: [SwiftSetting] = isVersionedDependency
    ? []
    : [.unsafeFlags(["-enable-library-evolution"])]

// System libraries/frameworks required by the static FFmpeg xcframework.
let ffmpegLinkerSettings: [LinkerSetting] = [
    .linkedLibrary("z"),
    .linkedLibrary("bz2"),
    .linkedLibrary("iconv"),
    .linkedFramework("CoreFoundation"),
    .linkedFramework("CoreMedia"),
    .linkedFramework("CoreVideo"),
    .linkedFramework("VideoToolbox"),
    .linkedFramework("AudioToolbox"),
    .linkedFramework("Security"),
]

let package = Package(
    name: "StreamenEngine",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
        .tvOS(.v18),
        .visionOS(.v2),
    ],
    products: [
        // Dynamic: FFmpeg 9 symbols stay inside StreamenEngine.framework (two-level
        // namespace), so apps can also link engines embedding other FFmpeg builds
        // without symbol collisions.
        .library(name: "StreamenEngine", type: .dynamic, targets: ["StreamenEngine"]),
        // macOS triage tool: `swift run streamenctl --help`. Drives a session
        // headlessly against a URL; nothing a consumer app links.
        .executable(name: "streamenctl", targets: ["streamenctl"]),
    ],
    targets: [
        // FFmpeg 9.0.x static libraries: released artifact, or a local build when
        // one is present (resolved above).
        ffmpegTarget,
        .target(
            name: "StreamenFFmpegBridge",
            dependencies: ["CFFmpeg"]
        ),

        // Data plane + control plane core: demux, decode, clock, channels. No UI.
        // Library evolution + `internal import CFFmpeg` keep the FFmpeg module
        // out of consumers' compiles entirely — apps can link other FFmpeg-based
        // engines without C-module type collisions.
        .target(
            name: "StreamenEngineCore",
            dependencies: ["StreamenFFmpegBridge"],
            swiftSettings: evolutionSettings,
            linkerSettings: ffmpegLinkerSettings
        ),

        // Public facade (StreamenPlayer, events, SwiftUI view).
        .target(
            name: "StreamenEngine",
            dependencies: ["StreamenEngineCore"],
            swiftSettings: evolutionSettings
        ),

        // macOS demo app: `swift run StreamenEngineDemo`.
        .executableTarget(
            name: "StreamenEngineDemo",
            dependencies: ["StreamenEngine"],
            path: "DemoApp/Sources"
        ),

        // streamenctl's logic (argument parsing, URL redaction, the headless run,
        // output), kept out of the executable so the tests can reach it.
        .target(
            name: "StreamenCtlCore",
            dependencies: ["StreamenEngineCore"]
        ),
        .executableTarget(
            name: "streamenctl",
            dependencies: ["StreamenCtlCore"]
        ),

        .testTarget(
            name: "StreamenEngineCoreTests",
            // CFFmpeg directly: some tests build FFmpeg structs (e.g. Dolby
            // Vision metadata) to exercise the engine's readers of them.
            // StreamenCtlCore and streamenctl: the tool's tests reuse the fixtures and
            // the torture server, and the Ctrl-C test runs the built binary.
            dependencies: ["StreamenEngineCore", "StreamenEngine", "StreamenFFmpegBridge", "StreamenCtlCore", "streamenctl"],
            exclude: ["Fixtures/generate-fixtures.sh"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
