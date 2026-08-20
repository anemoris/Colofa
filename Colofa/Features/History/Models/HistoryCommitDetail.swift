////
//  HistoryCommitDetail.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// What one selected Commit is read for beyond its row: the message exactly as it holds it, and
/// the paths it changed.
///
/// Kept apart from `HistoryCommit` because a page holds 200 rows and neither of these has an
/// upper bound worth paying for 200 times.
nonisolated struct HistoryCommitDetailRequest: Equatable, Sendable {
    let repositoryURL: URL
    let objectID: String
    /// What the Commit is compared against. `nil` for a root Commit and for the boundary of a
    /// shallow Repository, where Git compares against an empty tree instead.
    let parentObjectID: String?

    /// The whole Commit, which is what counting its changed files asks for. Reading a patch
    /// narrows this to one of them.
    var diffSource: DiffSource {
        .commit(objectID: objectID, parentObjectID: parentObjectID)
    }
}

nonisolated struct HistoryCommitDetail: Equatable, Sendable {
    let objectID: String
    /// The message byte for byte, minus only the single newline `git log` ends its record with.
    let message: String
    let changedFiles: [DiffFileSummary]

    /// The message's first line, which is what a Commit is identified by.
    ///
    /// The line byte for byte, including whatever whitespace it opens with: this pane shows the
    /// message rather than a rendering of it, so nothing is trimmed away. Git's `%s`, which a
    /// row shows, folds every line before the first blank one into one line, so a Commit whose
    /// first paragraph spans several lines reads differently here on purpose.
    var summary: String {
        String(messageLines.first ?? "")
    }

    /// Everything past the first line, with the blank line Git writes between them removed.
    ///
    /// Only line breaks are trimmed off the front, so a body that opens with an indented line
    /// keeps its indentation. Trailing whitespace goes because the last of it is not the
    /// Commit's: `GitHistoryReader` strips the newline `git log` ends its record with, and a
    /// message written with CRLF ends in a `\r\n` Swift reads as one Character rather than as
    /// the `\n` that strip looks for, leaving the record's newline attached to the message.
    var body: String {
        let lines = messageLines
        guard lines.count > 1 else {
            return ""
        }
        let rest = lines[1].trimmingPrefix(while: \.isNewline)
        guard let end = rest.lastIndex(where: { !$0.isWhitespace }) else {
            return ""
        }
        return String(rest[...end])
    }

    /// The Summary and everything after it, split on whatever line break the message uses.
    ///
    /// Split on any line break rather than on `\n`: Swift reads CRLF as a single Character, so a
    /// message written with CRLF holds no `\n` to split on at all and would otherwise read as one
    /// line — the whole message rendered as the Summary, with no body.
    private var messageLines: [Substring] {
        message.split(maxSplits: 1, omittingEmptySubsequences: false, whereSeparator: \.isNewline)
    }

    func file(_ id: String) -> DiffFileSummary? {
        changedFiles.first { $0.id == id }
    }

    var stats: DiffStats {
        changedFiles.reduce(.zero) { $0 + ($1.stats ?? .zero) }
    }
}
