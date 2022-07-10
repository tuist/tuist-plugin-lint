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
        
        @Flag(exclusivity: .exclusive)
        var leniency: LeniencyOptions?

        @Flag(help: "Keep printing to a minimum.")
        var quiet = false
        
        func run() throws {
            try SwiftLintService().run(
                path: path,
                targetName: target,
                leniency: leniencyStrategy(from: leniency),
                quiet: quiet
            )
        }

        private func leniencyStrategy(from leniencyFlags: LeniencyOptions?) -> Leniency {
            switch leniencyFlags {
            case nil:
                return .`default`
            case .strict:
                return .strict
            case .lenient:
                return .lenient
            }
        }
    }

    enum LeniencyOptions: String, EnumerableFlag {
        case strict, lenient

        static func help(for value: LeniencyOptions) -> ArgumentHelp? {
            switch value {
            case .strict:
                return "Upgrades warnings to serious violations (errors)."
            case .lenient:
                return "Downgrades serious violations to warnings, warning threshold is disabled."
            }
        }
    }
}
