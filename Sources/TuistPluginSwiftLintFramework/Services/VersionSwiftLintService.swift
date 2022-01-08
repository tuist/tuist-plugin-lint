import Foundation
import SwiftLintFramework

public final class VersionSwiftLintService {
    public init() {}
    
    public func run() {
        print(SwiftLintFramework.Version.current.value)
    }
}
