import Foundation
import SwiftLintFramework

#warning("needs unit tests")
#warning("needs documentation")

extension Configuration {
    init(options: LintOptions) {
        self.init(
            configurationFiles: options.configurationFiles,
            enableAllRules: options.enableAllRules,
            cachePath: options.cachePath
        )
    }
}
