////
//  PushUnavailabilityReason.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// Why Publish and Push cannot run right now, so a disabled control explains itself instead of
/// letting Git refuse the command afterwards.
///
/// An unresolved Conflict and an active operation are deliberately absent. Neither stops Git from
/// pushing Commits that already exist, and refusing one here would be Colofa inventing a rule the
/// user would then have to work around. What the upstream turns out to hold is absent for the
/// opposite reason: only the remote can answer that, so it is reported as a refusal after Git
/// gives it.
nonisolated enum PushUnavailabilityReason: Equatable, Sendable {
    case noRepository

    /// Detached HEAD is on no Branch, so there is no Branch to publish and no upstream to push
    /// to. Whatever was committed there is reachable from nothing a remote could hold.
    case detachedHead

    /// An Unborn Branch names no Commit, so there is nothing for a remote to receive.
    case unbornBranch

    /// The Repository has no remote at all, so there is nowhere to publish to.
    case noRemote

    case pushInProgress
    case mutationInProgress

    /// Why a Push cannot start, or `nil` when it may.
    ///
    /// Ordered by what the user has to do about it: the states no command can resolve come first,
    /// then the ones another command is holding. `mutationInProgress` is last so a transient
    /// in-flight command never replaces a standing explanation with a flicker.
    static func evaluate(
        repository: RepositorySnapshot?,
        isMutating: Bool,
        isPushing: Bool
    ) -> Self? {
        guard let repository else {
            return .noRepository
        }
        if case .detached = repository.head {
            return .detachedHead
        }
        if case .unbornBranch = repository.head {
            return .unbornBranch
        }
        if repository.remotes.isEmpty {
            return .noRemote
        }
        if isPushing {
            return .pushInProgress
        }
        return isMutating ? .mutationInProgress : nil
    }

    var message: LocalizedStringResource {
        switch self {
        case .noRepository: .pushUnavailableNoRepository
        case .detachedHead: .pushUnavailableDetachedHead
        case .unbornBranch: .pushUnavailableUnbornBranch
        case .noRemote: .pushUnavailableNoRemote
        case .pushInProgress: .pushUnavailablePushInProgress
        case .mutationInProgress: .pushUnavailableMutationInProgress
        }
    }
}
