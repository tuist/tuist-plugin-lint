import Foundation
import SwiftLintFramework

#warning("TODO: needs documentation")
#warning("TODO: unit tests")

public protocol SwiftLintFrameworkAdapting {
    func lint(paths: [String], configurationFiles: [String], leniency: Leniency, quiet: Bool)
}

public final class SwiftLintFrameworkAdapter: SwiftLintFrameworkAdapting {
    private let indexIncrementerQueue = DispatchQueue(label: "io.tuist.tuist-plugin-swiftlint.indexIncrementer")
    private let visitorMutationQueue = DispatchQueue(label: "io.tuist.tuist-plugin-swiftlint.lintVisitorMutation")
    
    public init() { }
    
    public func lint(paths: [String], configurationFiles: [String], leniency: Leniency, quiet: Bool) {
        let configuration = Configuration(configurationFiles: configurationFiles)
        let reporter = reporterFrom(identifier: configuration.reporter)
        let cache = LinterCache(configuration: configuration)
        let storage = RuleStorage()
        
        var violations: [StyleViolation] = []
        
        do {
            // Linting
            let visitor = LintableFilesVisitor(
                paths: paths,
                quiet: quiet,
                cache: cache,
                block: { [visitorMutationQueue] linter in
                    let currentViolations = linter
                        .styleViolations(using: storage)
                        .applyingLeniency(leniency)
                    
                    visitorMutationQueue.sync {
                        violations += currentViolations
                    }
                    
                    linter.file.invalidateCache()
                    reporter.report(violations: currentViolations, realtimeCondition: true)
                }
            )
            let files = try visitLintableFiles(with: visitor, storage: storage, configuration: configuration)
            
            // post processing
            if let warningThreshold = configuration.warningThreshold, violations.isWarningThresholdBroken(warningThreshold: warningThreshold), leniency != .lenient {
                let thresholdViolation = StyleViolation.createThresholdViolation(threshold: warningThreshold)
                
                violations.append(thresholdViolation)
                reporter.report(violations: [thresholdViolation], realtimeCondition: true)
            }
            
            reporter.report(violations: violations, realtimeCondition: false)
            let numberOfSeriousViolations = violations.numberOfViolations(severity: .error)
            if !quiet {
                queuedPrintError(
                    violations.generateSummary(numberOfFiles: files.count, numberOfSeriousViolations: numberOfSeriousViolations)
                )
            }

            try? cache.save()
            guard numberOfSeriousViolations == 0 else { exit(2) }
        } catch {
            #warning("Handle errors")
        }
    }
    
    // MARK: - Helpers - Linting
    
    private func visitLintableFiles(with visitor: LintableFilesVisitor, storage: RuleStorage, configuration: Configuration ) throws -> [SwiftLintFile] {
        let files = try getFiles(with: visitor, configuration: configuration)
        let groupedFiles = try groupFiles(files, visitor: visitor, configuration: configuration)
        let linters = linters(for: groupedFiles, visitor: visitor)
        let (collectedLinters, duplicateFileNames) = collect(linters: linters, visitor: visitor, storage: storage, duplicateFileNames: linters.duplicateFileNames, configuration: configuration)
        let visitedFiles = visit(linters: collectedLinters, visitor: visitor, storage: storage, duplicateFileNames: duplicateFileNames, configuration: configuration)
        
        return visitedFiles
    }
    
    private func getFiles(with visitor: LintableFilesVisitor, configuration: Configuration) throws -> [SwiftLintFile] {
        if !visitor.quiet {
            let filesInfo: String
            if visitor.paths.isEmpty || visitor.paths == [""] {
                filesInfo = "in current working directory"
            } else {
                filesInfo = "at paths \(visitor.paths.joined(separator: ", "))"
            }

            queuedPrintError("Linting Swift files \(filesInfo)")
        }
        
        return visitor.paths.flatMap {
            configuration.lintableFiles(inPath: $0, forceExclude: false)
        }
    }
    
    private func groupFiles(
        _ files: [SwiftLintFile],
        visitor: LintableFilesVisitor,
        configuration: Configuration
    ) throws -> [Configuration: [SwiftLintFile]] {
        var groupedFiles = [Configuration: [SwiftLintFile]]()
        
        files.forEach { file in
            let fileConfiguration = configuration.configuration(for: file)
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
    
    private func collect(
        linters: [Linter],
        visitor: LintableFilesVisitor,
        storage: RuleStorage,
        duplicateFileNames: Set<String>,
        configuration: Configuration
    ) -> ([CollectedLinter], Set<String>) {
        var collected = 0
        let total = linters.filter({ $0.isCollecting }).count
        let collect = { [indexIncrementerQueue] (linter: Linter) -> CollectedLinter? in
            if !visitor.quiet, linter.isCollecting, let filePath = linter.file.path {
                let outputFilename = outputFilename(for: filePath, duplicateFileNames: duplicateFileNames, configuration: configuration)
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
    
    private func visit(
        linters: [CollectedLinter],
        visitor: LintableFilesVisitor,
        storage: RuleStorage,
        duplicateFileNames: Set<String>,
        configuration: Configuration
    ) -> [SwiftLintFile] {
        var visited = 0
        let visit = { [indexIncrementerQueue] (linter: CollectedLinter) -> SwiftLintFile in
            if !visitor.quiet, let filePath = linter.file.path {
                let outputFilename = outputFilename(for: filePath, duplicateFileNames: duplicateFileNames, configuration: configuration)
                let increment = {
                    visited += 1
                    queuedPrintError("Linting '\(outputFilename)' (\(visited)/\(linters.count))")
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

// MARK: - Helpers

private func outputFilename(for path: String, duplicateFileNames: Set<String>, configuration: Configuration) -> String {
    let basename = path.bridge().lastPathComponent
    if !duplicateFileNames.contains(basename) {
        return basename
    }

    var pathComponents = path.bridge().pathComponents
    for component in configuration.rootDirectory.bridge().pathComponents where pathComponents.first == component {
        pathComponents.removeFirst()
    }

    return pathComponents.joined(separator: "/")
}
