////
//  RepositoryService.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

struct RepositoryService: Sendable {
    let availability: @Sendable () async -> GitAvailability
    let load: @Sendable (URL) async throws -> RepositorySnapshot

    /// Runs one mutating command, optionally feeding it standard input. Content that belongs to
    /// the user, such as a Commit message, travels here rather than in the argument list, which
    /// is echoed back in sanitized failure details.
    let runMutation: @Sendable ([String], String?, URL) async throws -> Void

    /// Reads one bounded patch. Separate from `load` because a Diff is chosen, not published:
    /// Repository state does not carry it, and its cost is paid only for the current selection.
    let loadDiff: @Sendable (DiffLoadRequest) async throws -> DiffLoadResult

    static func live() -> Self {
        let backend = GitRepositoryService()

        return Self(
            availability: {
                await backend.availability()
            },
            load: { url in
                try await backend.loadRepository(at: url)
            },
            runMutation: { arguments, standardInput, url in
                try await backend.runMutation(arguments, standardInput: standardInput, in: url)
            },
            loadDiff: { request in
                try await backend.loadDiff(request)
            }
        )
    }

#if DEBUG
    static func unavailable() -> Self {
        Self(
            availability: { .unavailable },
            load: { _ in throw RepositoryOpenError.gitUnavailable },
            runMutation: { _, _, _ in throw RepositoryOpenError.gitUnavailable },
            loadDiff: { _ in throw RepositoryOpenError.gitUnavailable }
        )
    }

    static func uiTesting(arguments: [String]) -> Self {
        let backend = UITestingRepositoryService(arguments: arguments)
        return Self(
            availability: { .available(URL(filePath: "/usr/bin/git")) },
            load: { url in
                try await backend.loadRepository(at: url)
            },
            runMutation: { arguments, standardInput, url in
                try await backend.runMutation(arguments, standardInput: standardInput, in: url)
            },
            loadDiff: { request in
                try await backend.loadDiff(request)
            }
        )
    }
#endif
}
