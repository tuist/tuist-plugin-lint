import Foundation
import SwiftLintFramework

#warning("TODO: needs documentation")
#warning("TODO: unit tests")

public protocol SwiftLintFrameworkAdapting {
    func lint(sources: [String])
}

public final class SwiftLintFrameworkAdapter: SwiftLintFrameworkAdapting {
    public init() { }
    
    public func lint(sources: [String]) {
        let options = LintOptions.create(sources: sources)
        
        SwiftLintFrameworkAdapter.lint(options: options)
    }
    
    private static func lint(options: LintOptions) -> Result<(), SwiftLintError> {
        let builder = LintResultBuilder(options: options)
        
        return collectViolations(builder: builder)
            .flatMap { postProcessViolations(files: $0, builder: builder) }
        
    }
    
    private static func collectViolations(builder: LintResultBuilder) -> Result<[SwiftLintFile], SwiftLintError> {
        let options = builder.options
        let visitorMutationQueue = DispatchQueue(label: "io.tuist.tuist-plugin-swiftlint.lintVisitorMutation")
        
        return builder.configuration
            .visitLintableFiles(
                options: options,
                cache: builder.cache,
                storage: builder.storage,
                visitorBlock: { linter in
                    let currentViolations: [StyleViolation] = applyLeniency(
                        options: options,
                        violations: linter.styleViolations(using: builder.storage)
                    )
                    visitorMutationQueue.sync {
                        builder.violations += currentViolations
                    }
                    
                    linter.file.invalidateCache()
                    builder.reporter.report(violations: currentViolations, realtimeCondition: true)
                }
            )
            
    }
    
    private static func applyLeniency(options: LintOptions, violations: [StyleViolation]) -> [StyleViolation] {
        switch (options.lenient, options.strict) {
        case (false, false):
            return violations

        case (true, false):
            return violations.map {
                if $0.severity == .error {
                    return $0.with(severity: .warning)
                } else {
                    return $0
                }
            }

        case (false, true):
            return violations.map {
                if $0.severity == .warning {
                    return $0.with(severity: .error)
                } else {
                    return $0
                }
            }

        case (true, true):
            queuedFatalError("Invalid command line options: 'lenient' and 'strict' are mutually exclusive.")
        }
    }
    
    private static func postProcessViolations(files: [SwiftLintFile], builder: LintResultBuilder) -> Result<(), SwiftLintError> {
        let options = builder.options
        let configuration = builder.configuration
        if isWarningThresholdBroken(configuration: configuration, violations: builder.violations)
            && !options.lenient {
            builder.violations.append(
                createThresholdViolation(threshold: configuration.warningThreshold!)
            )
            builder.reporter.report(violations: [builder.violations.last!], realtimeCondition: true)
        }
        builder.reporter.report(violations: builder.violations, realtimeCondition: false)
        let numberOfSeriousViolations = builder.violations.filter({ $0.severity == .error }).count
        if !options.quiet {
            printStatus(violations: builder.violations, files: files, serious: numberOfSeriousViolations,
                        verb: options.verb)
        }

        try? builder.cache?.save()
        guard numberOfSeriousViolations == 0 else { exit(2) }
        return .success(())
    }
    
    private static func printStatus(violations: [StyleViolation], files: [SwiftLintFile], serious: Int, verb: String) {
        let pluralSuffix = { (collection: [Any]) -> String in
            return collection.count != 1 ? "s" : ""
        }
        queuedPrintError(
            "Done \(verb)! Found \(violations.count) violation\(pluralSuffix(violations)), " +
            "\(serious) serious in \(files.count) file\(pluralSuffix(files))."
        )
    }
    
    private static func isWarningThresholdBroken(configuration: Configuration,
                                                 violations: [StyleViolation]) -> Bool {
        guard let warningThreshold = configuration.warningThreshold else { return false }
        let numberOfWarningViolations = violations.filter({ $0.severity == .warning }).count
        return numberOfWarningViolations >= warningThreshold
    }
    
    private static func createThresholdViolation(threshold: Int) -> StyleViolation {
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
            reason: "Number of warnings exceeded threshold of \(threshold).")
    }
}






/// MARK: - Helper

private let indexIncrementerQueue = DispatchQueue(label: "io.tuist.tuist-plugin-swiftlint.indexIncrementer")

extension Configuration {
    func visitLintableFiles(
        options: LintOptions,
        cache: LinterCache? = nil,
        storage: RuleStorage,
        visitorBlock: @escaping (CollectedLinter) -> Void
    ) -> Result<[SwiftLintFile], SwiftLintError> {
        return LintableFilesVisitor.create(options: options,
                                           cache: cache,
                                           allowZeroLintableFiles: allowZeroLintableFiles,
                                           block: visitorBlock).flatMap({ visitor in
        visitLintableFiles(with: visitor, storage: storage)
    })
    }
    
    func visitLintableFiles(with visitor: LintableFilesVisitor, storage: RuleStorage) -> Result<[SwiftLintFile], SwiftLintError> {
        getFiles(with: visitor)
            .flatMap { groupFiles($0, visitor: visitor) }
            .map { linters(for: $0, visitor: visitor) }
            .map { ($0, $0.duplicateFileNames) }
            .map { collect(linters: $0, visitor: visitor, storage: storage, duplicateFileNames: $1) }
            .map { visit(linters: $0, visitor: visitor, storage: storage, duplicateFileNames: $1) }
    }
    
    private func linters(for filesPerConfiguration: [Configuration: [SwiftLintFile]],
                         visitor: LintableFilesVisitor) -> [Linter] {
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
    
    private func collect(linters: [Linter],
                         visitor: LintableFilesVisitor,
                         storage: RuleStorage,
                         duplicateFileNames: Set<String>) -> ([CollectedLinter], Set<String>) {
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

    
    private func groupFiles(_ files: [SwiftLintFile],
                            visitor: LintableFilesVisitor)
        -> Result<[Configuration: [SwiftLintFile]], SwiftLintError> {
        if files.isEmpty && !visitor.allowZeroLintableFiles {
            let errorMessage = "No lintable files found at paths: '\(visitor.paths.joined(separator: ", "))'"
            return .failure(.usageError(description: errorMessage))
        }

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

        return .success(groupedFiles)
    }
    
    fileprivate func getFiles(with visitor: LintableFilesVisitor) -> Result<[SwiftLintFile], SwiftLintError> {
        if visitor.useSTDIN {
            let stdinData = FileHandle.standardInput.readDataToEndOfFile()
            if let stdinString = String(data: stdinData, encoding: .utf8) {
                return .success([SwiftLintFile(contents: stdinString)])
            }
            return .failure(.usageError(description: "stdin isn't a UTF8-encoded string"))
        } else if visitor.useScriptInputFiles {
            return scriptInputFiles()
                .map { files in
                    guard visitor.forceExclude else {
                        return files
                    }

                    let scriptInputPaths = files.compactMap { $0.path }
                    let filesToLint = visitor.useExcludingByPrefix
                                      ? filterExcludedPathsByPrefix(in: scriptInputPaths)
                                      : filterExcludedPaths(in: scriptInputPaths)
                    return filesToLint.map(SwiftLintFile.init(pathDeferringReading:))
                }
        }
        if !visitor.quiet {
            let filesInfo: String
            if visitor.paths.isEmpty || visitor.paths == [""] {
                filesInfo = "in current working directory"
            } else {
                filesInfo = "at paths \(visitor.paths.joined(separator: ", "))"
            }

            queuedPrintError("\(visitor.action) Swift files \(filesInfo)")
        }
        return .success(visitor.paths.flatMap {
            self.lintableFiles(inPath: $0, forceExclude: visitor.forceExclude,
                               excludeByPrefix: visitor.useExcludingByPrefix)
        })
    }
    
    private func visit(linters: [CollectedLinter],
                       visitor: LintableFilesVisitor,
                       storage: RuleStorage,
                       duplicateFileNames: Set<String>) -> [SwiftLintFile] {
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

func reporterFrom(optionsReporter: String?, configuration: Configuration) -> Reporter.Type {
    return reporterFrom(identifier: optionsReporter ?? configuration.reporter)
}


enum SwiftLintError: LocalizedError {
    case usageError(description: String)

    var errorDescription: String? {
        switch self {
        case .usageError(let description):
            return description
        }
    }
}

private func scriptInputFiles() -> Result<[SwiftLintFile], SwiftLintError> {
    func getEnvironmentVariable(_ variable: String) -> Result<String, SwiftLintError> {
        let environment = ProcessInfo.processInfo.environment
        if let value = environment[variable] {
            return .success(value)
        }
        return .failure(.usageError(description: "Environment variable not set: \(variable)"))
    }

    let count: Result<Int, SwiftLintError> = {
        let inputFileKey = "SCRIPT_INPUT_FILE_COUNT"
        guard let countString = ProcessInfo.processInfo.environment[inputFileKey] else {
            return .failure(.usageError(description: "\(inputFileKey) variable not set"))
        }
        if let count = Int(countString) {
            return .success(count)
        }
        return .failure(.usageError(description: "\(inputFileKey) did not specify a number"))
    }()

    return count.flatMap { count in
        return .success((0..<count).compactMap { fileNumber in
            switch getEnvironmentVariable("SCRIPT_INPUT_FILE_\(fileNumber)") {
            case let .success(path):
                if path.bridge().isSwiftFile() {
                    return SwiftLintFile(pathDeferringReading: path)
                }
                return nil
            case let .failure(error):
                queuedPrintError(String(describing: error))
                return nil
            }
        })
    }
}
