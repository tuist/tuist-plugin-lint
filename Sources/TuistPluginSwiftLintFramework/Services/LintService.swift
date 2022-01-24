import Foundation
import ProjectAutomation

enum LintServiceError: Error, CustomStringConvertible, Equatable {
    /// Thrown when a graph can not be found at the given path.
    case graphNotFound(reason: String)
    
    /// Thrown when target with given name does not exist.
    case targetNotFound(targetName: String)
    
    /// Error description.
    var description: String {
        switch self {
        case .graphNotFound(let reason):
            return "The project's graph can not be found. Reason: \(reason)"
        case .targetNotFound(let targetName):
            return "A target with a name '\(targetName)' not found in the project."
        }
    }
}

/// A service that manages code linting.
public final class LintService {
    public init() {}
    
    /// The entry point of the service. Invoke it to start linting.
    /// - Parameters:
    ///   - path: The path to the directory that contains the workspace or project whose code will be linted.
    ///   - targetName: The target to be linted. When not specified all the targets of the graph are linted.
    public func run(path: String?, targetName: String?) throws {
        let graph = try getGraph(at: path)
        let sourcesToLint = try getSourcesToLint(in: graph, targetName: targetName)
    }
    
    // TODO: add unit tests
    private func getGraph(at path: String?) throws -> Graph {
        do {
            if let path = path {
                return try Tuist.graph(at: path)
            } else {
                return try Tuist.graph()
            }
        } catch {
            throw LintServiceError.graphNotFound(reason: "\(error)")
        }
    }
    
    // TODO: add unit tests
    private func getSourcesToLint(in graph: Graph, targetName: String?) throws -> [String] {
        if let targetName = targetName {
            guard let target = graph.allTargets.first(where: { $0.name == targetName }) else {
                throw LintServiceError.targetNotFound(targetName: targetName)
            }
            
            return target.sources
        }
        
        return graph.allTargets.flatMap { $0.sources }
    }
}

// TODO: add unit tests
private extension Graph {
    /// Returns a list of targets that are included into the graph.
    var allTargets: [Target] {
        projects.values.flatMap { $0.targets }
    }
}





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
