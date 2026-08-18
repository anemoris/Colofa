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

    /// Reads one page of the History reachable from a Ref. Separate from `load` for the same
    /// reason a Diff is: a Repository has more History than any snapshot should carry, and only
    /// the selected Ref's pages are ever paid for.
    let loadHistory: @Sendable (HistoryPageRequest) async throws -> HistoryPage

    /// Reads the message and changed paths of one selected Commit, which a page deliberately
    /// leaves unread.
    let loadCommitDetail: @Sendable (HistoryCommitDetailRequest) async throws -> HistoryCommitDetail

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
            },
            loadHistory: { request in
                try await backend.loadHistory(request)
            },
            loadCommitDetail: { request in
                try await backend.loadCommitDetail(request)
            }
        )
    }

#if DEBUG
    static func unavailable() -> Self {
        Self(
            availability: { .unavailable },
            load: { _ in throw RepositoryOpenError.gitUnavailable },
            runMutation: { _, _, _ in throw RepositoryOpenError.gitUnavailable },
            loadDiff: { _ in throw RepositoryOpenError.gitUnavailable },
            loadHistory: { _ in throw RepositoryOpenError.gitUnavailable },
            loadCommitDetail: { _ in throw RepositoryOpenError.gitUnavailable }
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
            },
            loadHistory: { request in
                try await backend.loadHistory(request)
            },
            loadCommitDetail: { request in
                try await backend.loadCommitDetail(request)
            }
        )
    }
#endif
}
