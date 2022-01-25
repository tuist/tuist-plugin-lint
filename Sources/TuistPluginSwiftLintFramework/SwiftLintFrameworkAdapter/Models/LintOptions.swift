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
    let useSTDIN: Bool
    let configurationFiles: [String]
    let leniency: Leniency
    let forceExclude: Bool
    let useExcludingByPrefix: Bool
    let useScriptInputFiles: Bool
    let reporter: String?
    let quiet: Bool
    let cachePath: String?
    let ignoreCache: Bool
    let enableAllRules: Bool
    
    #warning("make `configurationFiles` configurable")
    #warning("make `leniency` configurable")
    #warning("make `quiet` configurable")
    
    static func create(sources: [String]) -> Self {
        LintOptions(
            paths: sources,
            useSTDIN: false,
            configurationFiles: [],
            leniency: .default,
            forceExclude: false,
            useExcludingByPrefix: false,
            useScriptInputFiles: false,
            reporter: nil,
            quiet: false,
            cachePath: nil,
            ignoreCache: false,
            enableAllRules: false
        )
    }
    
    var verb: String {
        "linting"
    }
}
