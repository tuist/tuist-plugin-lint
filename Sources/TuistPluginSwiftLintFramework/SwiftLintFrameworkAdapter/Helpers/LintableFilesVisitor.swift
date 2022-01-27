import Foundation
import SwiftLintFramework

#warning("TODO: needs documentation")
#warning("TODO: unit tests")

struct LintableFilesVisitor {
    let quiet: Bool
    let cache: LinterCache?

    init(
        quiet: Bool,
        cache: LinterCache?
    ) {
        self.quiet = quiet
        self.cache = cache
    }
}
