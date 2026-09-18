////
//  GitStashParser.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// Reads the field stream `GitStashCommand.list` produces: every field NUL-terminated, eight to
/// a record.
///
/// A record it cannot read is a failure rather than a row with holes in it: a list that quietly
/// dropped an entry would read as everything the user had saved.
nonisolated enum GitStashParser {
    /// - Throws: `GitOutputParsingError` for a stream that does not divide into whole records, and
    ///   for any record that is not exactly the shape asked for, including one carrying fewer
    ///   parents than a Stash Commit has.
    static func parse(_ data: Data) throws -> [Stash] {
        guard !data.isEmpty else {
            return []
        }
        // `-z` terminates the last record too, so a stream that does not end in NUL was cut off.
        guard data.last == 0 else {
            throw GitOutputParsingError()
        }
        let fields = data.dropLast()
            .split(separator: 0, omittingEmptySubsequences: false)
            .map(String.init(gitBytes:))
        guard fields.count.isMultiple(of: fieldCount) else {
            throw GitOutputParsingError()
        }
        return try stride(from: 0, to: fields.count, by: fieldCount).map {
            try stash(fields[$0..<$0 + fieldCount])
        }
    }

    private static func stash(_ record: ArraySlice<String>) throws -> Stash {
        let fields = Array(record)
        let parents = fields[3].split(separator: " ").map(String.init)
        guard !fields[0].isEmpty,
              !fields[1].isEmpty,
              // Git builds every Stash from the Commit it was saved on and the index at the time,
              // so anything with fewer parents is not a record this parser understands.
              parents.count >= trackedParentCount,
              let authoredDate = date(fields[6]) else {
            throw GitOutputParsingError()
        }

        return Stash(
            selector: fields[0],
            objectID: fields[1],
            abbreviatedObjectID: fields[2],
            baseObjectID: parents[0],
            untrackedObjectID: parents.count > trackedParentCount
                ? parents[trackedParentCount]
                : nil,
            message: fields[7],
            authorName: fields[4],
            authorEmail: fields[5],
            authoredDate: authoredDate
        )
    }

    private static func date(_ field: String) -> Date? {
        guard let seconds = Int(field) else {
            return nil
        }
        return Date(timeIntervalSince1970: TimeInterval(seconds))
    }

    private static let fieldCount = GitStashCommand.recordFields.count

    /// The base Commit and the index Commit, which every Stash has. A third parent is the
    /// untracked files, and only a Stash saved with Include Untracked Files has one.
    private static let trackedParentCount = 2
}
