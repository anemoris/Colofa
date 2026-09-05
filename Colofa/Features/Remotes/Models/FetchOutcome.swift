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

    /// Whether a remote actually answered, which is what the app-owned last-Fetch time records.
    ///
    /// A remote that answered before another one failed, or before the user stopped the Fetch,
    /// was still contacted, and what it refreshed is as fresh as this moment. Waiting for every
    /// eligible remote would report the Repository as staler than it is, and would not even be
    /// consistent with a Fetch Tags, which contacts one remote and records the time for it.
    var reachedRemote: Bool {
        switch self {
        case .fetched(let remotes), .cancelled(let remotes): !remotes.isEmpty
        case .failed(_, let fetched, _): !fetched.isEmpty
        case .nothingEligible, .planFailed: false
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
    ///
    /// A program Git could not find is preferred over naming the remotes, because it is the same
    /// answer for every one of them: no remote refused anything, and a Fetch that names them is
    /// pointing the user at the part that worked.
    var message: LocalizedStringResource? {
        if let missingHelper = error?.missingHelper {
            missingHelper.message
        } else {
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
    }

    /// Remote names as one readable phrase, in the reader's own language.
    private static func list(_ remotes: [String]) -> String {
        remotes.formatted(.list(type: .and))
    }
}
