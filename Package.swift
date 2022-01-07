// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "tuist-plugin-swiftlint",
    platforms: [.macOS(.v10_15)],
    products: [
        .executable(
            name: "tuist-plugin-swiftlint",
            targets: ["tuist-plugin-swiftlint"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/tuist/tuist", branch: "release/3.0"), // TODO: replace "revision" with requirement for released version when `3.0` be released
        .package(url: "https://github.com/realm/SwiftLint", .upToNextMinor(from: "0.45.0")),
    ],
    targets: [
        .executableTarget(
            name: "tuist-plugin-swiftlint",
            dependencies: [
                .product(name: "ProjectAutomation", package: "tuist"),
                .product(name: "SwiftLintFramework", package: "SwiftLint"),
            ]
        ),
        .testTarget(
            name: "tuist-plugin-swiftlintTests",
            dependencies: [
                "tuist-plugin-swiftlint"
            ]
        ),
    ]
)
