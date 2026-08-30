////
//  WorkspaceState+PushDestination.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// The one thing a remote name cannot establish: the address a Push actually writes to.
///
/// Git resolves a remote name when the command runs, out of configuration no upstream spells out.
/// So the address is read before a confirmation opens, shown in it, and read once more immediately
/// before the command runs — which is as close to the write as Colofa can get without giving up
/// pushing by name, and pushing by name is what keeps Git updating the remote-tracking Ref
/// afterwards.
///
/// Pushing to the captured address instead would not close that window either, which is why it is
/// not done. `url.<base>.pushInsteadOf` rewrites an address given on the command line exactly as
/// it rewrites one resolved from a remote name, so configuration edited in the same window still
/// redirects the write. What it would cost is real: a Push to a URL creates no remote-tracking
/// Ref, and `--set-upstream` against one records the raw path as `branch.<name>.remote`, which
/// leaves `@{upstream}` unresolvable and ahead/behind unanswerable. Everything Colofa would then
/// have to write by hand is what pushing by name already gets right.
extension WorkspaceState {

    /// Where a Push to `remote` would land.
    ///
    /// - Throws: `PushDestinationRefusal` for a remote that resolves to this Repository or to more
    ///   than one address, neither of which one confirmation can describe.
    func pushDestination(
        of remote: String,
        in repository: RepositorySnapshot
    ) async throws -> PushDestination {
        try await repositoryService.loadPushDestination(
            PushDestinationRequest(repositoryURL: repository.rootURL, remote: remote)
        )
    }

    /// Whether the remote still resolves to the address the confirmation captured.
    ///
    /// A refusal closes the dialog and explains itself, because what it showed has stopped being
    /// true — the same reason a stale dialog is dismissed rather than quietly updated.
    ///
    /// Not private: `confirmPush` in WorkspaceState+Push.swift asks it immediately before running
    /// the command, and Swift keeps `private` within one file.
    func confirmsDestination(
        of confirmation: PushConfirmation,
        in repository: RepositorySnapshot
    ) async -> Bool {
        let generation = repositoryGeneration
        do {
            let destination = try await pushDestination(
                of: confirmation.target.remote,
                in: repository
            )
            guard destination == confirmation.destination else {
                throw PushDestinationRefusal.changed(remote: confirmation.target.remote)
            }
        } catch {
            pushDialog = nil
            presentDestinationFailure(error, title: .pushFailed)
            return false
        }
        // Re-checked after the read, which suspends: the confirmation may have been reloaded out
        // from under this, and the box may have been ticked while Git was answering.
        return canPush && isCurrent(generation) && pushDialog?.confirmation == confirmation
    }

    /// Reports a destination Colofa refused to push to, and anything else as the read failure it
    /// was.
    ///
    /// A refusal is not a command that failed: nothing ran, and what has to be said is which
    /// configuration made the destination unconfirmable. Git wrote nothing about it, so the alert
    /// offers no output to expand.
    ///
    /// Not private: both Publish and Push report their own reads with it, and Swift keeps
    /// `private` within one file.
    func presentDestinationFailure(
        _ error: any Error,
        title: LocalizedStringResource
    ) {
        guard let refusal = error as? PushDestinationRefusal else {
            presentMutationError(pushError(error), title: title)
            return
        }
        presentFailure(.pushDestinationAlert(refusal))
    }
}
