////
//  WorkspaceState+Commit.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

/// Creating a Commit from exactly the Staged Changes, and rewriting HEAD through Amend.
///
/// Commit and Push stay separate commands: nothing here contacts a remote.
extension WorkspaceState {
    var commitUnavailabilityReason: CommitUnavailabilityReason? {
        CommitUnavailabilityReason.evaluate(
            repository: repository,
            hasSummary: commitDraft.hasSummary,
            isAmending: commitDraft.isAmending,
            isMutating: !canMutateRepository
        )
    }

    var canCommit: Bool {
        commitUnavailabilityReason == nil
    }

    /// Amend needs a commit to rewrite, so it stays unavailable on an Unborn Branch.
    var canAmend: Bool {
        guard canMutateRepository,
              let repository,
              repository.headCommit != nil,
              repository.operation == nil else {
            return false
        }
        if case .detached = repository.head {
            return false
        }
        return true
    }

    var isAmendingPublishedCommit: Bool {
        commitDraft.isAmending && repository?.headCommit?.isPublished == true
    }

    /// True while the Amend in progress would rewrite HEAD's message formatting, which the
    /// composer says out loud rather than leaving the user to discover afterwards.
    var amendReformatsMessage: Bool {
        commitDraft.isAmending && repository?.headCommit?.amendReformatsMessage == true
    }

    func setAmending(_ isAmending: Bool) {
        if isAmending {
            guard let headCommit = repository?.headCommit, canAmend else {
                return
            }
            commitDraft.beginAmending(with: headCommit)
        } else {
            commitDraft.endAmending()
            isConfirmingHistoryRewrite = false
        }
    }

    /// Runs the Commit, or asks for confirmation first when it would rewrite published history.
    func commit() async {
        guard canCommit else {
            return
        }
        guard !isAmendingPublishedCommit else {
            isConfirmingHistoryRewrite = true
            return
        }
        await executeCommit()
    }

    /// Runs the Amend the user confirmed in the history-rewrite warning.
    ///
    /// The presentation flag is deliberately not part of the guard: SwiftUI clears it while
    /// dismissing the dialog, before the confirming button's action runs. What is checked instead
    /// is that this is still the published Amend the warning described.
    func confirmHistoryRewrite() async {
        isConfirmingHistoryRewrite = false
        guard canCommit, isAmendingPublishedCommit else {
            return
        }
        await executeCommit()
    }

    func cancelHistoryRewrite() {
        isConfirmingHistoryRewrite = false
    }

    /// Drops an Amend draft whose Commit is no longer the one HEAD points at, and says so: the
    /// message was prefilled from a Commit that has since been replaced, so amending now would
    /// rewrite a different one.
    ///
    /// Not private: WorkspaceState.swift runs this after every reload that is not Colofa's own
    /// HEAD rewrite, and after a command that failed with HEAD moved anyway.
    func reconcileAmendDraft() {
        guard commitDraft.isAmending,
              commitDraft.amendedCommitObjectID != repository?.headCommit?.objectID else {
            return
        }
        commitDraft.endAmending()
        isConfirmingHistoryRewrite = false
        isShowingStaleAmendAlert = true
    }

    private func executeCommit() async {
        let isAmending = commitDraft.isAmending
        // No --no-verify and no signing override: configured hooks and commit.gpgsign decide what
        // happens, and `--file=-` keeps the message out of the argument list that failure details
        // echo back.
        let succeeded = await performMutation(
            isAmending ? ["commit", "--amend", "--file=-"] : ["commit", "--file=-"],
            standardInput: commitDraft.message,
            rewritesHead: isAmending,
            failureTitle: isAmending ? .amendCommitFailed : .commitFailed
        )
        guard succeeded else {
            return
        }
        commitDraft.clear()
    }
}
