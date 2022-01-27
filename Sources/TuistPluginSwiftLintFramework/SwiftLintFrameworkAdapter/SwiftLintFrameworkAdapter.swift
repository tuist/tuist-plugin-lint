import Foundation
import SwiftLintFramework

#warning("TODO: needs documentation")
#warning("TODO: unit tests")

public protocol SwiftLintFrameworkAdapting {
    func lint(paths: [String], configurationFiles: [String], leniency: Leniency, quiet: Bool)
}

public final class SwiftLintFrameworkAdapter: SwiftLintFrameworkAdapting {
    public init() { }
    
    public func lint(paths: [String], configurationFiles: [String], leniency: Leniency, quiet: Bool) {
        let configuration = Configuration(configurationFiles: configurationFiles)
        let reporter = reporterFrom(identifier: configuration.reporter)
        let cache = LinterCache(configuration: configuration)
        let storage = RuleStorage()
        
        var violations: [StyleViolation] = []
        
        do {
            // Linting
            let visitorMutationQueue = DispatchQueue(label: "io.tuist.tuist-plugin-swiftlint.lintVisitorMutation")
            let visitor = LintableFilesVisitor(
                paths: paths,
                quiet: quiet,
                cache: cache,
                block: { linter in
                    let currentViolations = linter
                        .styleViolations(using: storage)
                        .applyingLeniency(leniency)
                    
                    visitorMutationQueue.sync {
                        violations += currentViolations
                    }
                    
                    linter.file.invalidateCache()
                    reporter.report(violations: currentViolations, realtimeCondition: true)
                }
            )
            let files = try configuration.visitLintableFiles(with: visitor, storage: storage)
            
            // post processing
            if Self.isWarningThresholdBroken(configuration: configuration, violations: violations) && leniency != .lenient {
                violations.append(
                    Self.createThresholdViolation(threshold: configuration.warningThreshold!)
                )
                reporter.report(violations: [violations.last!], realtimeCondition: true)
            }
            reporter.report(violations: violations, realtimeCondition: false)
            let numberOfSeriousViolations = violations.filter({ $0.severity == .error }).count
            if !quiet {
                Self.printStatus(
                    violations: violations,
                    files: files,
                    serious: numberOfSeriousViolations,
                    verb: "linting"
                )
            }

            try? cache.save()
            guard numberOfSeriousViolations == 0 else { exit(2) }
        } catch {
            #warning("Handle errors")
        }
    }
    
    private static func printStatus(violations: [StyleViolation], files: [SwiftLintFile], serious: Int, verb: String) {
        let pluralSuffix = { (collection: [Any]) -> String in
            return collection.count != 1 ? "s" : ""
        }
        queuedPrintError(
            "Done \(verb)! Found \(violations.count) violation\(pluralSuffix(violations)), " +
            "\(serious) serious in \(files.count) file\(pluralSuffix(files))."
        )
    }
    
    private static func isWarningThresholdBroken(configuration: Configuration, violations: [StyleViolation]) -> Bool {
        guard let warningThreshold = configuration.warningThreshold else { return false }
        
        let numberOfWarningViolations = violations.filter({ $0.severity == .warning }).count
        return numberOfWarningViolations >= warningThreshold
    }
    
    private static func createThresholdViolation(threshold: Int) -> StyleViolation {
        let description = RuleDescription(
            identifier: "warning_threshold",
            name: "Warning Threshold",
            description: "Number of warnings thrown is above the threshold.",
            kind: .lint
        )
        
        return StyleViolation(
            ruleDescription: description,
            severity: .error,
            location: Location(file: "", line: 0, character: 0),
            reason: "Number of warnings exceeded threshold of \(threshold).")
    }
}
