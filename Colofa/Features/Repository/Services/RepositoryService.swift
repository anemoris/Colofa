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

    /// Asks Git whether it would accept one branch name, so Colofa accepts exactly the names Git
    /// accepts rather than reproducing its rules.
    let validateBranchName: @Sendable (BranchNameValidationRequest) async throws -> Bool

    /// Reads which paths a Ref would rewrite, which is what lets a Checkout Git refused name the
    /// local work it protected.
    let loadCheckoutComparison: @Sendable (CheckoutComparisonRequest) async throws -> CheckoutComparison

    /// Reads what Git says about a local Branch a Delete would remove: the Commit it points at,
    /// and how many Commits only it holds. `nil` when Git no longer has the Branch. Asked when
    /// Delete Branch runs rather than with a snapshot: it decides what one command would cost,
    /// not what the Repository is.
    let loadBranchDeletionSurvey:
        @Sendable (BranchDeletionRequest) async throws -> BranchDeletionSurvey?

    /// Reads which remotes Git's configuration excludes from a Fetch of every remote. Asked when
    /// Fetch runs rather than with a snapshot: it decides what a command does, not what the
    /// Repository is.
    let loadSkippedRemotes: @Sendable (URL) async throws -> Set<String>

    /// Reads which local tags a remote's tags of the same name would have replaced, which is what
    /// lets a Fetch Tags Git refused name the tags it kept.
    let loadTagConflicts: @Sendable (TagConflictRequest) async throws -> TagFetchConflict

    /// Reads the remote Git's own configuration would publish a Branch to, or `nil` when it names
    /// none. Asked when Publish runs rather than with a snapshot: it decides where a command goes,
    /// not what the Repository is.
    let loadPublishRemote: @Sendable (PushTargetRequest) async throws -> String?

    /// Reads where a Push of one Branch goes and what its upstream held, which is the exact object
    /// a Force Push with Lease requires the remote to still hold.
    let loadPushTarget: @Sendable (PushTargetRequest) async throws -> PushTarget?

    /// Reads the one address a Push to a remote writes to, which is what a confirmation shows and
    /// what is checked again before anything is sent. Throws `PushDestinationRefusal` for a remote
    /// that resolves to this Repository or to more than one address.
    let loadPushDestination: @Sendable (PushDestinationRequest) async throws -> PushDestination

    /// Runs one command that contacts a remote. Separate from `runMutation` for two reasons: it
    /// can be stopped, because a network command has no duration Colofa can promise the user; and
    /// it is the only kind of command that can ask for a secret, so it is the only one that
    /// carries whoever answers.
    let runNetworkMutation: @Sendable ([String], URL, AuthenticationResponder) async throws -> Void

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
            },
            validateBranchName: { request in
                try await backend.validateBranchName(request)
            },
            loadCheckoutComparison: { request in
                try await backend.loadCheckoutComparison(request)
            },
            loadBranchDeletionSurvey: { request in
                try await backend.loadBranchDeletionSurvey(request)
            },
            loadSkippedRemotes: { url in
                try await backend.loadSkippedRemotes(in: url)
            },
            loadTagConflicts: { request in
                try await backend.loadTagConflicts(request)
            },
            loadPublishRemote: { request in
                try await backend.loadPublishRemote(request)
            },
            loadPushTarget: { request in
                try await backend.loadPushTarget(request)
            },
            loadPushDestination: { request in
                try await backend.loadPushDestination(request)
            },
            runNetworkMutation: { arguments, url, responder in
                try await backend.runNetworkMutation(arguments, in: url, responder: responder)
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
            loadCommitDetail: { _ in throw RepositoryOpenError.gitUnavailable },
            validateBranchName: { _ in throw RepositoryOpenError.gitUnavailable },
            loadCheckoutComparison: { _ in throw RepositoryOpenError.gitUnavailable },
            loadBranchDeletionSurvey: { _ in throw RepositoryOpenError.gitUnavailable },
            loadSkippedRemotes: { _ in throw RepositoryOpenError.gitUnavailable },
            loadTagConflicts: { _ in throw RepositoryOpenError.gitUnavailable },
            loadPublishRemote: { _ in throw RepositoryOpenError.gitUnavailable },
            loadPushTarget: { _ in throw RepositoryOpenError.gitUnavailable },
            loadPushDestination: { _ in throw RepositoryOpenError.gitUnavailable },
            runNetworkMutation: { _, _, _ in throw RepositoryOpenError.gitUnavailable }
        )
    }

    /// - Parameter backend: Built by the caller rather than here, so the same stub can answer the
    ///   Repository and the file system: a UI test's Move to Trash has to remove the very row the
    ///   Repository then stops reporting.
    static func uiTesting(_ backend: UITestingRepositoryService) -> Self {
        Self(
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
                await backend.loadHistory(request)
            },
            loadCommitDetail: { request in
                await backend.loadCommitDetail(request)
            },
            validateBranchName: { request in
                await backend.validateBranchName(request)
            },
            loadCheckoutComparison: { request in
                await backend.loadCheckoutComparison(request)
            },
            loadBranchDeletionSurvey: { request in
                await backend.branchDeletionSurvey(request)
            },
            loadSkippedRemotes: { _ in
                await backend.skippedRemotes()
            },
            loadTagConflicts: { request in
                await backend.tagConflicts(request)
            },
            loadPublishRemote: { request in
                await backend.publishRemote(request)
            },
            loadPushTarget: { request in
                await backend.pushTarget(request)
            },
            loadPushDestination: { request in
                try await backend.pushDestination(request)
            },
            runNetworkMutation: { arguments, url, responder in
                try await backend.runNetworkMutation(arguments, in: url, responder: responder)
            }
        )
    }
#endif
}
