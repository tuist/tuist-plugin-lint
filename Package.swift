// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-plugin-swiftlint",
    platforms: [.macOS(.v10_15)],
    products: [
        .executable(
            name: "swift-plugin-swiftlint",
            targets: ["swift-plugin-swiftlint"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/tuist/tuist", revision: "5749fbebf26eae2fb8b5ffff03e1af3593a71c34"), // a commit where `Plugins 2.0` was merged into `release/3.0` branch
    ],
    targets: [
        .executableTarget(
            name: "swift-plugin-swiftlint",
            dependencies: [
                .product(name: "ProjectAutomation", package: "tuist"),
            ]
        ),
        .testTarget(
            name: "swift-plugin-swiftlintTests",
            dependencies: [
                "swift-plugin-swiftlint"
            ]
        ),
    ]
)
