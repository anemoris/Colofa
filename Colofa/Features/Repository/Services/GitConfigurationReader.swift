////
//  GitConfigurationReader.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation

/// Builds the configuration half of a `RepositorySnapshot` from Git.
///
/// Two reads are needed and neither can be derived from the other:
///
/// - The *effective* read follows includes and conditional includes, which is what the user's
///   Git actually resolves and therefore what Colofa must display.
/// - The *direct* read skips includes, so whatever it reports lives literally in a file Colofa
///   can write to. Only those entries may be offered for editing or unsetting.
///
/// The direct read deliberately omits `--global`/`--local`: without a scope flag Git reports
/// every scope in one invocation, so the pair costs two subprocesses rather than three.
enum GitConfigurationReader {
    static let effectiveArguments = [
        "config", "--null", "--show-origin", "--show-scope", "--includes",
        "--get-regexp", GitConfigurationKey.gitReadPattern,
    ]

    static let directArguments = [
        "config", "--null", "--show-origin", "--show-scope", "--no-includes",
        "--get-regexp", GitConfigurationKey.gitReadPattern,
    ]

    /// Runs both reads through `run` and combines them into the snapshot the app consumes.
    ///
    /// `run` is expected to tolerate Git's exit status 1, which simply means the pattern matched
    /// nothing. The `isolation` parameter keeps it running in the caller's actor rather than
    /// being treated as concurrent work.
    static func snapshot(
        isolation: isolated (any Actor)? = #isolation,
        run: (_ arguments: [String]) async throws -> Data
    ) async throws -> GitConfigurationSnapshot {
        let effective = try GitConfigurationParser.parse(try await run(effectiveArguments))
        let direct = try GitConfigurationParser.parse(try await run(directArguments))
        return GitConfigurationSnapshot(
            entries: effective.entries,
            editableEntries: direct.entries.filter {
                $0.scope == .global || $0.scope == .local
            }
        )
    }
}
