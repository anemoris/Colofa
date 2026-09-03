////
//  BranchActionUnavailabilityReason.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// Why New Branch, Checkout, or Delete Branch cannot run right now, so a disabled control
/// explains itself instead of letting Git refuse the command afterwards.
///
/// A Checkout that would overwrite local work is deliberately absent: that one is Git's answer,
/// not a state Colofa can read off a snapshot, and it is reported as a refusal after Git gives it.
nonisolated enum BranchActionUnavailabilityReason: Equatable, Sendable {
    case noRepository
    /// An Unborn Branch names no Commit, so there is nothing for a branch to start at.
    case unbornBranch
    case alreadyCheckedOut
    /// HEAD is on this Branch, and Git has no valid state in which the Branch a working tree is
    /// on stops existing.
    case currentBranch
    /// Delete Branch removes a local branch and nothing else, so a tag, a Remote-tracking
    /// Branch, and a Detached HEAD are all Refs it has nothing to act on.
    case notLocalBranch
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

    /// Why Delete Branch cannot run against `branch`, or `nil` when it may.
    ///
    /// The current Branch is refused here rather than by Git, because a disabled control that
    /// says why is a better answer than a command that fails. Everything else a Delete can run
    /// into — a Branch checked out in another worktree, History nothing else holds — stays Git's
    /// answer, given after Git gives it.
    static func evaluateDeletion(
        branch: String?,
        repository: RepositorySnapshot?,
        isMutating: Bool
    ) -> Self? {
        guard let repository else {
            return .noRepository
        }
        guard let branch, repository.localBranches.contains(branch) else {
            return .notLocalBranch
        }
        if case .branch(let current) = repository.head, current == branch {
            return .currentBranch
        }
        return isMutating ? .mutationInProgress : nil
    }

    var message: LocalizedStringResource {
        switch self {
        case .noRepository: .branchActionUnavailableNoRepository
        case .unbornBranch: .branchActionUnavailableUnbornBranch
        case .alreadyCheckedOut: .branchActionUnavailableAlreadyCheckedOut
        case .currentBranch: .branchActionUnavailableCurrentBranch
        case .notLocalBranch: .branchActionUnavailableNotLocalBranch
        case .operationInProgress: .branchActionUnavailableOperationInProgress
        case .conflict: .branchActionUnavailableConflict
        case .mutationInProgress: .branchActionUnavailableMutationInProgress
        }
    }
}
