////
//  WorkspaceState+Push.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// Putting the current Branch on a remote: creating it there the first time, and sending it to
/// its upstream every time after.
///
/// Nothing here happens on its own. A Branch nobody has pushed yet goes where Git's own
/// configuration says, or where the user names; a Branch with an upstream goes exactly where a
/// confirmation showed it going. And history is replaced only by a Force Push with Lease the user
/// ticked on purpose, which carries the exact object the remote must still hold — there is no
/// argument anywhere in this path that spells a naked force.
extension WorkspaceState {

    // MARK: - Availability

    var isPushing: Bool {
        pushProgress != nil
    }

    var pushUnavailabilityReason: PushUnavailabilityReason? {
        PushUnavailabilityReason.evaluate(
            repository: repository,
            isMutating: !canMutateRepository,
            isPushing: isPushing
        )
    }

    var canPush: Bool {
        pushUnavailabilityReason == nil
    }

    /// Whether the current Branch has no upstream, which is what turns Push into Publish.
    ///
    /// It answers for the Branch the Repository is actually on. Detached HEAD has no Branch at
    /// all, and offering to publish one would be offering to publish nothing.
    var isCurrentBranchUnpublished: Bool {
        guard let repository, case .branch = repository.head else {
            return false
        }
        return repository.upstream == nil
    }

    /// How many Commits the current Branch has that its upstream does not, or `nil` when there is
    /// no number to show.
    ///
    /// `DESIGN.md` §「关键 IA 决策」⑤ puts this count on the button that acts on it rather than
    /// across the window in the status bar: the button is the disposition of the number.
    ///
    /// `nil` covers three different situations that all render as no badge. Zero is one of them —
    /// `↑0` is noise beside a button that already says what it does. The other two are Git
    /// declining to count at all: an upstream ref that is gone, and an Unborn Branch with no
    /// Commit to count from. `RepositoryUpstream.ahead` already answers `nil` for both, so this
    /// only has to drop the zero.
    var pushAheadCount: Int? {
        guard let ahead = repository?.upstream?.ahead, ahead > 0 else {
            return nil
        }
        return ahead
    }

    /// Everything a Push does happens out at the remote, so the way out stays offered for as long
    /// as it is out there. What is left afterwards is Colofa's own reload, which is a local read
    /// and not something to interrupt.
    var canCancelPush: Bool {
        pushTask != nil
    }

    // MARK: - Starting one

    /// Publishes the current Branch or opens the confirmation that pushes it, depending on whether
    /// it has an upstream yet.
    func beginPush() async {
        guard let repository, case .branch(let branch) = repository.head, canPush else {
            return
        }
        // The Repository state every answer below is about. A read suspends, and what comes back
        // describes the Repository as it was when the question was asked; opening a dialog on a
        // Repository that has been read again since would be showing the user one state and
        // acting on another.
        let generation = repositoryGeneration
        let request = PushTargetRequest(repositoryURL: repository.rootURL, branch: branch)
        guard repository.upstream != nil else {
            await beginPublish(request, in: repository, at: generation)
            return
        }

        let target: PushTarget?
        do {
            target = try await repositoryService.loadPushTarget(request)
        } catch {
            presentMutationError(pushError(error), title: .pushFailed)
            return
        }
        // Re-checked after the read: the Repository may have been reloaded, or a command may have
        // taken it, while Git was answering.
        guard canPush, isCurrent(generation) else {
            return
        }
        // Git reports no upstream after all, so the snapshot's was configuration that has since
        // gone. Publishing is what resolves that, and it never sends anything without first
        // saying — or asking — where it is going.
        guard let target else {
            await beginPublish(request, in: repository, at: generation)
            return
        }
        // Where the remote actually points, asked before the confirmation opens. The upstream
        // names a remote, and only Git can say what address that name resolves to — which is the
        // one fact a confirmation about writing to somebody else's copy has to establish.
        let destination: PushDestination
        do {
            destination = try await pushDestination(of: target.remote, in: repository)
        } catch {
            presentDestinationFailure(error, title: .pushFailed)
            return
        }
        guard canPush, isCurrent(generation) else {
            return
        }
        pushDialog = .confirmation(
            PushConfirmation(
                branch: branch,
                target: target,
                destination: destination,
                localObjectID: repository.headCommit?.objectID
            )
        )
    }

    /// Works out where a Branch nobody has pushed yet should go, and asks only when nothing else
    /// can answer.
    ///
    /// Git's own configuration is honored first, so a Repository that already says where this
    /// Branch belongs is never asked to repeat itself. A single remote is the answer rather than a
    /// question. Only several remotes and no configuration is genuinely ambiguous, and that is the
    /// one case that opens a dialog.
    private func beginPublish(
        _ request: PushTargetRequest,
        in repository: RepositorySnapshot,
        at generation: Int
    ) async {
        let configured: String?
        do {
            configured = try await repositoryService.loadPublishRemote(request)
        } catch {
            presentMutationError(pushError(error), title: .publishFailed)
            return
        }
        guard canPush, isCurrent(generation) else {
            return
        }

        let remotes = repository.remotes.map(\.name)
        if let remote = configured ?? (remotes.count == 1 ? remotes.first : nil) {
            await publish(request.branch, to: remote, in: repository)
            return
        }
        pushDialog = PublishRemoteSelection(branch: request.branch, remotes: remotes)
            .map(PushDialog.publishRemote)
    }

    /// Sends the Branch exactly where the open confirmation said it was going, forcing only when
    /// its own checkbox is ticked.
    func confirmPush() async {
        // Checked here as well as on every reload, because the press and the reload are not
        // ordered with respect to each other: what a Force Push installs at the upstream must be
        // the history the box was ticked against, not whatever the Branch has drifted to since.
        guard let repository else {
            return
        }
        reconcilePushDialog(against: repository)
        guard case .confirmation(let confirmation) = pushDialog, canPush else {
            return
        }
        // Asked once more, immediately before the command runs. A remote's address is
        // configuration, and configuration can be edited — by the user, or by another process —
        // while a dialog is open. This cannot be atomic with Git's own resolution, but it reduces
        // the window from however long the dialog was up to the length of one read.
        guard await confirmsDestination(of: confirmation, in: repository) else {
            return
        }
        pushDialog = nil
        await runPush(
            PushRun(
                arguments: confirmation.arguments,
                progress: PushProgress(
                    target: confirmation.target.upstream,
                    work: confirmation.work
                ),
                branch: confirmation.branch,
                upstream: confirmation.target.upstream,
                failureTitle: .pushFailed
            ),
            in: repository
        )
    }

    /// Publishes to the remote the dialog has selected. Nothing here happens on its own: this runs
    /// because the dialog's own button was pressed.
    func confirmPublishRemote() async {
        guard let repository else {
            return
        }
        reconcilePushDialog(against: repository)
        guard case .publishRemote(let selection) = pushDialog, canPush else {
            return
        }
        pushDialog = nil
        await publish(selection.branch, to: selection.selectedRemote, in: repository)
    }

    // MARK: - Running one

    private func publish(
        _ branch: String,
        to remote: String,
        in repository: RepositorySnapshot
    ) async {
        // The same question Push asks, for the same reason: a Publish writes to a remote too, and
        // a remote resolving to this Repository or to several addresses at once is a destination
        // no confirmation — and no automatic choice — can describe honestly.
        let generation = repositoryGeneration
        do {
            _ = try await pushDestination(of: remote, in: repository)
        } catch {
            presentDestinationFailure(error, title: .publishFailed)
            return
        }
        guard canPush, isCurrent(generation) else {
            return
        }
        await runPush(
            PushRun(
                arguments: PushCommand.publish(branch, to: remote),
                progress: PushProgress(target: remote, work: .publishing),
                branch: branch,
                // The upstream this would create, named the way Git names one. It is display text
                // for a refusal rather than anything a command is routed by; every command above
                // is routed by the remote and Ref Git itself reported.
                upstream: "\(remote)/\(branch)",
                failureTitle: .publishFailed
            ),
            in: repository
        )
    }

    /// Runs one command that contacts a remote, then reloads Repository state whatever it did.
    ///
    /// The reload is unconditional on purpose. A Push that failed partway and a Push the user
    /// stopped both leave the remote and its tracking Ref exactly as far along as Git got, and
    /// only a real read can say where that is. Nothing here records a last-Fetch time: a Push
    /// downloads nothing, and dating the Repository from one would date what is on screen against
    /// work that never arrived.
    private func runPush(_ run: PushRun, in repository: RepositorySnapshot) async {
        // Claimed before anything suspends, so a second press cannot start a second Push while the
        // first one is still on its way to the first `await`.
        pushProgress = run.progress
        // Assigned in the same step, so a Cancel pressed the moment the Push appears on screen
        // still reaches the task it is offered for.
        let task = Task { [self] in
            await performPush(run.arguments, in: repository)
        }
        pushTask = task

        // Kept alive past the initiating view task: a Push is stopped by Cancel, not by a view
        // going away, and the reload that follows it has to happen either way.
        await Task { [self] in
            let outcome = await task.value
            pushTask = nil

            await refresh()
            if let failure = pushFailure(outcome, of: run) {
                presentFailure(failure)
            }
            // Released only once the reload and the explanation are done: until then the Push is
            // still the command holding the Repository.
            pushProgress = nil
        }.value
    }

    /// Stops the running Push. What the remote already accepted stays accepted, and the reload
    /// that follows reports exactly how far it got.
    func cancelPush() {
        guard canCancelPush else {
            return
        }
        pushTask?.cancel()
    }

    private func performPush(
        _ arguments: [String],
        in repository: RepositorySnapshot
    ) async -> PushOutcome {
        do {
            try await repositoryService.runNetworkMutation(
                arguments,
                repository.rootURL,
                authenticationResponder
            )
            return .succeeded
        } catch is CancellationError {
            return .cancelled
        } catch {
            return .failed(pushError(error))
        }
    }

    // MARK: - Reporting

    /// Works out what to say about a Push that failed.
    ///
    /// The three answers are deliberately kept apart, because the user does something different
    /// about each. A connection that was never trusted or never authenticated never reached the
    /// remote's decision at all. A remote that refused the update is telling the user to integrate
    /// first, and Git says which refusal it was in the one part of its answer written for a
    /// machine. Everything else is a transport that failed, and only Git's own words explain it.
    private func pushFailure(
        _ outcome: PushOutcome,
        of run: PushRun
    ) -> RepositoryFailurePresentation? {
        guard let error = outcome.error, let details = error.failureDetails else {
            return outcome.error.map { .mutationAlert($0, title: run.failureTitle) }
        }
        if let failure = details.authenticationFailure
            ?? AuthenticationFailure.detect(in: details.output) {
            return .authenticationAlert(failure, error: error)
        }
        guard let rejection = PushRejection.detect(in: details.output) else {
            return .mutationAlert(error, title: run.failureTitle)
        }
        return .pushRejectedAlert(
            rejection,
            branch: run.branch,
            upstream: run.upstream,
            error: error
        )
    }

    /// Whether the Repository state a read was started against is still the one on screen, which
    /// is what a read that suspended has to establish before acting on its answer.
    ///
    /// The generation rather than the path: a reload of the same Repository replaces the Branch,
    /// the upstream and the objects a Push would be about just as completely as opening a
    /// different one does, and a path comparison cannot see it.
    ///
    /// Not private: the destination check in WorkspaceState+PushDestination.swift asks the same
    /// question after its own read, and Swift keeps `private` within one file.
    func isCurrent(_ generation: Int) -> Bool {
        repositoryGeneration == generation
    }

    /// Git's own sanitized failure when Git produced one, and Colofa's description of the error
    /// when Git never got far enough to write one.
    ///
    /// Not private: the destination reader in WorkspaceState+PushDestination.swift reports its own
    /// read failures with it, and Swift keeps `private` within one file.
    func pushError(_ error: any Error) -> RepositoryOpenError {
        guard let error = error as? RepositoryOpenError else {
            return .commandFailed(
                GitFailureDetails(command: "git push", output: error.localizedDescription)
            )
        }
        return error
    }
}

/// One Publish or Push about to run: what leaves for the remote, and everything a refusal would
/// have to be able to say about it.
///
/// Declared alongside rather than nested, because the Store is one type and this is a detail of
/// how its Push runs rather than part of its published state.
private struct PushRun {
    let arguments: [String]
    let progress: PushProgress
    let branch: String

    /// The upstream a refusal names, which for a Publish is the one it was about to create.
    let upstream: String

    let failureTitle: LocalizedStringResource
}
