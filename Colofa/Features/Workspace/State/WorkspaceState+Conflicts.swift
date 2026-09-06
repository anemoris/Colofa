////
//  WorkspaceState+Conflicts.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation

/// Resolving the unmerged paths an operation left, and finishing or rolling back the operation
/// itself.
///
/// Nothing here decides a Conflict. Colofa restores one of the two versions the user names, opens
/// the file where the user can edit it line by line, and stages what the file then holds; which
/// of those to do is always the user's choice. There is no Smart Merge and no built-in three-way
/// editor.
extension WorkspaceState {
    // MARK: - The Conflict

    /// The unmerged paths, which the Repository already reports before everything else.
    var conflictedChanges: [RepositoryChange] {
        repository?.unstagedChanges.filter(\.isConflict) ?? []
    }

    var hasUnresolvedConflicts: Bool {
        repository?.unstagedChanges.contains(where: \.isConflict) ?? false
    }

    /// The real name one version is offered under, or `nil` when the Repository cannot name it.
    ///
    /// Never "ours" or "theirs". The current side is the Branch the working tree is on, or the
    /// Commit a Detached HEAD sits at; the incoming side is whatever Git's own `MERGE_HEAD` points
    /// at, which is a Branch when one still does and the Commit itself otherwise.
    func conflictVersionLabel(_ version: ConflictVersion) -> String? {
        guard let repository else {
            return nil
        }
        switch version {
        case .current:
            return switch repository.head {
            case .branch(let name): name
            case .detached(let objectID): String(objectID.prefix(12))
            case .unbornBranch: nil
            }
        case .incoming:
            return repository.mergeHead?.label
        }
    }

    func canChooseConflictVersion(_ version: ConflictVersion, for change: RepositoryChange) -> Bool {
        conflictVersionLabel(version) != nil && canResolveConflict(at: change)
    }

    /// Restores the path to one complete version, in the working tree only.
    ///
    /// The path stays unmerged afterwards, exactly as Git leaves it: choosing a side is the user
    /// saying which content they want, and Mark as Resolved is the separate step that tells Git
    /// the Conflict is over. Keeping them apart is what makes resolving one always explicit.
    func chooseConflictVersion(_ version: ConflictVersion, for change: RepositoryChange) async {
        guard canChooseConflictVersion(version, for: change) else {
            return
        }
        await performMutation(
            version.arguments(for: change),
            failureTitle: .conflictVersionFailed
        )
    }

    func canMarkResolved(_ change: RepositoryChange) -> Bool {
        canResolveConflict(at: change)
    }

    /// Stages whatever the file holds right now.
    ///
    /// It merges nothing and checks nothing: Git stops reporting the path as unmerged because the
    /// content on disk has been recorded, and whether that content is a correct resolution is the
    /// user's judgment. That is why the action is named for what it does to the index rather than
    /// for a merge it did not perform.
    func markResolved(_ change: RepositoryChange) async {
        guard canMarkResolved(change) else {
            return
        }
        await performMutation(
            MergeCommand.markingResolved(change.gitPathspecs),
            failureTitle: .markResolvedFailed
        )
    }

    /// Opens the conflicted file in whichever app the system opens that kind of file with, which
    /// is where a line-level resolution is made.
    ///
    /// Colofa has no three-way editor, and the conflict markers Git wrote into the file are what
    /// an ordinary text editor already shows. The file system is asked at invocation rather than
    /// predicted: a path can disappear between the read that listed it and the click that opens it.
    func openInDefaultEditor(_ change: RepositoryChange) async {
        guard let url = fileURL(for: change) else {
            return
        }
        guard await fileSystem.open(url) else {
            // The Repository listed a path nothing can open, so it is read again before the
            // explanation goes up: the list the user is looking at was part of what was wrong.
            await refresh()
            presentFailure(.fileActionAlert(.openFailed(path: change.path)))
            return
        }
    }

    private func canResolveConflict(at change: RepositoryChange) -> Bool {
        canMutateRepository
            && change.isConflict
            && repository?.unstagedChanges.contains(change) == true
    }

    // MARK: - Finishing the operation

    /// Whether an unfinished Merge is what the Repository is in the middle of, which is the one
    /// operation these controls act on. A Rebase, a Revert, a cherry-pick, and an `am` have their
    /// own recovery commands and are deliberately left read-only here.
    var isMergeUnfinished: Bool {
        repository?.operation == .merge
    }

    /// Continue is unavailable while any path is still unmerged, because Git would refuse it and
    /// because an operation must not be finished over a Conflict nobody decided.
    var canContinueMerge: Bool {
        isMergeUnfinished && !hasUnresolvedConflicts && canMutateRepository
    }

    /// Completes the merge with the message Git already prepared for it. `MergeCommand.completing`
    /// carries why that is a Commit rather than `git merge --continue`.
    func continueMerge() async {
        guard canContinueMerge else {
            return
        }
        await performMutation(MergeCommand.completing, failureTitle: .continueMergeFailed)
    }

    var canAbortMerge: Bool {
        isMergeUnfinished && canMutateRepository
    }

    /// Rolls the merge back with Git's own merge rollback, which restores the Branch, the index,
    /// and the working tree to what they were before the Merge started.
    func abortMerge() async {
        guard canAbortMerge else {
            return
        }
        await performMutation(MergeCommand.abort, failureTitle: .abortMergeFailed)
    }
}
