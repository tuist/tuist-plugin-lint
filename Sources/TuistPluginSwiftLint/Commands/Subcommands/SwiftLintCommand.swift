import ArgumentParser
import TuistPluginSwiftLintFramework

extension MainCommand {
    /// A command to lint the code using SwiftLint.
    struct SwiftLintCommand: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "swiftlint",
            abstract: "Lints the code of your projects using SwiftLint."
        )
        
        @Option(
            name: .shortAndLong,
            help: "The path to the directory that contains the workspace or project whose code will be linted.",
            completion: .directory
        )
        var path: String?
        
        @Argument(
            help: "The target to be linted. When not specified all the targets of the graph are linted."
        )
        var target: String?
        
        func run() throws {
            try SwiftLintService()
                .run(
                    path: path,
                    targetName: target
                )
        }
    }
}
