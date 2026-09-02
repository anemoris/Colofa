////
//  WorkspaceState+FileActions.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// The actions a changed path offers besides staging it: removing its content, and working with
/// the file itself outside Colofa.
///
/// The two destructive ones are deliberately not one action. Git can restore a tracked path
/// because it already holds the staged version; nothing holds an untracked file, so removing one
/// goes to the Trash instead. One control covering both would have to be named for neither.
extension WorkspaceState {
    // MARK: - Availability

    /// Whether this path can have its unstaged content restored to the staged version.
    ///
    /// Only an unstaged, tracked, non-conflicted row: a Staged Change is unstaged rather than
    /// discarded, an untracked file has no staged version to restore, and choosing a side of a
    /// Conflict is always explicit rather than something a generic Discard decides.
    func canDiscardChanges(_ change: RepositoryChange, isStaged: Bool) -> Bool {
        guard !isStaged, !change.isConflict, !change.isUntracked else {
            return false
        }
        return canMutateRepository && repository?.unstagedChanges.contains(change) == true
    }

    /// Whether this path can be moved to the macOS Trash, which only an untracked one can.
    func canMoveToTrash(_ change: RepositoryChange, isStaged: Bool) -> Bool {
        guard !isStaged, change.isUntracked else {
            return false
        }
        return canMutateRepository && repository?.unstagedChanges.contains(change) == true
    }

    /// Where the changed path is, or would be, on disk.
    ///
    /// A deleted path still has one: what is gone is the file, not the location, and both Reveal
    /// in Finder and Copy Path are asked about the location.
    func fileURL(for change: RepositoryChange) -> URL? {
        repository?.rootURL.appending(path: change.path)
    }

    // MARK: - Confirmation

    /// Whether a destructive confirmation is on screen. Both actions are bound through the one
    /// pending slot, so only one of them can ever be up, and dismissing it by any route — Cancel,
    /// Escape, or clicking away — is the same as cancelling it.
    var isConfirmingFileAction: Bool {
        get { pendingFileAction != nil }
        set {
            if !newValue {
                cancelFileAction()
            }
        }
    }

    func beginDiscardingChanges(_ change: RepositoryChange) {
        guard canDiscardChanges(change, isStaged: false) else {
            return
        }
        pendingFileAction = .discardChanges(change)
    }

    func beginMovingToTrash(_ change: RepositoryChange) {
        guard canMoveToTrash(change, isStaged: false) else {
            return
        }
        pendingFileAction = .moveToTrash(change)
    }

    /// Drops the pending action without running anything, which is what Cancel does. Nothing has
    /// touched Git or the file system by this point, so there is nothing to roll back.
    func cancelFileAction() {
        pendingFileAction = nil
    }

    /// Runs the destructive action the user confirmed.
    ///
    /// The action is handed in rather than read back out of `pendingFileAction`, because by the
    /// time the confirming button's action runs the pending slot is already empty: SwiftUI clears
    /// a dialog's presentation binding while dismissing it, before that action runs — the same
    /// ordering `confirmHistoryRewrite()` is written around. The dialog's `presenting:` payload is
    /// what survives the dismissal, so it is the only thing that can say what was confirmed.
    ///
    /// What the action may still do is checked again against the Repository as it is now rather
    /// than as it was when the dialog opened.
    func confirmFileAction(_ action: DestructiveFileAction) async {
        pendingFileAction = nil
        switch action {
        case .discardChanges(let change):
            await discardChanges(change)
        case .moveToTrash(let change):
            await moveToTrash(change)
        }
    }

    /// Keeps the pending action pointing at a Change the Repository still reports.
    ///
    /// A confirmation outliving the Change it names has nothing left to do: the content it would
    /// have discarded is already gone, and a path that stopped being untracked must not be
    /// trashed by a dialog that was opened when it still was. It closes rather than acting on
    /// something the user never saw.
    ///
    /// Not private: `publishRepository` calls it as each authoritative read lands.
    func reconcileFileAction(against repository: RepositorySnapshot) {
        guard let pendingFileAction else {
            return
        }
        guard !repository.unstagedChanges.contains(pendingFileAction.change) else {
            return
        }
        self.pendingFileAction = nil
    }

    // MARK: - Working with the file outside Colofa

    /// Selects the changed path in Finder, or explains that it is no longer there.
    ///
    /// The file system is asked at invocation rather than predicted from the Change's kind: a
    /// path can disappear between the read that listed it and the click that reveals it, and a
    /// staged deletion whose file was written again is still there.
    func revealInFinder(_ change: RepositoryChange) async {
        guard let url = fileURL(for: change) else {
            return
        }
        guard await fileSystem.reveal(url) else {
            // The Repository listed a path that is no longer on disk, so it is read again before
            // the explanation goes up: the list the user is looking at was part of what was wrong.
            await refresh()
            presentFailure(.fileActionAlert(.revealMissing(path: change.path)))
            return
        }
    }

    /// Copies the changed path's absolute location, which is what another tool needs.
    ///
    /// It copies the location whether or not a file is there. A deleted or trashed path is still
    /// the path the user asked for — it is what a `git restore` or a search is written against —
    /// so this reports no failure for one, unlike Reveal in Finder, which has nothing to show.
    func copyPath(_ change: RepositoryChange) {
        guard let url = fileURL(for: change) else {
            return
        }
        pasteboard.write(url.normalizedFilePath)
    }

    // MARK: - Running the destructive actions

    /// Restores only the working tree from the index, never the index from HEAD. `--worktree` is
    /// explicit rather than left to Git's default so that what this cannot touch — the Staged
    /// Changes the user already chose — is visible in the command itself.
    private func discardChanges(_ change: RepositoryChange) async {
        guard canDiscardChanges(change, isStaged: false) else {
            return
        }
        await performMutation(
            ["--literal-pathspecs", "restore", "--worktree", "--"] + change.gitPathspecs,
            failureTitle: .discardChangesFailed
        )
    }

    /// Moves an untracked file to the macOS Trash.
    ///
    /// It holds the Repository the way a mutating Git command does even though no Git command
    /// runs: it changes the working tree, and a command landing in the middle of it would read a
    /// tree that is being written. The Repository is read again either way, because a failure
    /// here is also the moment to find out the path had already moved.
    private func moveToTrash(_ change: RepositoryChange) async {
        // Keep the removal and authoritative reload alive if the initiating view task is cancelled.
        await Task {
            guard let url = fileURL(for: change),
                  canMoveToTrash(change, isStaged: false) else {
                return
            }
            isPerformingMutation = true
            defer { isPerformingMutation = false }

            var failure: FileActionFailure?
            do {
                try await fileSystem.moveToTrash(url)
            } catch let error as CocoaError where error.code == .userCancelled {
                failure = .trashCancelled(path: change.path)
            } catch {
                failure = .trashFailed(path: change.path, reason: error.localizedDescription)
            }

            await refresh()
            if let failure {
                // After the reload, which clears whatever failure was on screen before it.
                presentFailure(.fileActionAlert(failure))
            }
        }.value
    }
}
