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
/// - The *direct* read skips includes, so whatever it reports lives literally in a file. Only
///   those entries may be offered for editing or unsetting, and a global one only when it lives
///   in the very file a `--global` write lands in — see `GitGlobalConfigurationFile`.
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
    ///
    /// - Parameter globalWriteTarget: The file a `--global` write lands in. A global entry from
    ///   any other file is reported as a source the user can see but not edit, because unsetting
    ///   it at that scope is a command Git answers with exit status 5 while the value stays in
    ///   force. `nil` leaves every global entry read-only, which is the honest answer when there
    ///   is no file to write to.
    static func snapshot(
        isolation: isolated (any Actor)? = #isolation,
        globalWriteTarget: String?,
        run: (_ arguments: [String]) async throws -> Data
    ) async throws -> GitConfigurationSnapshot {
        let effective = try GitConfigurationParser.parse(try await run(effectiveArguments))
        let direct = try GitConfigurationParser.parse(try await run(directArguments))
        return GitConfigurationSnapshot(
            entries: effective.entries,
            editableEntries: direct.entries.filter { entry in
                switch entry.scope {
                case .local:
                    // One Repository has one `.git/config`, so its scope already names its file.
                    true
                case .global:
                    globalWriteTarget.map(entry.origin.isFile(at:)) ?? false
                default:
                    false
                }
            }
        )
    }
}
