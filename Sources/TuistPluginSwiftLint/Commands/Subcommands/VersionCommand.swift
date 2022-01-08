import ArgumentParser
import TuistPluginSwiftLintFramework

extension MainCommand {
    /// A command to print the current version of the plugin.
    struct VersionCommand: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "version",
            abstract: "Outputs the current version of the plugin."
        )
        
        func run() throws {
            VersionService()
                .run()
        }
    }
}
