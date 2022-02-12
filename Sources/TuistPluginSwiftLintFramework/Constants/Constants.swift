import Foundation

/// A set of constant values that can be reused across `TuistPluginSwiftLintFramework` module.
enum Constants {
    /// The plugin version.
    static let version = "0.0.1"
    
    /// A set of constant values that reflects values from Tuist project.
    enum Tuist {
        /// A name of the directory that contains Tuist files.
        static let tuistDirectoryName = "Tuist"
        
        /// A name of the directory that contains 3rd party dependencies installed using `Dependencies.swift`.
        static let dependenciesDirectoryName = "Dependencies"
    }
}
