////
//  CommitUnavailabilityReason.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// Why Commit or Amend cannot run right now, so the composer can explain a disabled button
/// instead of letting Git refuse the command afterwards.
enum CommitUnavailabilityReason: Equatable, Sendable {
    case noRepository
    case detachedHead
    case operationInProgress
    case conflict
    case noStagedChanges
    case nothingToAmend
    case missingIdentity
    case emptySummary
    case mutationInProgress

    /// The first reason that applies, or `nil` when the command may run.
    ///
    /// Ordered by how the user has to fix it: Repository states that no composer input can
    /// resolve come first, then the index, then identity, then the message. Identity follows the
    /// staged check deliberately — a Repository the user has not staged anything in should not
    /// open by demanding an identity. `mutationInProgress` is last so a transient in-flight
    /// command never replaces a standing explanation with a flicker.
    static func evaluate(
        repository: RepositorySnapshot?,
        hasSummary: Bool,
        isAmending: Bool,
        isMutating: Bool
    ) -> Self? {
        guard let repository else {
            return .noRepository
        }
        if case .detached = repository.head {
            return .detachedHead
        }
        if repository.operation != nil {
            return .operationInProgress
        }
        if repository.unstagedChanges.contains(where: \.isConflict) {
            return .conflict
        }
        if isAmending {
            if repository.headCommit == nil {
                return .nothingToAmend
            }
        } else if repository.stagedChanges.isEmpty {
            return .noStagedChanges
        }
        if !repository.configuration.hasEffectiveIdentity {
            return .missingIdentity
        }
        if !hasSummary {
            return .emptySummary
        }
        if isMutating {
            return .mutationInProgress
        }
        return nil
    }

    /// True for a reason that resolves on its own, which the composer states in the button's help
    /// rather than printing below it — a running command would otherwise flash an explanation
    /// through the layout on the way to the real one.
    var isTransient: Bool {
        self == .mutationInProgress
    }

    var message: LocalizedStringResource {
        switch self {
        case .noRepository:
            .commitUnavailableNoRepository
        case .detachedHead:
            .commitUnavailableDetachedHead
        case .operationInProgress:
            .commitUnavailableOperationInProgress
        case .conflict:
            .commitUnavailableConflict
        case .noStagedChanges:
            .commitUnavailableNoStagedChanges
        case .nothingToAmend:
            .commitUnavailableNothingToAmend
        case .missingIdentity:
            .commitUnavailableMissingIdentity
        case .emptySummary:
            .commitUnavailableEmptySummary
        case .mutationInProgress:
            .commitUnavailableMutationInProgress
        }
    }
}
