// swift-tools-version: 6.2
// GradleLens — a local-only macOS (Apple Silicon, macOS 14+) Gradle build observability app.
// Swift 6 strict concurrency. SwiftUI-first. AppKit only where SwiftUI is insufficient.

import PackageDescription

// Xcode 26's Approachable Concurrency defaults (SE-0461, SE-0470). Applied to every
// target so isolation behaves the same in the app, core, and tests.
let approachableConcurrency: [SwiftSetting] = [
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
]

let librarySwiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6)
] + approachableConcurrency

// The executable is a SwiftUI app. Match Xcode 26's new-app default: infer @MainActor
// unless a type opts out. Core stays nonisolated so actors and Sendable models remain
// the teaching default there.
let executableSwiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .defaultIsolation(MainActor.self),
] + approachableConcurrency

let appTestSwiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .defaultIsolation(MainActor.self),
] + approachableConcurrency

let package = Package(
    name: "GradleLens",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "GradleLens", targets: ["GradleLens"]),
        .library(name: "GradleLensCore", targets: ["GradleLensCore"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "GradleLensCore",
            dependencies: [],
            swiftSettings: librarySwiftSettings,
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .executableTarget(
            name: "GradleLens",
            dependencies: ["GradleLensCore"],
            swiftSettings: executableSwiftSettings
        ),
        .testTarget(
            name: "GradleLensCoreTests",
            dependencies: ["GradleLensCore"],
            resources: [
                .copy("Fixtures")
            ],
            swiftSettings: librarySwiftSettings
        ),
        .testTarget(
            name: "GradleLensTests",
            dependencies: ["GradleLens"],
            swiftSettings: appTestSwiftSettings
        ),
    ]
)
