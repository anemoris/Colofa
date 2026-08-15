////
//  DiffHunk.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// A contiguous block of related changed lines, held in both layouts Colofa can render.
///
/// The Split rows are built once here rather than in a view: regrouping a hundred thousand lines
/// is not work a frequently evaluated `body` may repeat, and the rows share their lines' storage,
/// so keeping both costs one struct per row rather than a second copy of the patch.
nonisolated struct DiffHunk: Equatable, Identifiable, Sendable {
    /// Position within the owning file, which is what makes the Hunk addressable in a list.
    let id: Int
    let oldStart: Int
    let oldCount: Int
    let newStart: Int
    let newCount: Int
    /// The context Git prints after the ranges, such as the enclosing function. Empty when Git
    /// found none.
    let heading: String
    let lines: [DiffLine]
    let splitRows: [DiffSplitRow]
    let stats: DiffStats

    init(
        id: Int,
        oldStart: Int,
        oldCount: Int,
        newStart: Int,
        newCount: Int,
        heading: String = "",
        lines: [DiffLine]
    ) {
        self.id = id
        self.oldStart = oldStart
        self.oldCount = oldCount
        self.newStart = newStart
        self.newCount = newCount
        self.heading = heading
        self.lines = lines
        splitRows = DiffSplitRow.rows(from: lines)
        stats = DiffStats(
            additions: lines.count(where: { $0.kind == .addition }),
            deletions: lines.count(where: { $0.kind == .deletion })
        )
    }

    /// The ranges exactly as Git states them, which is what a reviewer compares against a patch
    /// applied elsewhere.
    var rangeDescription: String {
        "@@ -\(oldStart),\(oldCount) +\(newStart),\(newCount) @@"
    }
}
