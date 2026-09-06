////
//  MergeUnavailabilityReason.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// Why Merge cannot run right now, so a disabled control explains itself instead of letting Git
/// refuse the command afterwards.
///
/// A path collision is deliberately absent: whether an untracked file stands where the merge
/// would write is Git's answer, not something a snapshot can decide, and it is reported as a
/// refusal after Git gives it.
nonisolated enum MergeUnavailabilityReason: Equatable, Sendable {
    case noRepository
    /// An Unborn Branch names no Commit, so there is nothing to merge into.
    case unbornBranch
    /// Merge brings in a Branch. A tag and HEAD are Refs it has nothing to act on.
    case notBranch
    /// The Branch HEAD is already on, which would merge a Branch into itself.
    case currentBranch
    case operationInProgress
    case conflict
    /// Tracked work Git would have to carry through the merge. Colofa neither stashes it nor
    /// merges around it, so the refusal says which of the two the user can do.
    case localChanges
    case mutationInProgress

    /// Why merging `source` cannot run, or `nil` when it may.
    ///
    /// Untracked files are deliberately not counted as local changes. Work Git has never recorded
    /// is unrelated to what a merge writes unless it lands on the same path, and refusing every
    /// merge because a scratch file exists would refuse the ordinary case.
    static func evaluate(
        source: MergeSource?,
        repository: RepositorySnapshot?,
        isMutating: Bool
    ) -> Self? {
        guard let repository else {
            return .noRepository
        }
        guard let source else {
            return .notBranch
        }
        if case .unbornBranch = repository.head {
            return .unbornBranch
        }
        // Only a local Branch can be the one HEAD is on. A Remote-tracking Branch is compared
        // against nothing here, so a local branch that happens to be named `origin/main` does not
        // stop `origin/main` itself from being merged.
        if case .branch(let current) = repository.head, !source.isRemote, current == source.name {
            return .currentBranch
        }
        if repository.operation != nil {
            return .operationInProgress
        }
        if repository.unstagedChanges.contains(where: \.isConflict) {
            return .conflict
        }
        if hasTrackedChanges(in: repository) {
            return .localChanges
        }
        return isMutating ? .mutationInProgress : nil
    }

    /// Whether the Repository holds work a merge would have to carry: anything Staged, and any
    /// unstaged change to a path Git already tracks.
    private static func hasTrackedChanges(in repository: RepositorySnapshot) -> Bool {
        !repository.stagedChanges.isEmpty
            || repository.unstagedChanges.contains { !$0.isUntracked && !$0.isConflict }
    }

    var message: LocalizedStringResource {
        switch self {
        case .noRepository: .mergeUnavailableNoRepository
        case .unbornBranch: .mergeUnavailableUnbornBranch
        case .notBranch: .mergeUnavailableNotBranch
        case .currentBranch: .mergeUnavailableCurrentBranch
        case .operationInProgress: .mergeUnavailableOperationInProgress
        case .conflict: .mergeUnavailableConflict
        case .localChanges: .mergeUnavailableLocalChanges
        case .mutationInProgress: .mergeUnavailableMutationInProgress
        }
    }
}
