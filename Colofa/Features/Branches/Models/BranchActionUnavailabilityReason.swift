////
//  BranchActionUnavailabilityReason.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// Why New Branch or Checkout cannot run right now, so a disabled control explains itself instead
/// of letting Git refuse the command afterwards.
///
/// A Checkout that would overwrite local work is deliberately absent: that one is Git's answer,
/// not a state Colofa can read off a snapshot, and it is reported as a refusal after Git gives it.
nonisolated enum BranchActionUnavailabilityReason: Equatable, Sendable {
    case noRepository
    /// An Unborn Branch names no Commit, so there is nothing for a branch to start at.
    case unbornBranch
    case alreadyCheckedOut
    case operationInProgress
    case conflict
    case mutationInProgress

    /// Why New Branch cannot run, or `nil` when it may.
    static func evaluateCreation(
        repository: RepositorySnapshot?,
        isMutating: Bool
    ) -> Self? {
        guard let repository else {
            return .noRepository
        }
        if case .unbornBranch = repository.head {
            return .unbornBranch
        }
        return isMutating ? .mutationInProgress : nil
    }

    /// Why a Checkout of `target` cannot run, or `nil` when it may.
    ///
    /// Git refuses to switch during a Merge, Rebase, or Revert and while a path is still
    /// unmerged. Both are states the user has to leave first, so both are said before the command
    /// rather than after it.
    static func evaluateCheckout(
        target: CheckoutTarget?,
        repository: RepositorySnapshot?,
        isMutating: Bool
    ) -> Self? {
        guard let repository else {
            return .noRepository
        }
        guard let target else {
            return .alreadyCheckedOut
        }
        if case .branch(let current) = repository.head, current == target.localBranchName {
            return .alreadyCheckedOut
        }
        if repository.operation != nil {
            return .operationInProgress
        }
        if repository.unstagedChanges.contains(where: \.isConflict) {
            return .conflict
        }
        return isMutating ? .mutationInProgress : nil
    }

    var message: LocalizedStringResource {
        switch self {
        case .noRepository: .branchActionUnavailableNoRepository
        case .unbornBranch: .branchActionUnavailableUnbornBranch
        case .alreadyCheckedOut: .branchActionUnavailableAlreadyCheckedOut
        case .operationInProgress: .branchActionUnavailableOperationInProgress
        case .conflict: .branchActionUnavailableConflict
        case .mutationInProgress: .branchActionUnavailableMutationInProgress
        }
    }
}
