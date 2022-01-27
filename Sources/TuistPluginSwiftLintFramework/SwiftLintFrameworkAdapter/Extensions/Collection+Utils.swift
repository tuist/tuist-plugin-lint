import Foundation
import SwiftLintFramework

#warning("TODO: needs documentation")
#warning("TODO: unit tests")

private struct DuplicateCollector {
    var all = Set<String>()
    var duplicates = Set<String>()
}

extension Collection where Element == Linter {
    var duplicateFileNames: Set<String> {
        let collector = reduce(into: DuplicateCollector()) { result, linter in
            if let filename = linter.file.path?.bridge().lastPathComponent {
                if result.all.contains(filename) {
                    result.duplicates.insert(filename)
                }

                result.all.insert(filename)
            }
        }
        return collector.duplicates
    }
}
