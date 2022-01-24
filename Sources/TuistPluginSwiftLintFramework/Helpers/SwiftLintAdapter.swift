import Foundation
import SwiftLintFramework

public protocol SwiftLintAdapting {
    func lint(sources: [String])
}

public final class SwiftLintAdapter: SwiftLintAdapting {
    public init() { }
    
    public func lint(sources: [String]) {
        let options = LintOrAnalyzeOptions(
            mode: .lint,
            paths: sources,
            useSTDIN: false,
            configurationFiles: [], // TODO: configuration files
            strict: false, // TODO: configurable, connected to `lenient`
            lenient: false, // TODO: configurable, connected to `strict`
            forceExclude: false,
            useExcludingByPrefix: false,
            useScriptInputFiles: false,
            benchmark: false,
            reporter: nil,
            quiet: false, // TODO: configurable
            cachePath: nil,
            ignoreCache: false,
            enableAllRules: false,
            autocorrect: false, // TODO: configurable
            format: false, // TODO: configurable
            compilerLogPath: nil,
            compileCommands: nil
        )
        
        SwiftLintAdapter.lint(options: options)
    }
    
    private static func lint(options: LintOrAnalyzeOptions) -> Result<(), SwiftLintError> {
        let builder = LintOrAnalyzeResultBuilder(options)
        
        return collectViolations(builder: builder)
            .flatMap { postProcessViolations(files: $0, builder: builder) }
        
    }
    
    private static func collectViolations(builder: LintOrAnalyzeResultBuilder) -> Result<[SwiftLintFile], SwiftLintError> {
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
    
    private static func applyLeniency(options: LintOrAnalyzeOptions, violations: [StyleViolation]) -> [StyleViolation] {
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
    
    private static func postProcessViolations(files: [SwiftLintFile], builder: LintOrAnalyzeResultBuilder) -> Result<(), SwiftLintError> {
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

typealias File = String
typealias Arguments = [String]

private let indexIncrementerQueue = DispatchQueue(label: "io.tuist.tuist-plugin-swiftlint.indexIncrementer")

struct LintableFilesVisitor {
    let paths: [String]
    let action: String
    let useSTDIN: Bool
    let quiet: Bool
    let useScriptInputFiles: Bool
    let forceExclude: Bool
    let useExcludingByPrefix: Bool
    let cache: LinterCache?
    let parallel: Bool
    let allowZeroLintableFiles: Bool
    let block: (CollectedLinter) -> Void

    init(paths: [String], action: String, useSTDIN: Bool,
         quiet: Bool, useScriptInputFiles: Bool, forceExclude: Bool, useExcludingByPrefix: Bool,
         cache: LinterCache?, parallel: Bool,
         allowZeroLintableFiles: Bool, block: @escaping (CollectedLinter) -> Void) {
        self.paths = resolveParamsFiles(args: paths)
        self.action = action
        self.useSTDIN = useSTDIN
        self.quiet = quiet
        self.useScriptInputFiles = useScriptInputFiles
        self.forceExclude = forceExclude
        self.useExcludingByPrefix = useExcludingByPrefix
        self.cache = cache
        self.parallel = parallel
        self.allowZeroLintableFiles = allowZeroLintableFiles
        self.block = block
    }

    static func create(
        _ options: LintOrAnalyzeOptions,
        cache: LinterCache?,
        allowZeroLintableFiles: Bool,
        block: @escaping (CollectedLinter) -> Void
    ) -> Result<LintableFilesVisitor, SwiftLintError> {
        let visitor = LintableFilesVisitor(paths: options.paths, action: options.verb.bridge().capitalized,
                                           useSTDIN: options.useSTDIN, quiet: options.quiet,
                                           useScriptInputFiles: options.useScriptInputFiles,
                                           forceExclude: options.forceExclude,
                                           useExcludingByPrefix: options.useExcludingByPrefix,
                                           cache: cache,
                                           parallel: true,
                                           allowZeroLintableFiles: allowZeroLintableFiles, block: block)
        return .success(visitor)
    }

    func shouldSkipFile(atPath path: String?) -> Bool {
        return false
    }

    func linter(forFile file: SwiftLintFile, configuration: Configuration) -> Linter {
        return Linter(file: file, configuration: configuration, cache: cache)
    }
}

enum LintOrAnalyzeMode {
    case lint

    var imperative: String {
        switch self {
        case .lint:
            return "lint"
        }
    }

    var verb: String {
        switch self {
        case .lint:
            return "linting"
        }
    }
}

struct LintOrAnalyzeOptions {
    let mode: LintOrAnalyzeMode
    let paths: [String]
    let useSTDIN: Bool
    let configurationFiles: [String]
    let strict: Bool
    let lenient: Bool
    let forceExclude: Bool
    let useExcludingByPrefix: Bool
    let useScriptInputFiles: Bool
    let benchmark: Bool
    let reporter: String?
    let quiet: Bool
    let cachePath: String?
    let ignoreCache: Bool
    let enableAllRules: Bool
    let autocorrect: Bool
    let format: Bool
    let compilerLogPath: String?
    let compileCommands: String?
    
    var verb: String {
        if autocorrect {
            return "correcting"
        } else {
            return mode.verb
        }
    }
}

private func resolveParamsFiles(args: [String]) -> [String] {
    return args.reduce(into: []) { (allArgs: inout [String], arg: String) -> Void in
        if arg.hasPrefix("@"), let contents = try? String(contentsOfFile: String(arg.dropFirst())) {
            allArgs.append(contentsOf: resolveParamsFiles(args: contents.split(separator: "\n").map(String.init)))
        } else {
            allArgs.append(arg)
        }
    }
}

private class LintOrAnalyzeResultBuilder {
    var violations = [StyleViolation]()
    let storage = RuleStorage()
    let configuration: Configuration
    let reporter: Reporter.Type
    let cache: LinterCache?
    let options: LintOrAnalyzeOptions

    init(_ options: LintOrAnalyzeOptions) {
        let config = Configuration(options: options)
        
        configuration = Configuration(options: options)
        reporter = reporterFrom(optionsReporter: options.reporter, configuration: config)
        cache = options.ignoreCache ? nil : LinterCache(configuration: config)
        self.options = options
    }
}

extension Configuration {
    init(options: LintOrAnalyzeOptions) {
        self.init(
            configurationFiles: options.configurationFiles,
            enableAllRules: options.enableAllRules,
            cachePath: options.cachePath
        )
    }
    
    func visitLintableFiles(
        options: LintOrAnalyzeOptions,
        cache: LinterCache? = nil,
        storage: RuleStorage,
        visitorBlock: @escaping (CollectedLinter) -> Void
    ) -> Result<[SwiftLintFile], SwiftLintError> {
        return LintableFilesVisitor.create(options,
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
            let skipFile = visitor.shouldSkipFile(atPath: linter.file.path)
            if !visitor.quiet, linter.isCollecting, let filePath = linter.file.path {
                let outputFilename = self.outputFilename(for: filePath, duplicateFileNames: duplicateFileNames)
                let increment = {
                    collected += 1
                    if skipFile {
                        queuedPrintError("""
                            Skipping '\(outputFilename)' (\(collected)/\(total)) \
                            because its compiler arguments could not be found
                            """)
                    } else {
                        queuedPrintError("Collecting '\(outputFilename)' (\(collected)/\(total))")
                    }
                }
                if visitor.parallel {
                    indexIncrementerQueue.sync(execute: increment)
                } else {
                    increment()
                }
            }

            guard !skipFile else {
                return nil
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

private struct DuplicateCollector {
    var all = Set<String>()
    var duplicates = Set<String>()
}

private extension Collection where Element == Linter {
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

extension Array {
    func parallelCompactMap<T>(transform: (Element) -> T?) -> [T] {
        return parallelMap(transform: transform).compactMap { $0 }
    }

    func parallelMap<T>(transform: (Element) -> T) -> [T] {
        return [T](unsafeUninitializedCapacity: count) { buffer, initializedCount in
            let baseAddress = buffer.baseAddress!
            DispatchQueue.concurrentPerform(iterations: count) { index in
                // Using buffer[index] does assignWithTake which tries
                // to read the uninitialized value (to release it) and crashes
                (baseAddress + index).initialize(to: transform(self[index]))
            }
            initializedCount = count
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
