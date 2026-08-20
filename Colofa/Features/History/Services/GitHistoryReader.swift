////
//  GitHistoryReader.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// Reads History under bounds enforced while Git is still writing, the same way a Diff is read.
///
/// A page is small by construction — one line per Commit, and the body left unread — so the
/// bounds here are a ceiling rather than a policy the user is asked about. Output that reaches
/// one is refused rather than truncated: a page cut in half would read as the end of History.
nonisolated struct GitHistoryReader: Sendable {
    let git: GitProcess

    func page(_ request: HistoryPageRequest) async throws -> HistoryPage {
        let output = try await git.boundedData(
            GitHistoryCommand.page(for: request).arguments,
            in: request.repositoryURL,
            bounds: Self.pageBounds,
            retainsOutput: true
        )
        guard !output.exceedsBounds else {
            throw GitOutputParsingError()
        }

        var commits = try GitHistoryParser.parse(
            output.data,
            remoteBranchNames: request.remoteBranchNames
        )
        // The extra record was only ever asked for to answer whether anything follows the page.
        let hasMore = commits.count > request.pageSize
        if hasMore {
            commits.removeLast(commits.count - request.pageSize)
        }
        return HistoryPage(commits: commits, hasMore: hasMore)
    }

    func commitDetail(_ request: HistoryCommitDetailRequest) async throws -> HistoryCommitDetail {
        let message = try await git.boundedData(
            GitHistoryCommand.message(for: request.objectID).arguments,
            in: request.repositoryURL,
            bounds: Self.messageBounds,
            retainsOutput: true
        )
        guard !message.exceedsBounds else {
            throw GitOutputParsingError()
        }

        let command = GitDiffCommand.numstat(for: request.diffSource)
        // Counting changed lines never writes the patch out, so this stays small however large
        // the Commit is. A partial list is refused rather than shown: it would read as the
        // complete set of paths the Commit touched.
        let counts = try await git.boundedData(
            command.arguments,
            in: request.repositoryURL,
            bounds: Self.changedFileBounds,
            retainsOutput: true,
            successfulExitStatuses: command.successfulExitStatuses
        )
        guard !counts.exceedsBounds else {
            throw GitOutputParsingError()
        }

        return HistoryCommitDetail(
            objectID: request.objectID,
            message: Self.message(from: message.data),
            changedFiles: try DiffNumstatParser.parse(counts.data)
        )
    }

    /// `%B` followed by the single newline `git log` ends every record with, which belongs to the
    /// record rather than to the message.
    private static func message(from data: Data) -> String {
        let record = String(gitBytes: data)
        return record.hasSuffix("\n") ? String(record.dropLast()) : record
    }

    /// A page is one line per Commit, so only the byte bound can be reached: a single record
    /// would have to hold megabytes of subject or Ref names to get there.
    private static let pageBounds = GitOutputBounds(
        byteCount: 8 * 1_024 * 1_024,
        lineCount: .max
    )

    private static let messageBounds = GitOutputBounds(
        byteCount: 1_024 * 1_024,
        lineCount: .max
    )

    /// `--numstat -z` writes one short NUL-separated record per file and no newlines at all.
    private static let changedFileBounds = GitOutputBounds(
        byteCount: 4 * 1_024 * 1_024,
        lineCount: .max
    )
}
