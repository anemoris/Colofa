////
//  PullUnavailabilityReason.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// Why Pull cannot run right now, so a disabled control explains itself instead of letting Git
/// refuse the command afterwards.
///
/// Divergence and a working tree the update would overwrite are deliberately absent. Both are
/// answers only the remote can give — the counts a snapshot carries were true as of the last
/// Fetch — so both are reported as refusals after Git gives them rather than as a disabled
/// button. An Unborn Branch is absent for the opposite reason: it is exactly the state a Pull
/// resolves, and Git fast-forwards it like any other.
nonisolated enum PullUnavailabilityReason: Equatable, Sendable {
    case noRepository
    /// Detached HEAD is on no Branch, so there is no Branch for an upstream to belong to.
    case detachedHead
    case noUpstream
    case operationInProgress
    case conflict
    case pullInProgress
    case mutationInProgress

    /// Why a Pull cannot start, or `nil` when it may.
    ///
    /// Ordered by what the user has to do about it: the states no command can resolve come
    /// first, then the ones another command is holding. `mutationInProgress` is last so a
    /// transient in-flight command never replaces a standing explanation with a flicker.
    static func evaluate(
        repository: RepositorySnapshot?,
        isMutating: Bool,
        isPulling: Bool
    ) -> Self? {
        guard let repository else {
            return .noRepository
        }
        if case .detached = repository.head {
            return .detachedHead
        }
        // Matched rather than compared to `nil`: a snapshot's own members are MainActor-isolated
        // by default, and `==` would reach for a conformance this nonisolated type cannot use.
        if case .none = repository.upstream {
            return .noUpstream
        }
        if case .some = repository.operation {
            return .operationInProgress
        }
        if repository.unstagedChanges.contains(where: \.isConflict) {
            return .conflict
        }
        if isPulling {
            return .pullInProgress
        }
        return isMutating ? .mutationInProgress : nil
    }

    var message: LocalizedStringResource {
        switch self {
        case .noRepository: .pullUnavailableNoRepository
        case .detachedHead: .pullUnavailableDetachedHead
        case .noUpstream: .pullUnavailableNoUpstream
        case .operationInProgress: .pullUnavailableOperationInProgress
        case .conflict: .pullUnavailableConflict
        case .pullInProgress: .pullUnavailablePullInProgress
        case .mutationInProgress: .pullUnavailableMutationInProgress
        }
    }
}
