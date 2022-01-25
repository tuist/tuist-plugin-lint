import Foundation
import SwiftLintFramework

#warning("needs unit tests")
#warning("needs documentation")

extension Reporter {
    static func report(violations: [StyleViolation], realtimeCondition: Bool) {
        if isRealtime == realtimeCondition {
            let report = generateReport(violations)
            if !report.isEmpty {
                queuedPrint(report)
            }
        }
    }
}
