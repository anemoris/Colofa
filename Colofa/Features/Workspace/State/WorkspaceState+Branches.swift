////
//  WorkspaceState+Branches.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation

/// Creating a local Branch at an explicit start point, and moving HEAD to a Ref on purpose.
///
/// Nothing here offers Force Checkout, Smart Checkout, or an automatic Stash: a Checkout Git
/// refuses stays refused, and the refusal names the work it protected.
extension WorkspaceState {
    // MARK: - New Branch

    var isCreatingBranch: Bool {
        get { branchCreation != nil }
        set {
            if !newValue {
                branchCreation = nil
            }
        }
    }

    var branchCreationUnavailabilityReason: BranchActionUnavailabilityReason? {
        BranchActionUnavailabilityReason.evaluateCreation(
            repository: repository,
            isMutating: !canMutateRepository
        )
    }

    var canBeginCreatingBranch: Bool {
        branchCreationUnavailabilityReason == nil
    }

    /// Opens the dialog on the Commit HEAD points at, which is what the toolbar's New Branch
    /// starts from.
    func beginCreatingBranch() {
        guard let repository, canBeginCreatingBranch,
              let startPoint = BranchStartPoint.head(of: repository) else {
            return
        }
        branchCreation = BranchCreationDraft(startPoint: startPoint)
    }

    /// Opens the same dialog on one selected Commit, which is what Create Branch Here starts from.
    func beginCreatingBranch(at commit: HistoryCommit) {
        guard canBeginCreatingBranch else {
            return
        }
        branchCreation = BranchCreationDraft(startPoint: .commit(commit))
    }

    func cancelBranchCreation() {
        branchCreation = nil
    }

    var branchNameValidation: BranchNameValidation {
        guard let branchCreation else {
            return .empty
        }
        return BranchNameValidation.evaluate(
            name: branchCreation.name,
            existingLocalBranches: repository?.localBranches ?? [],
            isFormatValid: branchCreation.formatValidity
        )
    }

    var canCreateBranch: Bool {
        branchNameValidation.allowsCreation && canMutateRepository && branchCreation != nil
    }

    /// What the dialog re-asks Git about: a different name, in a different Repository, is a
    /// different question.
    var branchNameValidationIdentity: BranchNameValidationRequest? {
        guard let repository, let name = branchCreation?.name else {
            return nil
        }
        return BranchNameValidationRequest(repositoryURL: repository.rootURL, name: name)
    }

    /// Asks real Git whether it would accept the name currently typed.
    ///
    /// The short wait first is what keeps one process per keystroke from being launched: the
    /// view's task is replaced on every edit, so only the name the user stopped on is asked about.
    ///
    /// A Git that could not be asked is reported as itself. Answering "invalid name" for it would
    /// leave Create disabled with the user editing a name that was never the problem.
    func validateBranchName() async {
        guard let request = branchNameValidationIdentity, !request.name.isEmpty else {
            return
        }
        do {
            try await Task.sleep(for: .milliseconds(150))
        } catch {
            return
        }
        do {
            let isValid = try await repositoryService.validateBranchName(request)
            guard branchCreation?.name == request.name else {
                return
            }
            branchCreation?.recordFormatCheck(of: request.name, isValid: isValid)
        } catch is CancellationError {
            // The name moved on while Git was being asked; the replacing task owns the answer.
            return
        } catch {
            guard branchCreation?.name == request.name else {
                return
            }
            branchCreation?.recordFailure(.nameCheckFailed(failureDetails(of: error)))
        }
    }

    /// Creates the branch, and checks it out when the dialog asked for that.
    ///
    /// A failure keeps the dialog open with its reason beside the name that caused it, because
    /// the name is what the user has to change.
    func createBranch() async {
        guard let draft = branchCreation, canCreateBranch else {
            return
        }
        branchCreation?.clearFailure()
        let outcome = await runMutation(draft.arguments)
        switch outcome {
        case .succeeded:
            branchCreation = nil
        case .unavailable:
            return
        case .failed(let error):
            await reportBranchCreationFailure(error, of: draft)
        }
    }

    // MARK: - Checkout

    /// The Ref the sidebar has selected, which is what the Branch menu's Checkout acts on.
    var selectedReference: GitReference? {
        guard case .reference(let reference) = storedSidebarSelection else {
            return nil
        }
        return reference
    }

    var canCheckoutSelectedReference: Bool {
        guard let selectedReference else {
            return false
        }
        return canCheckout(selectedReference)
    }

    func checkoutSelectedReference() async {
        guard let selectedReference else {
            return
        }
        await checkout(selectedReference)
    }

    /// The command `reference` would run, or `nil` for HEAD, which is already checked out.
    func checkoutTarget(for reference: GitReference) -> CheckoutTarget? {
        guard let repository else {
            return nil
        }
        return CheckoutTarget.resolve(reference, in: repository)
    }

    func checkoutUnavailabilityReason(
        for reference: GitReference
    ) -> BranchActionUnavailabilityReason? {
        BranchActionUnavailabilityReason.evaluateCheckout(
            target: checkoutTarget(for: reference),
            repository: repository,
            isMutating: !canMutateRepository
        )
    }

    func canCheckout(_ reference: GitReference) -> Bool {
        checkoutUnavailabilityReason(for: reference) == nil
    }

    /// Moves HEAD to `reference`, carrying whatever local changes Git allows it to carry.
    ///
    /// Git decides: the command is the plain one, so a Checkout it accepts brings compatible
    /// Staged and unstaged changes along, and a Checkout it refuses changes nothing at all.
    func checkout(_ reference: GitReference) async {
        guard let target = checkoutTarget(for: reference), canCheckout(reference) else {
            return
        }
        let outcome = await runMutation(target.arguments)
        guard case .failed(let error) = outcome else {
            return
        }
        if let obstruction = await obstruction(blocking: target.revision) {
            presentFailure(
                .checkoutRefusedAlert(
                    obstruction,
                    reference: target.displayName,
                    error: error
                )
            )
        } else {
            presentFailure(.mutationAlert(error, title: .checkoutFailed))
        }
    }

    /// The local work a move to `revision` would have overwritten, or `nil` when there is none.
    ///
    /// Asked only after Git has already refused, so it explains a refusal rather than deciding
    /// one. The comparison is Git's own name-status walk, not text scraped from Git's message.
    ///
    /// A comparison that itself fails is deliberately discarded rather than raised. The refusal
    /// the user needs to see is Git's, and the caller still shows it in full — this walk only
    /// adds the paths it protected. Reporting the failure of an explanation in place of the
    /// thing being explained would replace a real answer with a worse one.
    private func obstruction(blocking revision: String) async -> CheckoutObstruction? {
        guard let repository,
              let comparison = try? await repositoryService.loadCheckoutComparison(
                  CheckoutComparisonRequest(
                      repositoryURL: repository.rootURL,
                      revision: revision,
                      hasHeadCommit: repository.headCommit != nil
                  )
              ) else {
            return nil
        }
        let obstruction = CheckoutObstruction.evaluate(comparison: comparison, in: repository)
        return obstruction.isEmpty ? nil : obstruction
    }

    /// Explains a New Branch that failed, inside the dialog that is still open.
    ///
    /// A dialog that asked for Checkout can fail the same way any Checkout does, so the same
    /// refusal is reported — with the paths it protected — rather than only Git's exit status.
    private func reportBranchCreationFailure(
        _ error: RepositoryOpenError,
        of draft: BranchCreationDraft
    ) async {
        guard branchCreation?.startPoint == draft.startPoint else {
            return
        }
        if draft.checksOutNewBranch,
           let obstruction = await obstruction(blocking: draft.startPoint.revision) {
            branchCreation?.recordFailure(.checkoutBlocked(obstruction))
            return
        }
        branchCreation?.recordFailure(.commandFailed(failureDetails(of: error)))
    }

    /// Git's own sanitized words when it produced any, and Colofa's description of the error
    /// when Git never got far enough to write one.
    private func failureDetails(of error: any Error) -> GitFailureDetails {
        guard let error = error as? RepositoryOpenError else {
            return GitFailureDetails(command: "git", output: error.localizedDescription)
        }
        return error.failureDetails
            ?? GitFailureDetails(command: "git", output: String(localized: error.message))
    }
}
