////
//  GitHistoryParser.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// Reads the record stream `GitHistoryCommand.recordFormat` produces.
///
/// A record it cannot read is a failure rather than a row with holes in it: a page that quietly
/// dropped a Commit would read as a complete History.
nonisolated enum GitHistoryParser {
    /// - Parameter remoteBranchNames: What the Repository reports as remote-tracking branches.
    ///   Git's decoration prints `origin/main` for one and `main` for a local branch, so nothing
    ///   in the text itself separates them from a local branch that happens to contain a slash.
    /// - Throws: `GitOutputParsingError` for any record that is not exactly the shape asked for.
    static func parse(
        _ data: Data,
        remoteBranchNames: Set<String> = []
    ) throws -> [HistoryCommit] {
        try data.split(separator: recordSeparator).map { record in
            try commit(record, remoteBranchNames: remoteBranchNames)
        }
    }

    /// Splits one `%D` decoration into the Refs it names, and reports whether Git marked the
    /// Commit as grafted.
    ///
    /// `grafted` is not a Ref: it is how a shallow Repository says that this Commit really does
    /// have parents and that they are not here. It is kept out of the labels and reported on its
    /// own, so nothing renders it as though a branch were called that.
    static func refLabels(
        decoration: String,
        remoteBranchNames: Set<String>
    ) -> (labels: [HistoryRefLabel], isShallowBoundary: Bool) {
        var labels: [HistoryRefLabel] = []
        var isShallowBoundary = false

        for item in decoration.components(separatedBy: ", ") where !item.isEmpty {
            if item == graftedMarker {
                isShallowBoundary = true
            } else if item.hasPrefix(tagPrefix) {
                labels.append(
                    HistoryRefLabel(name: String(item.dropFirst(tagPrefix.count)), kind: .tag)
                )
            } else if item == headName {
                labels.append(HistoryRefLabel(name: headName, kind: .head))
            } else if item.hasPrefix(headPointerPrefix) {
                labels.append(HistoryRefLabel(name: headName, kind: .head))
                labels.append(
                    branchLabel(
                        String(item.dropFirst(headPointerPrefix.count)),
                        remoteBranchNames: remoteBranchNames
                    )
                )
            } else {
                labels.append(branchLabel(item, remoteBranchNames: remoteBranchNames))
            }
        }

        return (labels, isShallowBoundary)
    }

    private static func branchLabel(
        _ name: String,
        remoteBranchNames: Set<String>
    ) -> HistoryRefLabel {
        HistoryRefLabel(
            name: name,
            kind: remoteBranchNames.contains(name) ? .remoteBranch : .localBranch
        )
    }

    private static func commit(
        _ record: Data,
        remoteBranchNames: Set<String>
    ) throws -> HistoryCommit {
        // Git terminates every record with a newline of its own, which belongs to neither the
        // subject nor the next record.
        var body = record[record.startIndex...]
        if body.last == UInt8(ascii: "\n") {
            body = body.dropLast()
        }
        let fields = body.split(separator: 0, omittingEmptySubsequences: false)
            .map(String.init(gitBytes:))
        guard fields.count == fieldCount,
              !fields[0].isEmpty,
              let authoredDate = date(fields[5]),
              let committedDate = date(fields[8]) else {
            throw GitOutputParsingError()
        }

        let refs = refLabels(decoration: fields[9], remoteBranchNames: remoteBranchNames)
        return HistoryCommit(
            objectID: fields[0],
            abbreviatedObjectID: fields[1],
            parentObjectIDs: fields[2].split(separator: " ").map(String.init),
            summary: fields[10],
            authorName: fields[3],
            authorEmail: fields[4],
            authoredDate: authoredDate,
            committerName: fields[6],
            committerEmail: fields[7],
            committedDate: committedDate,
            refLabels: refs.labels,
            isShallowBoundary: refs.isShallowBoundary
        )
    }

    private static func date(_ field: String) -> Date? {
        guard let seconds = Int(field) else {
            return nil
        }
        return Date(timeIntervalSince1970: TimeInterval(seconds))
    }

    /// ASCII record separator. Git identities, subjects, and Ref names cannot contain it.
    private static let recordSeparator = UInt8(0x1e)
    private static let fieldCount = 11
    private static let graftedMarker = "grafted"
    private static let tagPrefix = "tag: "
    private static let headName = "HEAD"
    private static let headPointerPrefix = "HEAD -> "
}
