////
//  DiffFixtures.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
@testable import Colofa

/// A one-line replacement, which is the smallest Diff that still has both a deletion and an
/// addition to place.
func replacementDiff(path: String, byteCount: Int = 120, lineCount: Int = 8) -> Diff {
    Diff(
        files: [
            DiffFile(
                oldPath: path,
                newPath: path,
                content: .text([
                    DiffHunk(
                        id: 0,
                        oldStart: 1,
                        oldCount: 1,
                        newStart: 1,
                        newCount: 1,
                        lines: [
                            DiffLine(
                                id: 0,
                                kind: .deletion,
                                oldNumber: 1,
                                newNumber: nil,
                                text: "old"
                            ),
                            DiffLine(
                                id: 1,
                                kind: .addition,
                                oldNumber: nil,
                                newNumber: 1,
                                text: "new"
                            ),
                        ]
                    ),
                ])
            ),
        ],
        measurement: DiffMeasurement(
            byteCount: byteCount,
            lineCount: lineCount,
            isComplete: true
        )
    )
}

/// The summary of a patch Colofa did not render. `stats` is absent for a binary change, and an
/// incomplete measurement is what a patch beyond a hard limit reports.
func diffSummary(
    path: String,
    stats: DiffStats?,
    byteCount: Int,
    lineCount: Int,
    isComplete: Bool
) -> DiffSummary {
    DiffSummary(
        files: [DiffFileSummary(oldPath: nil, newPath: path, stats: stats)],
        measurement: DiffMeasurement(
            byteCount: byteCount,
            lineCount: lineCount,
            isComplete: isComplete
        )
    )
}
