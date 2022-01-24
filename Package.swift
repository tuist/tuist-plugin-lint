// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "tuist-plugin-swiftlint",
    platforms: [.macOS(.v10_15)],
    products: [
        .executable(
            name: "plugin-swiftlint",
            targets: ["TuistPluginSwiftLint"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/tuist/tuist", branch: "release/3.0"), // TODO: replace "revision" with requirement for released version when `3.0` be released
        .package(url: "https://github.com/realm/SwiftLint", .exact("0.46.1")), // it is a core dependency of the plugin, the version should be under control and locked
        .package(url: "https://github.com/apple/swift-argument-parser.git", .upToNextMinor(from: "1.0.0")),
    ],
    targets: [
        .executableTarget(
            name: "TuistPluginSwiftLint",
            dependencies: [
                "TuistPluginSwiftLintFramework",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .target(
            name: "TuistPluginSwiftLintFramework",
            dependencies: [
                .product(name: "ProjectAutomation", package: "tuist"),
                .product(name: "SwiftLintFramework", package: "SwiftLint"),
            ]
        ),
        .testTarget(
            name: "TuistPluginSwiftLintFrameworkTests",
            dependencies: [
                "TuistPluginSwiftLintFramework",
            ]
        ),
    ]
)
