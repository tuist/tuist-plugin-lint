import Foundation

/// A service that prints the version of the plugin.
public final class VersionService {
    public init() {}
    
    /// The entry point of the service.
    public func run() {
        print(Constants.version)
    }
}
