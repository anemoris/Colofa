////
//  WorkspaceState+Merge.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation

/// Merging one Branch into the current one, under a policy the user chose.
///
/// Nothing here is a Smart Merge. Tracked local work is refused before the command runs rather
/// than stashed around it, an untracked file Git says is in the way stops the Merge and is named,
/// and the three policies are exactly Git's own. Nothing squashes, skips the Commit, skips a
/// Hook, or allows unrelated histories.
extension WorkspaceState {
    // MARK: - Availability

    /// Whether a Merge confirmation is on screen. Dismissing it by any route — Cancel, Escape, or
    /// clicking away — is the same as cancelling it, because nothing has run yet.
    var isMerging: Bool {
        get { mergeDraft != nil }
        set {
            if !newValue {
                cancelMerge()
            }
        }
    }

    /// The Branch `reference` would bring in, or `nil` for a Ref Merge has nothing to act on.
    ///
    /// A tag answers `nil`, which is what keeps Merge out of its menu entirely: an action disabled
    /// on every tag would be an action that never applies.
    ///
    /// HEAD is resolved to the Branch it is on instead, the same way Delete Branch resolves it.
    /// The sidebar gives the current Branch no row of its own — it is the HEAD row — so leaving
    /// HEAD unresolved would take Merge off the one Branch a user is most likely to try it on, and
    /// the refusal that names it the current Branch could never be shown. Merging it into itself
    /// is still refused; it is refused where the user can read why.
    func mergeSource(of reference: GitReference) -> MergeSource? {
        guard case .head = reference else {
            return MergeSource.resolve(reference)
        }
        // A Detached HEAD and an Unborn Branch name no Branch, so there is nothing to offer.
        guard case .branch(let name) = repository?.head else {
            return nil
        }
        return MergeSource.resolve(.localBranch(name))
    }

    func mergeUnavailabilityReason(
        for reference: GitReference
    ) -> MergeUnavailabilityReason? {
        MergeUnavailabilityReason.evaluate(
            source: mergeSource(of: reference),
            repository: repository,
            isMutating: !canMutateRepository
        )
    }

    func canMerge(_ reference: GitReference) -> Bool {
        mergeUnavailabilityReason(for: reference) == nil
    }

    /// Whether the Branch menu's Merge may act on the sidebar's selected Ref.
    var canMergeSelectedReference: Bool {
        guard let selectedReference else {
            return false
        }
        return canMerge(selectedReference)
    }

    // MARK: - Confirmation

    /// Opens the confirmation for `reference`, naming both ends of the merge.
    ///
    /// Both names are read here rather than inside the dialog, so what the user agrees to is the
    /// direction that was true when they asked — and a Repository read again underneath the sheet
    /// cannot quietly turn it into a different merge.
    func beginMerging(_ reference: GitReference) {
        guard let repository,
              let source = mergeSource(of: reference),
              let target = Self.mergeTargetName(of: repository.head),
              canMerge(reference) else {
            return
        }
        mergeDraft = MergeDraft(source: source, target: target)
    }

    func beginMergingSelectedReference() {
        guard let selectedReference else {
            return
        }
        beginMerging(selectedReference)
    }

    /// Drops the pending Merge without running anything, which is what Cancel does. Nothing has
    /// touched Git by this point.
    func cancelMerge() {
        mergeDraft = nil
    }

    var canConfirmMerge: Bool {
        mergeDraft != nil && canMutateRepository
    }

    /// Runs the Merge the user confirmed.
    ///
    /// A Merge that ends in Conflict closes the dialog without an alert: nothing failed, and the
    /// Repository is now the state the user works in. The banner and the conflicted paths at the
    /// top of Changes are what say so, and an alert over them would cover the only list that
    /// matters.
    func confirmMerge() async {
        guard let draft = mergeDraft, canConfirmMerge else {
            return
        }
        switch await runMerge(draft) {
        case .merged, .conflicted:
            mergeDraft = nil
        case .unavailable:
            // Nothing ran, so the confirmation stays for the user to press again.
            return
        case .failed(let error):
            mergeDraft = nil
            presentFailure(await mergeFailure(error, of: draft.source))
        }
    }

    // MARK: - Running one Merge

    /// Runs the command and reads what the Repository became, which is the only thing that can
    /// tell a Conflict apart from a failure: Git ends both with a non-zero status.
    private func runMerge(_ draft: MergeDraft) async -> MergeOutcome {
        switch await runMutation(draft.arguments) {
        case .succeeded:
            return .merged
        case .unavailable:
            return .unavailable
        case .failed(let error):
            return repository?.operation == .merge ? .conflicted : .failed(error)
        }
    }

    /// Works out what to say about a Merge Git refused.
    ///
    /// The one refusal Colofa can add to is an untracked file standing where the merge would have
    /// written: Git names none of them in a form worth parsing, so the paths come from Git's own
    /// name-status walk instead.
    private func mergeFailure(
        _ error: RepositoryOpenError,
        of source: MergeSource
    ) async -> RepositoryFailurePresentation {
        guard let collision = await mergeCollision(bringingIn: source) else {
            return .mutationAlert(error, title: .mergeFailed)
        }
        return .mergeBlockedAlert(collision, error: error)
    }

    /// The untracked files the Merge would have written over, or `nil` when there are none.
    ///
    /// Asked only after Git has already refused, so it explains a refusal rather than deciding
    /// one. A walk that itself fails is deliberately discarded rather than raised: the refusal the
    /// user needs to see is Git's, and the caller still shows it in full.
    private func mergeCollision(bringingIn source: MergeSource) async -> MergeCollision? {
        guard let repository,
              let comparison = try? await repositoryService.loadCheckoutComparison(
                  CheckoutComparisonRequest(
                      repositoryURL: repository.rootURL,
                      revision: source.revision,
                      hasHeadCommit: repository.headCommit != nil
                  )
              ) else {
            return nil
        }
        let collision = MergeCollision.evaluate(comparison: comparison, in: repository)
        return collision.isEmpty ? nil : collision
    }

    /// What a merge lands on, which the confirmation names as the target.
    ///
    /// A Detached HEAD is a valid target and is named by its Commit; an Unborn Branch is not one
    /// at all, and answering `nil` for it is what keeps a Merge from opening on it.
    private static func mergeTargetName(of head: RepositoryHead) -> String? {
        switch head {
        case .branch(let name): name
        case .detached(let objectID): String(objectID.prefix(12))
        case .unbornBranch: nil
        }
    }
}
