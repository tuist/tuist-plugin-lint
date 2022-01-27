import Foundation

/// Leniency strategy.
public enum Leniency: Equatable {
    /// Keeps warnings as warnings and serious violations as serious violations.
    case `default`
    
    /// Upgrades warnings to serious violations (errors).
    case strict
    
    /// Downgrades serious violations to warnings, warning threshold is disabled.
    case lenient
}
