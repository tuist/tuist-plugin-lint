import Foundation
import SwiftLintFramework

#warning("TODO: needs documentation")
#warning("TODO: unit tests")

struct LintableFilesVisitor {
    let paths: [String]
    let action: String
    let quiet: Bool
    let forceExclude: Bool
    let useExcludingByPrefix: Bool
    let cache: LinterCache?
    let parallel: Bool
    let allowZeroLintableFiles: Bool
    let block: (CollectedLinter) -> Void

    static func create(
        options: LintOptions,
        cache: LinterCache?,
        allowZeroLintableFiles: Bool,
        block: @escaping (CollectedLinter) -> Void
    ) -> LintableFilesVisitor {
        let paths = resolveParamsFiles(args: options.paths)
        
        let visitor = LintableFilesVisitor(
            paths: paths,
            action: options.verb.bridge().capitalized,
            quiet: options.quiet,
            forceExclude: options.forceExclude,
            useExcludingByPrefix: options.useExcludingByPrefix,
            cache: cache,
            parallel: true,
            allowZeroLintableFiles: allowZeroLintableFiles,
            block: block
        )
        
        return visitor
    }

    func linter(forFile file: SwiftLintFile, configuration: Configuration) -> Linter {
        Linter(file: file, configuration: configuration, cache: cache)
    }
}

// MARK: - Helpers

private func resolveParamsFiles(args: [String]) -> [String] {
    return args.reduce(into: []) { (allArgs: inout [String], arg: String) -> Void in
        if arg.hasPrefix("@"), let contents = try? String(contentsOfFile: String(arg.dropFirst())) {
            allArgs.append(contentsOf: resolveParamsFiles(args: contents.split(separator: "\n").map(String.init)))
        } else {
            allArgs.append(arg)
        }
    }
}
