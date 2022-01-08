import Foundation
import SwiftLintFramework

/// A service that prints the version of SwiftLint.
public final class VersionSwiftLintService {
    public init() {}
    
    /// The entry point of the service.
    public func run() {
        print(SwiftLintFramework.Version.current.value)
    }
}
