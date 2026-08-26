////
//  PullOutcome.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// What one Pull actually did, which is not always what it was asked to do.
///
/// A Pull is two commands, so its answers say which of them ended it. That distinction is the
/// whole reason the phases are separate: a remote that never answered says nothing at all about
/// whether the Branch could have been advanced, and reading a divergence into a Pull that never
/// got past the network would be inventing one.
nonisolated enum PullOutcome: Equatable, Sendable {

    /// The remote answered and the Branch is at its upstream, whether or not it had to move.
    case fastForwarded

    /// The user stopped the network phase. Whatever Git had already written stays written.
    case cancelled

    /// The remote was never reached, so nothing about the Branch was decided.
    case fetchFailed(RepositoryOpenError)

    /// The remote answered, but Git refused to advance the Branch.
    case integrationRefused(RepositoryOpenError)

    /// Whether the remote answered, which is what the app-owned last-Fetch time is about.
    ///
    /// A Pull that fetched and then could not fast-forward still fetched: its remote-tracking
    /// refs and ahead/behind counts are as fresh as a Fetch would have left them, and saying
    /// otherwise would date state the user is looking at right now. A Pull the user stopped is
    /// deliberately excluded, exactly as a stopped Fetch is.
    var reachedRemote: Bool {
        switch self {
        case .fastForwarded, .integrationRefused: true
        case .cancelled, .fetchFailed: false
        }
    }

    /// Whether the user has to be told. A Pull the user cancelled needs no alert explaining what
    /// the user just did.
    var needsReporting: Bool {
        error != nil
    }

    /// Git's own words, when Git got far enough to write any.
    var error: RepositoryOpenError? {
        switch self {
        case .fetchFailed(let error), .integrationRefused(let error): error
        case .fastForwarded, .cancelled: nil
        }
    }
}
