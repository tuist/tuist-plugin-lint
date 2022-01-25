import Foundation
import SwiftLintFramework

#warning("TODO: needs documentation")

class LintResultBuilder {
    var violations = [StyleViolation]()
    let storage = RuleStorage()
    let configuration: Configuration
    let reporter: Reporter.Type
    let cache: LinterCache?
    let options: LintOptions

    init(options: LintOptions) {
        let config = Configuration(options: options)
        
        self.configuration = Configuration(options: options)
        self.reporter = reporterFrom(optionsReporter: options.reporter, configuration: config)
        self.cache = options.ignoreCache ? nil : LinterCache(configuration: config)
        self.options = options
    }
}
