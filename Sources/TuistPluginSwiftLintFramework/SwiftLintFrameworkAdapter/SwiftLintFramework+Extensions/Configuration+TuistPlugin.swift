import Foundation
import SwiftLintFramework

#warning("needs unit tests")
#warning("needs documentation")

private let indexIncrementerQueue = DispatchQueue(label: "io.tuist.tuist-plugin-swiftlint.indexIncrementer")

extension Configuration {
    init(options: LintOptions) {
        self.init(
            configurationFiles: options.configurationFiles,
            enableAllRules: options.enableAllRules,
            cachePath: options.cachePath
        )
    }
    
    func visitLintableFiles(with visitor: LintableFilesVisitor, storage: RuleStorage) throws -> [SwiftLintFile] {
        let files = try getFiles(with: visitor)
        let groupedFiles = try groupFiles(files, visitor: visitor)
        let linters = linters(for: groupedFiles, visitor: visitor)
        let (collectedLinters, duplicateFileNames) = collect(linters: linters, visitor: visitor, storage: storage, duplicateFileNames: linters.duplicateFileNames)
        let visitedFiles = visit(linters: collectedLinters, visitor: visitor, storage: storage, duplicateFileNames: duplicateFileNames)
        
        return visitedFiles
    }
    
    private func linters(
        for filesPerConfiguration: [Configuration: [SwiftLintFile]],
        visitor: LintableFilesVisitor
    ) -> [Linter] {
        let fileCount = filesPerConfiguration.reduce(0) { $0 + $1.value.count }

        var linters = [Linter]()
        linters.reserveCapacity(fileCount)
        for (config, files) in filesPerConfiguration {
            let newConfig: Configuration
            if visitor.cache != nil {
                newConfig = config.withPrecomputedCacheDescription()
            } else {
                newConfig = config
            }
            linters += files.map { visitor.linter(forFile: $0, configuration: newConfig) }
        }
        
        return linters
    }
    
    private func outputFilename(for path: String, duplicateFileNames: Set<String>) -> String {
        let basename = path.bridge().lastPathComponent
        if !duplicateFileNames.contains(basename) {
            return basename
        }

        var pathComponents = path.bridge().pathComponents
        for component in rootDirectory.bridge().pathComponents where pathComponents.first == component {
            pathComponents.removeFirst()
        }

        return pathComponents.joined(separator: "/")
    }
    
    private func collect(
        linters: [Linter],
        visitor: LintableFilesVisitor,
        storage: RuleStorage,
        duplicateFileNames: Set<String>
    ) -> ([CollectedLinter], Set<String>) {
        var collected = 0
        let total = linters.filter({ $0.isCollecting }).count
        let collect = { (linter: Linter) -> CollectedLinter? in
            if !visitor.quiet, linter.isCollecting, let filePath = linter.file.path {
                let outputFilename = self.outputFilename(for: filePath, duplicateFileNames: duplicateFileNames)
                let increment = {
                    collected += 1
                    queuedPrintError("Collecting '\(outputFilename)' (\(collected)/\(total))")
                }
                if visitor.parallel {
                    indexIncrementerQueue.sync(execute: increment)
                } else {
                    increment()
                }
            }

            return autoreleasepool {
                linter.collect(into: storage)
            }
        }

        let collectedLinters = visitor.parallel ?
            linters.parallelCompactMap(transform: collect) :
            linters.compactMap(collect)
        return (collectedLinters, duplicateFileNames)
    }

    
    private func groupFiles(
        _ files: [SwiftLintFile],
        visitor: LintableFilesVisitor
    ) throws -> [Configuration: [SwiftLintFile]] {
        var groupedFiles = [Configuration: [SwiftLintFile]]()
        for file in files {
            let fileConfiguration = configuration(for: file)
            let fileConfigurationRootPath = fileConfiguration.rootDirectory.bridge()

            // Files whose configuration specifies they should be excluded will be skipped
            let shouldSkip = fileConfiguration.excludedPaths.contains { excludedRelativePath in
                let excludedPath = fileConfigurationRootPath.appendingPathComponent(excludedRelativePath)
                let filePathComponents = file.path?.bridge().pathComponents ?? []
                let excludedPathComponents = excludedPath.bridge().pathComponents
                return filePathComponents.starts(with: excludedPathComponents)
            }

            if !shouldSkip {
                groupedFiles[fileConfiguration, default: []].append(file)
            }
        }

        return groupedFiles
    }
    
    private func getFiles(with visitor: LintableFilesVisitor) throws -> [SwiftLintFile] {
        if !visitor.quiet {
            let filesInfo: String
            if visitor.paths.isEmpty || visitor.paths == [""] {
                filesInfo = "in current working directory"
            } else {
                filesInfo = "at paths \(visitor.paths.joined(separator: ", "))"
            }

            queuedPrintError("\(visitor.action) Swift files \(filesInfo)")
        }
        
        return visitor.paths.flatMap {
            self.lintableFiles(inPath: $0, forceExclude: visitor.forceExclude)
        }
    }
    
    private func visit(
        linters: [CollectedLinter],
        visitor: LintableFilesVisitor,
        storage: RuleStorage,
        duplicateFileNames: Set<String>
    ) -> [SwiftLintFile] {
        var visited = 0
        let visit = { (linter: CollectedLinter) -> SwiftLintFile in
            if !visitor.quiet, let filePath = linter.file.path {
                let outputFilename = self.outputFilename(for: filePath, duplicateFileNames: duplicateFileNames)
                let increment = {
                    visited += 1
                    queuedPrintError("\(visitor.action) '\(outputFilename)' (\(visited)/\(linters.count))")
                }
                if visitor.parallel {
                    indexIncrementerQueue.sync(execute: increment)
                } else {
                    increment()
                }
            }

            autoreleasepool {
                visitor.block(linter)
            }
            return linter.file
        }
        return visitor.parallel ? linters.parallelMap(transform: visit) : linters.map(visit)
    }
}
