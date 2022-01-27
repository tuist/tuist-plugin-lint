import Foundation
import SwiftLintFramework

#warning("TODO: needs documentation")
#warning("TODO: unit tests")

public protocol SwiftLintFrameworkAdapting {
    func lint(paths: [String])
}

public final class SwiftLintFrameworkAdapter: SwiftLintFrameworkAdapting {
    public init() { }
    
    public func lint(paths: [String]) {
        let options = LintOptions(
            paths: paths,
            configurationFiles: [],
            leniency: .default,
            quiet: false
        )
        let builder = LintResultBuilder(options: options)
        
        do {
            let files = try Self.collectViolations(builder: builder)
            Self.postProcessViolations(files: files, builder: builder)
        } catch {
            #warning("Handle errors")
        }
    }
    
    private static func collectViolations(builder: LintResultBuilder) throws -> [SwiftLintFile] {
        let options = builder.options
        let visitorMutationQueue = DispatchQueue(label: "io.tuist.tuist-plugin-swiftlint.lintVisitorMutation")
        
        let visitor = LintableFilesVisitor(
            paths: options.paths,
            quiet: options.quiet,
            cache: builder.cache,
            block: { linter in
                let currentViolations: [StyleViolation] = applyLeniency(
                    options: options,
                    violations: linter.styleViolations(using: builder.storage)
                )
                visitorMutationQueue.sync {
                    builder.violations += currentViolations
                }
                
                linter.file.invalidateCache()
                builder.reporter.report(violations: currentViolations, realtimeCondition: true)
            }
        )
        
        return try builder.configuration.visitLintableFiles(with: visitor, storage: builder.storage)
    }
    
    private static func applyLeniency(options: LintOptions, violations: [StyleViolation]) -> [StyleViolation] {
        switch options.leniency {
        case .default:
            return violations
        case .lenient:
            return violations.map {
                if $0.severity == .error {
                    return $0.with(severity: .warning)
                } else {
                    return $0
                }
            }
        case .strict:
            return violations.map {
                if $0.severity == .warning {
                    return $0.with(severity: .error)
                } else {
                    return $0
                }
            }
        }
    }
    
    private static func postProcessViolations(files: [SwiftLintFile], builder: LintResultBuilder) {
        let options = builder.options
        let configuration = builder.configuration
        if isWarningThresholdBroken(configuration: configuration, violations: builder.violations) && options.leniency != .lenient {
            builder.violations.append(
                createThresholdViolation(threshold: configuration.warningThreshold!)
            )
            builder.reporter.report(violations: [builder.violations.last!], realtimeCondition: true)
        }
        builder.reporter.report(violations: builder.violations, realtimeCondition: false)
        let numberOfSeriousViolations = builder.violations.filter({ $0.severity == .error }).count
        if !options.quiet {
            printStatus(
                violations: builder.violations,
                files: files,
                serious: numberOfSeriousViolations,
                verb: "linting"
            )
        }

        try? builder.cache?.save()
        guard numberOfSeriousViolations == 0 else { exit(2) }
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
