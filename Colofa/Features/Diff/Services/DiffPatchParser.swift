////
//  DiffPatchParser.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// Turns one unified patch into the files, Hunks, and lines Colofa renders.
nonisolated struct DiffPatchParser {
    private static let fileHeader = "diff --git "

    /// - Throws: `GitOutputParsingError` when the output is not a unified patch, so a Diff is
    ///   never assembled from text Colofa did not understand.
    static func parse(_ data: Data) throws -> [DiffFile] {
        var files: [DiffFile] = []
        var accumulator: DiffFileAccumulator?

        for line in lines(of: data) {
            if line.hasPrefix(fileHeader) {
                if let accumulator {
                    files.append(accumulator.build())
                }
                accumulator = DiffFileAccumulator(
                    header: String(line.dropFirst(fileHeader.count))
                )
                continue
            }
            guard accumulator != nil else {
                throw GitOutputParsingError()
            }
            try accumulator?.consume(line)
        }

        if let accumulator {
            files.append(accumulator.build())
        }
        return files
    }

    /// Splits on newlines before decoding, so one undecodable line cannot cost the whole patch
    /// and line boundaries stay exactly where Git put them.
    private static func lines(of data: Data) -> [String] {
        guard !data.isEmpty else {
            return []
        }
        var records = data.split(
            separator: UInt8(ascii: "\n"),
            omittingEmptySubsequences: false
        )
        // A trailing newline ends the last line; it does not begin an empty one.
        if records.last?.isEmpty == true {
            records.removeLast()
        }
        return records.map(String.init(gitBytes:))
    }
}
