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
