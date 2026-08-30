////
//  PushOutcome.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// What one Publish or Push actually did.
///
/// A Push writes to a remote, so its answers stay separate from a Fetch's: nothing here ever
/// records a last-Fetch time, because a Push downloads nothing and dating the Repository from one
/// would date state the user is looking at against work that never arrived.
nonisolated enum PushOutcome: Equatable, Sendable {

    /// The remote accepted the update, whether or not it had to move.
    case succeeded

    /// The user stopped it. Whatever the remote already accepted stays accepted.
    case cancelled

    /// The command failed, whether the remote refused it or was never reached at all.
    case failed(RepositoryOpenError)

    /// Git's own words, when Git got far enough to write any.
    var error: RepositoryOpenError? {
        if case .failed(let error) = self {
            error
        } else {
            nil
        }
    }
}
