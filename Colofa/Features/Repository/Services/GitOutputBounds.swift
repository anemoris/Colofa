////
//  GitOutputBounds.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// The most standard output a bounded read is willing to take from one Git command.
///
/// Both counts are inclusive: output equal to a bound is still within it.
nonisolated struct GitOutputBounds: Equatable, Sendable {
    let byteCount: Int
    let lineCount: Int
}

/// What a bounded read observed.
///
/// `exceedsBounds` means reading stopped at a bound rather than at the end of Git's output, so
/// `byteCount` and `lineCount` are lower bounds and `data` is deliberately empty — the point of
/// stopping is not to hold output Colofa has already refused.
nonisolated struct GitBoundedOutput: Equatable, Sendable {
    let data: Data
    let byteCount: Int
    let lineCount: Int
    let exceedsBounds: Bool
}
