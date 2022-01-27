import Foundation
import SwiftLintFramework

#warning("TODO: needs documentation")

final class LintResultBuilder {
    var violations: [StyleViolation]
    let storage: RuleStorage
    let configuration: Configuration
    let reporter: Reporter.Type
    let cache: LinterCache

    init(
        configuration: Configuration,
        reporter: Reporter.Type,
        cache: LinterCache
    ) {
        self.violations = []
        self.storage = RuleStorage()
        self.configuration = configuration
        self.reporter = reporter
        self.cache = cache
    }
}
