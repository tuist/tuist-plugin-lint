import ArgumentParser
import TuistPluginSwiftLintFramework

extension MainCommand {
    /// A command to print the current version of SwiftLint.
    struct VersionSwiftLintCommand: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "version-swiftlint",
            abstract: "Outputs the current version of SwiftLint."
        )
        
        func run() throws {
            VersionSwiftLintService()
                .run()
        }
    }
}
