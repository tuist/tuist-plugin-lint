import Foundation
import SwiftLintFramework

#warning("TODO: unit tests")

extension StyleViolation {
    /// Upgrades/Downgrades violation depends on the given leniency.
    func applyingLeniency(_ leniency: Leniency) -> Self {
        switch leniency {
        case .default:
            return self
        case .strict:
            if severity == .warning {
                return with(severity: .error)
            } else {
                return self
            }
        case .lenient:
            if severity == .error {
                return with(severity: .warning)
            } else {
                return self
            }
        }
    }
    
    /// Creates "number of warnings exceeded threshold" violation.
    static func createThresholdViolation(threshold: Int) -> StyleViolation {
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
            reason: "Number of warnings exceeded threshold of \(threshold)."
        )
    }
}

extension Array where Element == StyleViolation {
    /// Returns a number of violations with the given severity level.
    func numberOfViolations(severity: ViolationSeverity) -> Int {
        filter { $0.severity == severity }.count
    }
    
    /// Upgrades/Downgrades the list of violations depends on the given leniency.
    func applyingLeniency(_ leniency: Leniency) -> [Element] {
        map { $0.applyingLeniency(leniency) }
    }
    
    /// Checks if number of warnings exceeds threshold.
    func isWarningThresholdBroken(warningThreshold: Int) -> Bool {
        numberOfViolations(severity: .warning) >= warningThreshold
    }
    
    /// Returns a summary message for the list of violations.
    func generateSummary(numberOfFiles: Int, numberOfSeriousViolations: Int) -> String {
        """
        Done linting! Found \(count) violation\(count.pluralSuffix),
        \(numberOfSeriousViolations) serious in \(numberOfFiles) file\(numberOfFiles.pluralSuffix).
        """
    }
    
    /// Generates and prints report from violations using the given reporter.
    func report(with reporter: Reporter.Type, realtimeCondition: Bool) {
        if reporter.isRealtime == realtimeCondition {
            let report = reporter.generateReport(self)
            if !report.isEmpty {
                queuedPrint(report)
            }
        }
    }
}

private extension Int {
    var pluralSuffix: String {
        self > 1 ? "s" : ""
    }
}
