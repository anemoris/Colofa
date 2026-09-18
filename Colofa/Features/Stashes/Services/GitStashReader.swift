////
//  GitStashReader.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// Reads Stashes under bounds enforced while Git is still writing, the same way History is.
///
/// Both reads are small by construction — one line per entry, and one short record per changed
/// path — so the bounds are a ceiling rather than a policy the user is asked about. Output that
/// reaches one is refused rather than truncated: a list cut in half would read as everything the
/// user had saved.
nonisolated struct GitStashReader: Sendable {
    let git: GitProcess

    func list(inRepositoryAt repositoryURL: URL) async throws -> [Stash] {
        let output = try await git.boundedData(
            GitStashCommand.list,
            in: repositoryURL,
            bounds: Self.listBounds,
            retainsOutput: true
        )
        guard !output.exceedsBounds else {
            throw GitOutputParsingError()
        }
        return try GitStashParser.parse(output.data)
    }

    /// The paths one Stash saved, counted without ever writing its patch out.
    ///
    /// Read as two comparisons because Git stored the Stash as two: what it changed in tracked
    /// files, and the Commit holding whatever was untracked. `git stash show --include-untracked`
    /// prints the union of exactly these, but says nothing about which side a path came from —
    /// and that is what decides which pair of objects the file's own Diff compares.
    func detail(_ request: StashDetailRequest) async throws -> StashDetail {
        var files = try await summaries(of: request.trackedSource, in: request.repositoryURL)
            .map { StashFile(summary: $0, isUntracked: false) }
        if let untrackedSource = request.untrackedSource {
            files += try await summaries(of: untrackedSource, in: request.repositoryURL)
                .map { StashFile(summary: $0, isUntracked: true) }
        }
        return StashDetail(objectID: request.objectID, files: files)
    }

    private func summaries(
        of source: DiffSource,
        in repositoryURL: URL
    ) async throws -> [DiffFileSummary] {
        let command = GitDiffCommand.numstat(for: source)
        // A partial list is refused rather than shown: it would read as the complete set of paths
        // the Stash saved.
        let counts = try await git.boundedData(
            command.arguments,
            in: repositoryURL,
            bounds: Self.changedFileBounds,
            retainsOutput: true,
            successfulExitStatuses: command.successfulExitStatuses
        )
        guard !counts.exceedsBounds else {
            throw GitOutputParsingError()
        }
        return try DiffNumstatParser.parse(counts.data)
    }

    /// One line per entry, so only the byte bound can be reached: a single record would have to
    /// hold megabytes of description to get there.
    private static let listBounds = GitOutputBounds(
        byteCount: 8 * 1_024 * 1_024,
        lineCount: .max
    )

    /// `--numstat -z` writes one short NUL-separated record per file and no newlines at all.
    private static let changedFileBounds = GitOutputBounds(
        byteCount: 4 * 1_024 * 1_024,
        lineCount: .max
    )
}
