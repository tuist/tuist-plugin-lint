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
            if let warningThreshold = configuration.warningThreshold, violations.isWarningThresholdBroken(warningThreshold: warningThreshold), leniency != .lenient {
                let thresholdViolation = StyleViolation.createThresholdViolation(threshold: warningThreshold)
                
                violations.append(thresholdViolation)
                reporter.report(violations: [thresholdViolation], realtimeCondition: true)
            }
            
            reporter.report(violations: violations, realtimeCondition: false)
            let numberOfSeriousViolations = violations.numberOfViolations(severity: .error)
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
}
