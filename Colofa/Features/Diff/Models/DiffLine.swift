////
//  DiffLine.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// One line of a text patch, carrying the numbers Git assigns it on each side.
///
/// A line number is absent whenever that side has no such line: an addition exists only in the
/// new file, a deletion only in the old one, and the no-newline marker in neither.
nonisolated struct DiffLine: Equatable, Identifiable, Sendable {
    enum Kind: Equatable, Sendable {
        case context
        case addition
        case deletion
        /// Git's `\ No newline at end of file` note. It documents the line above it rather than
        /// being content, so it is kept as its own line and rendered as Colofa's own text.
        case noNewlineMarker
    }

    /// Position within the owning Hunk, which is what makes the line addressable in a list.
    let id: Int
    let kind: Kind
    let oldNumber: Int?
    let newNumber: Int?
    let text: String
}
