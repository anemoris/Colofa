////
//  StashCreationUnavailabilityReason.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// Why a Stash cannot be created right now, so a disabled control explains itself instead of
/// letting Git refuse the command afterwards.
///
/// The clean case matters more here than elsewhere: `git stash push` with nothing to save writes
/// "No local changes to save" and exits *successfully*, having created nothing. A button that ran
/// it would report a Stash that does not exist, so the state is refused before the command runs.
nonisolated enum StashCreationUnavailabilityReason: Equatable, Sendable {
    case noRepository

    /// An Unborn Branch has no Commit for a Stash to be saved against.
    case unbornBranch

    case operationInProgress

    /// Git refuses to save an index that holds unmerged paths.
    case conflict

    /// Nothing to save at all.
    case noLocalChanges

    /// The only changes are to submodules, which `git stash push` never counts as something to
    /// save — it would answer "No local changes to save" and exit successfully having saved
    /// nothing, while the Repository still lists the submodule as changed.
    case submoduleChangesOnly

    /// The only work in the Repository is untracked, and Include Untracked Files is off — so the
    /// options as they stand would save nothing.
    case untrackedOnly

    case mutationInProgress

    /// Why a Stash cannot be created, or `nil` when it can.
    ///
    /// - Parameter includesUntrackedFiles: What the options would save. The control that *opens*
    ///   the sheet asks with `true`, because the sheet is where that option is chosen; the sheet's
    ///   own Stash button asks with whatever the user has set.
    static func evaluate(
        repository: RepositorySnapshot?,
        includesUntrackedFiles: Bool,
        isMutating: Bool
    ) -> Self? {
        guard let repository else {
            return .noRepository
        }
        if case .unbornBranch = repository.head {
            return .unbornBranch
        }
        if repository.operation != nil {
            return .operationInProgress
        }
        if repository.unstagedChanges.contains(where: \.isConflict) {
            return .conflict
        }
        if !hasTrackedChanges(in: repository) {
            guard hasUntrackedChanges(in: repository) else {
                return hasSubmoduleChanges(in: repository) ? .submoduleChangesOnly : .noLocalChanges
            }
            guard includesUntrackedFiles else {
                return .untrackedOnly
            }
        }
        return isMutating ? .mutationInProgress : nil
    }

    /// Whether the Repository holds work Git would save without being asked for untracked files:
    /// anything Staged, and any unstaged change to a path Git already tracks.
    ///
    /// A submodule counts on neither side. Git decides whether there is anything to save while
    /// ignoring submodules entirely, so a submodule change is only saved alongside other work.
    private static func hasTrackedChanges(in repository: RepositorySnapshot) -> Bool {
        repository.stagedChanges.contains { !$0.isSubmodule }
            || repository.unstagedChanges.contains {
                !$0.isUntracked && !$0.isConflict && !$0.isSubmodule
            }
    }

    private static func hasSubmoduleChanges(in repository: RepositorySnapshot) -> Bool {
        repository.stagedChanges.contains(where: \.isSubmodule)
            || repository.unstagedChanges.contains(where: \.isSubmodule)
    }

    private static func hasUntrackedChanges(in repository: RepositorySnapshot) -> Bool {
        repository.unstagedChanges.contains(where: \.isUntracked)
    }

    var message: LocalizedStringResource {
        switch self {
        case .noRepository: .stashUnavailableNoRepository
        case .unbornBranch: .stashUnavailableUnbornBranch
        case .operationInProgress: .stashUnavailableOperationInProgress
        case .conflict: .stashUnavailableConflict
        case .noLocalChanges: .stashUnavailableNoLocalChanges
        case .submoduleChangesOnly: .stashUnavailableSubmoduleChangesOnly
        case .untrackedOnly: .stashUnavailableUntrackedOnly
        case .mutationInProgress: .stashUnavailableMutationInProgress
        }
    }
}
