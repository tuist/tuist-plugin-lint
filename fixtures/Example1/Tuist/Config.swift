import ProjectDescription

let config = Config(
    plugins: [
        .local(path: .relativeToManifest("../../tuist-plugin-swiftlint"))
    ],
    generationOptions: []
)
