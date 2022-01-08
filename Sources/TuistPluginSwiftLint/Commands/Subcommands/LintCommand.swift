import ArgumentParser

extension MainCommand {
    struct LintCommand: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "lint"
        )
        
        func run() throws {
            print("Start liniting!")
        }
    }
}
