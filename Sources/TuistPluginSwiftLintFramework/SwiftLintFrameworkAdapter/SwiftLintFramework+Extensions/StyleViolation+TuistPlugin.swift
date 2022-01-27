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
                return self.with(severity: .error)
            } else {
                return self
            }
        case .lenient:
            if severity == .error {
                return self.with(severity: .warning)
            } else {
                return self
            }
        }
    }
}

extension Sequence where Element == StyleViolation {
    /// Upgrades/Downgrades a list of violations depends on the given leniency.
    func applyingLeniency(_ leniency: Leniency) -> [Element] {
        map {
            $0.applyingLeniency(leniency)
        }
    }
}
