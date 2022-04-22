// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "tuist-lint",
    platforms: [.macOS(.v11)],
    products: [
        .executable(
            name: "tuist-lint",
            targets: ["TuistPluginSwiftLint"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/tuist/ProjectAutomation", .exact("3.2.0")),
        .package(url: "https://github.com/realm/SwiftLint", .exact("0.46.5")), // it is a core dependency of the plugin, the version should be under control and locked
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
                .product(name: "ProjectAutomation", package: "ProjectAutomation"),
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
