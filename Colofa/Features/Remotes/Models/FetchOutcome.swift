////
//  FetchOutcome.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// What one Fetch actually did, which is not always what it was asked to do.
///
/// A Fetch of every remote is several commands, so it has partial answers: a remote can fail
/// after another already succeeded, and the user can stop it partway. Each of those is reported
/// as itself rather than collapsed into "it worked" or "it failed".
nonisolated enum FetchOutcome: Equatable, Sendable {

    /// Every eligible remote was refreshed.
    case fetched([String])

    /// Nothing ran: Git's configuration excludes every configured remote from a Fetch of all of
    /// them.
    case nothingEligible

    /// The user stopped it. Whatever had already been fetched stays fetched.
    case cancelled(fetched: [String])

    /// At least one remote failed. The remotes that answered are still refreshed.
    case failed(remotes: [String], fetched: [String], error: RepositoryOpenError)

    /// Colofa could not read which remotes are eligible, so no remote was contacted at all.
    case planFailed(RepositoryOpenError)

    /// Whether this Fetch is the kind that updates the app-owned last-Fetch time: every eligible
    /// remote answered, and there was at least one to answer.
    var isSuccessful: Bool {
        if case .fetched(let remotes) = self {
            !remotes.isEmpty
        } else {
            false
        }
    }

    /// Whether the user has to be told. A Fetch the user cancelled needs no alert explaining what
    /// the user just did.
    var needsReporting: Bool {
        switch self {
        case .fetched, .cancelled: false
        case .nothingEligible, .failed, .planFailed: true
        }
    }

    /// Git's own words, when Git got far enough to write any.
    var error: RepositoryOpenError? {
        switch self {
        case .failed(_, _, let error), .planFailed(let error): error
        case .fetched, .nothingEligible, .cancelled: nil
        }
    }

    /// What the alert is titled, or `nil` for an outcome that raises none.
    var title: LocalizedStringResource? {
        switch self {
        case .nothingEligible: .fetchNothingEligibleTitle
        case .failed, .planFailed: .fetchFailed
        case .fetched, .cancelled: nil
        }
    }

    /// What the alert says, or `nil` for an outcome that raises none.
    var message: LocalizedStringResource? {
        switch self {
        case .nothingEligible:
            .fetchNothingEligibleDescription
        case .planFailed:
            .fetchPlanFailedDescription
        case .failed(let remotes, let fetched, _):
            if fetched.isEmpty {
                .fetchRemotesFailedDescription(Self.list(remotes))
            } else {
                .fetchPartiallyFailedDescription(Self.list(remotes))
            }
        case .fetched, .cancelled:
            nil
        }
    }

    /// Remote names as one readable phrase, in the reader's own language.
    private static func list(_ remotes: [String]) -> String {
        remotes.formatted(.list(type: .and))
    }
}
