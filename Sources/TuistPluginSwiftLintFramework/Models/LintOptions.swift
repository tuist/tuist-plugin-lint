import Foundation

#warning("needs documentation")

struct LintOptions {
    let paths: [String]
    let useSTDIN: Bool
    let configurationFiles: [String]
    let strict: Bool
    let lenient: Bool
    let forceExclude: Bool
    let useExcludingByPrefix: Bool
    let useScriptInputFiles: Bool
    let reporter: String?
    let quiet: Bool
    let cachePath: String?
    let ignoreCache: Bool
    let enableAllRules: Bool
    
    #warning("make `configurationFiles` configurable")
    #warning("make `strict` configurable")
    #warning("make `lenient` configurable")
    #warning("make `quiet` configurable")
    
    #warning("TODO: can `strict` and `lenient` be merged?")
    
    static func create(sources: [String]) -> Self {
        LintOptions(
            paths: sources,
            useSTDIN: false,
            configurationFiles: [],
            strict: false,
            lenient: false,
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
