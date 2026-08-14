////
//  GitHeadCommitReader.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// Reads the commit HEAD points at, and whether a remote already has it.
///
/// Declared `nonisolated` because the project defaults to Main Actor isolation while
/// `GitRepositoryService` reads this from an actor.
nonisolated enum GitHeadCommitReader {
    /// - Parameter hasRemoteBranches: Skips the published check when there is no remote-tracking
    ///   ref that could contain HEAD. `--contains` walks history, so it is not worth asking. The
    ///   answer is only as current as the last Fetch, which `RepositoryHeadCommit.isPublished`
    ///   records.
    /// - Returns: `nil` on an Unborn Branch, and for a message Colofa cannot decode — offering
    ///   either one for Amend would rewrite bytes the user never saw.
    static func headCommit(
        head: RepositoryHead,
        hasRemoteBranches: Bool,
        using git: GitProcess,
        in repositoryURL: URL
    ) async throws -> RepositoryHeadCommit? {
        if case .unbornBranch = head {
            return nil
        }

        // Read raw and unbounded. `%s` is not the first line: Git joins every line before the
        // first blank one with spaces, so a Summary read that way would already differ from the
        // bytes the Commit holds, and a truncated read would silently shorten what Amend rewrites.
        let message = try await git.data(
            ["log", "--max-count=1", "--format=%H%x00%B", "HEAD"],
            in: repositoryURL
        )
        let containingRemoteRef = hasRemoteBranches ? try await git.text(
            [
                "for-each-ref", "--contains", "HEAD", "--count=1",
                "--format=%(refname)", "refs/remotes",
            ],
            in: repositoryURL
        ) : ""

        return parse(message, isPublished: !containingRemoteRef.isEmpty)
    }

    static func parse(_ message: Data, isPublished: Bool) -> RepositoryHeadCommit? {
        let fields = message.split(separator: 0, maxSplits: 1, omittingEmptySubsequences: false)
        guard fields.count == 2,
              let objectID = String(bytes: fields[0], encoding: .utf8),
              !objectID.isEmpty,
              let record = String(bytes: fields[1], encoding: .utf8) else {
            return nil
        }
        return headCommit(objectID: objectID, record: record, isPublished: isPublished)
    }

    /// Splits a message the way the composer presents it: the first line is the Summary and
    /// everything past it is the Description, each trimmed exactly as the composer trims them.
    ///
    /// What that would commit is then compared with the message byte for byte, so a Commit the
    /// composer cannot reproduce — a first line without a blank line after it, an indented or
    /// leading-space line, trailing blank lines a verbatim cleanup kept — is flagged rather than
    /// quietly reformatted by the Amend that follows. Nothing is trimmed off the message before
    /// that comparison: whitespace the composer would drop is the whole point of the check.
    ///
    /// - Parameter record: `%B` followed by the single newline `git log` ends every record with.
    private static func headCommit(
        objectID: String,
        record: String,
        isPublished: Bool
    ) -> RepositoryHeadCommit {
        let message = record.hasSuffix("\n") ? String(record.dropLast()) : record
        let lines = message.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
        let summary = String(lines.first ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let body = lines.count > 1
            ? String(lines[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            : ""

        return RepositoryHeadCommit(
            objectID: objectID,
            summary: summary,
            body: body,
            isPublished: isPublished,
            amendReformatsMessage: committedMessage(summary: summary, body: body) != message
        )
    }

    /// What Git stores for a Summary and Description, after the `whitespace` cleanup it applies
    /// to `--file` input by default: every line loses its trailing whitespace, runs of blank
    /// lines collapse into one, leading and trailing blank lines go, and what remains ends with
    /// exactly one newline.
    ///
    /// A Repository that sets `commit.cleanup` to something else does not follow this, and
    /// Colofa does not read that setting; the check is one-sided either way, reporting a rewrite
    /// the composer would cause rather than promising one it would not.
    static func committedMessage(summary: String, body: String) -> String {
        let message = cleaningWhitespace(body.isEmpty ? summary : "\(summary)\n\n\(body)")
        return message.isEmpty ? message : message + "\n"
    }

    private static func cleaningWhitespace(_ message: String) -> String {
        var lines: [String] = []
        for line in message.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = trimmingTrailingWhitespace(line)
            // Git keeps one blank line wherever the message had a run of them.
            if trimmed.isEmpty, lines.last?.isEmpty ?? true {
                continue
            }
            lines.append(trimmed)
        }
        while lines.last?.isEmpty == true {
            lines.removeLast()
        }
        return lines.joined(separator: "\n")
    }

    private static func trimmingTrailingWhitespace(_ line: Substring) -> String {
        var end = line.endIndex
        while end > line.startIndex, line[line.index(before: end)].isWhitespace {
            end = line.index(before: end)
        }
        return String(line[line.startIndex..<end])
    }
}
