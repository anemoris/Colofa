////
//  WorkspaceState+BranchDeletion.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation

/// Removing one local Branch, with Git's merged-history protection kept in front of it.
///
/// Delete Branch is local and stays local. It runs `git branch --delete`, which writes under
/// `refs/heads/` and nowhere else, so a Remote-tracking Branch, an upstream, and whatever the
/// remote itself holds are all left exactly as they were. Nothing here contacts a remote, and
/// nothing here offers to delete one.
extension WorkspaceState {
    // MARK: - Availability

    /// Whether a Delete Branch confirmation is on screen. Dismissing it by any route — Cancel,
    /// Escape, or clicking away — is the same as cancelling it, because nothing has run yet.
    var isDeletingBranch: Bool {
        get { branchDeletion != nil }
        set {
            if !newValue {
                cancelBranchDeletion()
            }
        }
    }

    /// The local branch `reference` names, or `nil` for a Ref that is not one.
    ///
    /// HEAD resolves to the branch it is on rather than to nothing, so the sidebar's current-Branch
    /// row still offers Delete Branch — disabled, saying why. A row that hid the action entirely
    /// would leave the user looking for it.
    func deletableBranchName(of reference: GitReference) -> String? {
        switch reference {
        case .head:
            if case .branch(let name) = repository?.head {
                name
            } else {
                nil
            }
        case .localBranch(let name):
            name
        case .remoteBranch, .tag:
            nil
        }
    }

    func branchDeletionUnavailabilityReason(
        for reference: GitReference
    ) -> BranchActionUnavailabilityReason? {
        BranchActionUnavailabilityReason.evaluateDeletion(
            branch: deletableBranchName(of: reference),
            repository: repository,
            isMutating: !canMutateRepository
        )
    }

    func canDeleteBranch(_ reference: GitReference) -> Bool {
        branchDeletionUnavailabilityReason(for: reference) == nil
    }

    /// Whether the Branch menu's Delete Branch may act on the sidebar's selected Ref.
    var canDeleteSelectedBranch: Bool {
        guard let selectedReference else {
            return false
        }
        return canDeleteBranch(selectedReference)
    }

    func beginDeletingSelectedBranch() async {
        guard let selectedReference else {
            return
        }
        await beginDeletingBranch(selectedReference)
    }

    // MARK: - Confirmation

    /// Opens the confirmation for `reference`, having first asked Git what removing it would cost.
    ///
    /// The question is asked before the dialog rather than inside it, because the answer decides
    /// what the dialog is: a Branch holding Commits no other Ref holds opens straight into the
    /// confirmation that requires Force Delete, with the exact count in front of the checkbox.
    /// Opening a plain confirmation first and turning it into that one afterwards would ask the
    /// user to agree to something before saying what it costs.
    func beginDeletingBranch(_ reference: GitReference) async {
        guard let repository,
              let branch = deletableBranchName(of: reference),
              canDeleteBranch(reference) else {
            return
        }
        do {
            guard let survey = try await surveyDeletion(of: branch, in: repository) else {
                // Git no longer has the Branch, so there is nothing to confirm and the list the
                // user clicked in was part of what was wrong.
                await refresh()
                return
            }
            branchDeletion = BranchDeletion(branch: branch, survey: survey)
        } catch {
            presentMutationError(deletionError(of: error), title: .deleteBranchCheckFailed)
        }
    }

    /// Drops the pending Delete without running anything, which is what Cancel does. Nothing has
    /// touched Git by this point, so the Branch is exactly as it was.
    func cancelBranchDeletion() {
        branchDeletion = nil
    }

    var canConfirmBranchDeletion: Bool {
        branchDeletion?.canDelete == true && canMutateRepository
    }

    /// Removes the Branch the user confirmed.
    ///
    /// What Git said when the dialog opened is asked again first. A Ref that moved since is no
    /// longer the Ref the confirmation described — its tip is a different Commit, or the History
    /// only it holds is no longer the amount that was agreed to — so it is refused rather than
    /// deleted under an assumption that stopped being true.
    ///
    /// A refusal keeps the dialog open with Git's own words in it and Force Delete now required,
    /// because the Branch is what the user has to decide about and an alert would take it away
    /// to say so.
    func confirmBranchDeletion() async {
        guard let repository, let deletion = branchDeletion, canConfirmBranchDeletion else {
            return
        }
        branchDeletion?.clearFailure()

        let survey: BranchDeletionSurvey?
        do {
            survey = try await surveyDeletion(of: deletion.branch, in: repository)
        } catch {
            guard branchDeletion?.branch == deletion.branch else {
                return
            }
            branchDeletion?.recordSurveyFailure(
                deletionFailureDetails(of: deletionError(of: error))
            )
            return
        }
        // The confirmation can have been replaced while Git was being asked — a Repository the
        // user opened in the meantime brings its own branches — and a dialog that is no longer
        // this one owns whatever it says about itself.
        guard branchDeletion?.branch == deletion.branch else {
            return
        }
        guard survey == deletion.survey else {
            branchDeletion = nil
            isShowingStaleBranchDeletionAlert = true
            await refresh()
            return
        }

        // The mutation reloads refs and History whichever way it ends, so a Delete that
        // succeeded and one Git refused both leave the window describing the Repository as it is.
        switch await runMutation(deletion.arguments) {
        case .succeeded:
            branchDeletion = nil
        case .unavailable:
            // Nothing ran, so the confirmation stays for the user to press again.
            return
        case .failed(let error):
            guard branchDeletion?.branch == deletion.branch else {
                return
            }
            branchDeletion?.recordRefusal(deletionFailureDetails(of: error))
        }
    }

    /// Closes a confirmation whose Branch the Repository has stopped reporting, and says so.
    ///
    /// A dialog outlives the reload that happens under it — the window becoming active is enough
    /// to cause one — so a Branch that somebody else removed in the meantime must not leave a
    /// confirmation standing over nothing. The alert exists because a sheet that vanishes on its
    /// own is otherwise indistinguishable from one the user dismissed by accident.
    ///
    /// A mutation of Colofa's own is deliberately exempt: the Delete that just succeeded is the
    /// reason the Branch is gone, and reporting Colofa's own success as somebody else's surprise
    /// would be a lie.
    ///
    /// Not private: `publishRepository` in WorkspaceState.swift calls it as each authoritative
    /// read lands, and Swift keeps `private` within one file.
    func reconcileBranchDeletion(against repository: RepositorySnapshot) {
        guard let branchDeletion, !isPerformingMutation,
              !repository.localBranches.contains(branchDeletion.branch) else {
            return
        }
        self.branchDeletion = nil
        isShowingStaleBranchDeletionAlert = true
    }

    // MARK: - Asking Git

    private func surveyDeletion(
        of branch: String,
        in repository: RepositorySnapshot
    ) async throws -> BranchDeletionSurvey? {
        try await repositoryService.loadBranchDeletionSurvey(
            BranchDeletionRequest(repositoryURL: repository.rootURL, name: branch)
        )
    }

    /// Git's own error when it gave one, and Colofa's description of the failure when the read
    /// never got far enough for Git to write one.
    private func deletionError(of error: any Error) -> RepositoryOpenError {
        error as? RepositoryOpenError
            ?? .commandFailed(
                GitFailureDetails(command: "git", output: error.localizedDescription)
            )
    }

    private func deletionFailureDetails(of error: RepositoryOpenError) -> GitFailureDetails {
        error.failureDetails
            ?? GitFailureDetails(command: "git", output: String(localized: error.message))
    }
}
