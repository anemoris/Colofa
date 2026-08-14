////
//  DiffNumstatParser.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// Reads `git diff --numstat -z`, which counts changed lines without writing the patch out.
///
/// That is what lets Colofa report exact stats for a patch it refused to read to the end. The
/// NUL-separated form is used because it prints paths verbatim, so no path needs unquoting and
/// none can be misread.
nonisolated struct DiffNumstatParser {
    /// - Throws: `GitOutputParsingError` for a record Colofa cannot read, so a summary never
    ///   states counts it did not receive.
    static func parse(_ data: Data) throws -> [DiffFileSummary] {
        var summaries: [DiffFileSummary] = []
        let records = data.split(separator: 0).map(String.init(gitBytes:))
        var index = 0

        while index < records.count {
            let fields = records[index].split(separator: "\t", omittingEmptySubsequences: false)
            guard fields.count == 3 else {
                throw GitOutputParsingError()
            }
            let stats = try lineStats(additions: fields[0], deletions: fields[1])

            if fields[2].isEmpty {
                // A rename empties the path field and follows it with the old and new paths as
                // two records of their own.
                guard index + 2 < records.count else {
                    throw GitOutputParsingError()
                }
                summaries.append(
                    DiffFileSummary(
                        oldPath: records[index + 1],
                        newPath: records[index + 2],
                        stats: stats
                    )
                )
                index += 3
            } else {
                summaries.append(
                    DiffFileSummary(oldPath: nil, newPath: String(fields[2]), stats: stats)
                )
                index += 1
            }
        }

        return summaries
    }

    /// Git writes `-` for both counts of a binary change rather than writing zero, because no
    /// lines were compared at all.
    private static func lineStats(
        additions: Substring,
        deletions: Substring
    ) throws -> DiffStats? {
        if additions == "-" && deletions == "-" {
            return nil
        }
        guard let additions = Int(additions), let deletions = Int(deletions) else {
            throw GitOutputParsingError()
        }
        return DiffStats(additions: additions, deletions: deletions)
    }
}
