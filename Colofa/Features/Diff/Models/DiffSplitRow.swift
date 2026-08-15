////
//  DiffSplitRow.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// One row of the Split layout, pairing what a change replaced with what it wrote.
///
/// A side is absent when the run of deletions and the run of additions have different lengths,
/// which is what makes an unbalanced replacement readable side by side.
nonisolated struct DiffSplitRow: Equatable, Identifiable, Sendable {
    let id: Int
    let old: DiffLine?
    let new: DiffLine?

    /// Regroups unified lines into side-by-side rows.
    ///
    /// Deletions and the additions that follow them form one replacement, so they are zipped
    /// rather than stacked: reviewing a Split layout means comparing the two halves of one row.
    /// Context appears on both sides, and the no-newline marker stays on the side of the line it
    /// documents rather than being duplicated onto a file that does end in a newline.
    static func rows(from lines: [DiffLine]) -> [DiffSplitRow] {
        var rows: [DiffSplitRow] = []
        var deletions: [DiffLine] = []
        var additions: [DiffLine] = []
        var previousKind: DiffLine.Kind?

        func flushReplacement() {
            for index in 0..<max(deletions.count, additions.count) {
                rows.append(
                    DiffSplitRow(
                        id: rows.count,
                        old: index < deletions.count ? deletions[index] : nil,
                        new: index < additions.count ? additions[index] : nil
                    )
                )
            }
            deletions.removeAll()
            additions.removeAll()
        }

        for line in lines {
            switch line.kind {
            case .deletion:
                // An addition already seen closes the previous replacement: this deletion opens
                // the next one rather than joining additions that answered earlier deletions.
                if !additions.isEmpty {
                    flushReplacement()
                }
                deletions.append(line)
            case .addition:
                additions.append(line)
            case .context:
                flushReplacement()
                rows.append(DiffSplitRow(id: rows.count, old: line, new: line))
            case .noNewlineMarker:
                switch previousKind {
                case .deletion:
                    deletions.append(line)
                case .addition:
                    additions.append(line)
                default:
                    flushReplacement()
                    rows.append(DiffSplitRow(id: rows.count, old: line, new: line))
                }
            }
            previousKind = line.kind
        }
        flushReplacement()

        return rows
    }
}
