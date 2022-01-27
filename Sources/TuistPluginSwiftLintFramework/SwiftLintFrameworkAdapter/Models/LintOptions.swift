import Foundation

#warning("needs documentation")

struct LintOptions {
    /// Leniency strategy.
    enum Leniency: Equatable {
        /// Keeps warnings as warnings and serious violations as serious violations.
        case `default`
        
        /// Upgrades warnings to serious violations (errors).
        case strict
        
        /// Downgrades serious violations to warnings, warning threshold is disabled.
        case lenient
    }
    
    let paths: [String]
    let configurationFiles: [String]
    let leniency: Leniency
    let forceExclude: Bool
    let reporter: String?
    let quiet: Bool
    
    #warning("make `configurationFiles` configurable")
    #warning("make `leniency` configurable")
    #warning("make `quiet` configurable")
    
    static func create(sources: [String]) -> Self {
        LintOptions(
            paths: sources,
            configurationFiles: [],
            leniency: .default,
            forceExclude: false,
            reporter: nil,
            quiet: false
        )
    }
    
    var verb: String {
        "linting"
    }
}
