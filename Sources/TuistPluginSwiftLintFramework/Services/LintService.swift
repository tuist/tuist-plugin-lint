import Foundation
import ProjectAutomation

/// A service that manages code linting.
public final class LintService {
    public init() {}
    
    /// The entry point of the service. Invoke it to start linting.
    /// - Parameters:
    ///   - path: The path to the directory that contains the workspace or project whose code will be linted.
    ///   - targetName: The target to be linted. When not specified all the targets of the graph are linted.
    public func run(path: String?, targetName: String?) throws {
        print("Hello")
        
        do {
            let graph: Graph = try {
                if let path = path {
                    print("path: " + path)
                    return try Tuist.graph(at: path)
                } else {
                    return try Tuist.graph()
                }
            }()
        } catch {
            print(error)
        }
        
        //        let targets = graph.projects.values.flatMap(\.targets)
        //        print("The current graph has the following targets: \(targets.map(\.name).joined(separator: " "))")
    }
}



// ------------------------------------------------
// ----------- OLD IMPLEMENTATION -----------------
// ------------------------------------------------

//enum LintCodeServiceError: FatalError, Equatable {
//    /// Thrown when target with given name does not exist.
//    case targetNotFound(String)
//    /// Throws when no lintable files found for target with given name.
//    case lintableFilesForTargetNotFound(String)
//
//    /// Error type.
//    var type: ErrorType {
//        switch self {
//        case .targetNotFound, .lintableFilesForTargetNotFound:
//            return .abort
//        }
//    }
//
//    /// Description
//    var description: String {
//        switch self {
//        case let .targetNotFound(name):
//            return "Target with name '\(name)' not found in the project."
//        case let .lintableFilesForTargetNotFound(name):
//            return "No lintable files for target with name '\(name)'."
//        }
//    }
//}
//
//final class LintCodeService {
//    private let codeLinter: CodeLinting
//    private let manifestGraphLoader: ManifestGraphLoading
//
//    convenience init() {
//        let manifestLoader = ManifestLoaderFactory()
//            .createManifestLoader()
//        let manifestGraphLoader = ManifestGraphLoader(manifestLoader: manifestLoader)
//        let codeLinter = CodeLinter()
//        self.init(
//            codeLinter: codeLinter,
//            manifestGraphLoader: manifestGraphLoader
//        )
//    }
//
//    init(
//        codeLinter: CodeLinting,
//        manifestGraphLoader: ManifestGraphLoading
//    ) {
//        self.codeLinter = codeLinter
//        self.manifestGraphLoader = manifestGraphLoader
//    }
//
//    func run(path: String?, targetName: String?, strict: Bool) throws {
//        // Determine destination path
//        let path = self.path(path)
//
//        // Load graph
//        logger.notice("Loading the dependency graph at \(path)")
//        let graph = try manifestGraphLoader.loadGraph(at: path)
//
//        // Get sources
//        let graphTraverser = GraphTraverser(graph: graph)
//        let sources = try getSources(targetName: targetName, graphTraverser: graphTraverser)
//
//        // Lint code
//        logger.notice("Running code linting")
//        try codeLinter.lint(sources: sources, path: path, strict: strict)
//    }
//
//    // MARK: - Destination path
//
//    private func path(_ path: String?) -> AbsolutePath {
//        guard let path = path else { return FileHandler.shared.currentPath }
//
//        return AbsolutePath(path, relativeTo: FileHandler.shared.currentPath)
//    }
//
//    // MARK: - Get sources to lint
//
//    private func getSources(targetName: String?, graphTraverser: GraphTraversing) throws -> [AbsolutePath] {
//        if let targetName = targetName {
//            return try getTargetSources(targetName: targetName, graphTraverser: graphTraverser)
//        } else {
//            return graphTraverser.allTargets()
//                .flatMap(\.target.sources)
//                .map(\.path)
//        }
//    }
//
//    private func getTargetSources(targetName: String, graphTraverser: GraphTraversing) throws -> [AbsolutePath] {
//        guard let target = graphTraverser.allTargets()
//            .map(\.target)
//            .first(where: { $0.name == targetName })
//        else {
//            throw LintCodeServiceError.targetNotFound(targetName)
//        }
//
//        let sources = target.sources.map(\.path)
//
//        if sources.isEmpty {
//            throw LintCodeServiceError.lintableFilesForTargetNotFound(targetName)
//        }
//        return sources
//    }
//}





//public protocol CodeLinting {
//    /// Lints source code in the given directory.
//    /// - Parameters:
//    ///   - sources: Directory in which source code will be linted.
//    ///   - path: Directory whose project will be linted.
//    ///   - strict: Bool if warnings should error.
//    func lint(sources: [AbsolutePath], path: AbsolutePath, strict: Bool) throws
//}
//
//public final class CodeLinter: CodeLinting {
//    private let rootDirectoryLocator: RootDirectoryLocating
//    private let binaryLocator: BinaryLocating
//
//    public init(rootDirectoryLocator: RootDirectoryLocating = RootDirectoryLocator(),
//                binaryLocator: BinaryLocating = BinaryLocator())
//    {
//        self.rootDirectoryLocator = rootDirectoryLocator
//        self.binaryLocator = binaryLocator
//    }
//
//    // MARK: - CodeLinting
//
//    public func lint(sources: [AbsolutePath], path: AbsolutePath, strict: Bool) throws {
//        let swiftLintPath = try binaryLocator.swiftLintPath()
//        let swiftLintConfigPath = swiftLintConfigPath(path: path)
//        let swiftLintArguments = buildSwiftLintArguments(
//            swiftLintPath: swiftLintPath,
//            sources: sources,
//            configPath: swiftLintConfigPath,
//            strict: strict
//        )
//        let environment = buildEnvironment(sources: sources)
//
//        _ = try System.shared.observable(
//            swiftLintArguments,
//            verbose: false,
//            environment: environment
//        )
//        .mapToString()
//        .print()
//        .toBlocking()
//        .last()
//    }
//
//    // MARK: - Helpers
//
//    private func swiftLintConfigPath(path: AbsolutePath) -> AbsolutePath? {
//        guard let rootPath = rootDirectoryLocator.locate(from: path) else { return nil }
//        return ["yml", "yaml"].compactMap { fileExtension -> AbsolutePath? in
//            let swiftlintPath = rootPath.appending(RelativePath("\(Constants.tuistDirectoryName)/.swiftlint.\(fileExtension)"))
//            return (FileHandler.shared.exists(swiftlintPath)) ? swiftlintPath : nil
//        }.first
//    }
//
//    private func buildEnvironment(sources: [AbsolutePath]) -> [String: String] {
//        var environment = ["SCRIPT_INPUT_FILE_COUNT": "\(sources.count)"]
//        for source in sources.enumerated() {
//            environment["SCRIPT_INPUT_FILE_\(source.offset)"] = source.element.pathString
//        }
//        return environment
//    }
//
//    private func buildSwiftLintArguments(swiftLintPath: AbsolutePath,
//                                         sources _: [AbsolutePath],
//                                         configPath: AbsolutePath?,
//                                         strict: Bool) -> [String]
//    {
//        var arguments = [
//            swiftLintPath.pathString,
//            "lint",
//            "--use-script-input-files",
//        ]
//
//        if let configPath = configPath {
//            arguments += ["--config", configPath.pathString]
//        }
//
//        if strict {
//            arguments += ["--strict"]
//        }
//
//        return arguments
//    }
//}
