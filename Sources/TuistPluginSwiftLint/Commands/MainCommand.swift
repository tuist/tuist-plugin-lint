import ArgumentParser

struct MainCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "swiftlint",
        subcommands: [
            LintCommand.self
        ],
        defaultSubcommand: LintCommand.self
    )
}
