////
//  WorkspaceState+Pull.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation

/// Updating the current Branch from its upstream, and only ever by fast-forward.
///
/// Nothing here chooses an integration method. A Pull that cannot fast-forward stops and says so;
/// Merge and Rebase are separate commands the user runs on purpose, and no Pull turns into one of
/// them, creates a merge commit, rewrites a local Commit, or stashes the working tree on the way.
extension WorkspaceState {

    // MARK: - Availability

    var isPulling: Bool {
        pullProgress != nil
    }

    var pullUnavailabilityReason: PullUnavailabilityReason? {
        PullUnavailabilityReason.evaluate(
            repository: repository,
            isMutating: !canMutateRepository,
            isPulling: isPulling
        )
    }

    var canPull: Bool {
        pullUnavailabilityReason == nil
    }

    /// Whether the running Pull is still in the half that can be stopped.
    ///
    /// Only the Fetch contacts the remote; the fast-forward that follows is a short local command,
    /// and offering to interrupt one halfway would be offering something Colofa will not do.
    var canCancelPull: Bool {
        pullTask != nil && pullProgress?.isCancellable == true
    }

    // MARK: - Pull

    /// Fetches the current Branch's upstream and advances the Branch to it, or explains why it
    /// could not.
    func pull() async {
        guard let repository, let upstream = repository.upstream, canPull else {
            return
        }
        // Claimed before anything suspends, so a second press cannot start a second Pull while
        // the first one is still on its way to the first `await`.
        pullProgress = PullProgress(upstream: upstream.name, phase: .contactingRemote)
        // Assigned in the same step, so a Cancel arriving before the Pull's first `await` still
        // reaches the task it is offered for.
        let task = Task { [self] in
            await performPull(from: upstream.name, in: repository)
        }
        pullTask = task

        // Kept alive past the initiating view task: a Pull is stopped by Cancel, not by a view
        // going away, and the reload that follows it has to happen either way.
        await Task { [self] in
            let outcome = await task.value
            pullTask = nil

            if outcome.reachedRemote {
                recordFetch(at: .now)
            }
            // Unconditional on purpose. A Pull that fetched and then refused to advance the
            // Branch has still moved remote-tracking refs, and only a real read can say how far;
            // reporting the state Colofa expected instead would be reporting a Repository that
            // does not exist.
            await refresh()
            if outcome.needsReporting, let failure = await pullFailure(outcome) {
                presentFailure(failure)
            }
            // Released only once the reload and the explanation are done: until then the Pull is
            // still the command holding the Repository.
            pullProgress = nil
        }.value
    }

    /// Stops the running Pull. What Git already wrote stays written, and the reload that follows
    /// reports exactly how far it got.
    func cancelPull() {
        guard canCancelPull else {
            return
        }
        pullTask?.cancel()
    }

    // MARK: - Running one Pull

    /// Runs the two halves of one Pull in order, stopping at whichever of them ends it.
    private func performPull(
        from upstream: String,
        in repository: RepositorySnapshot
    ) async -> PullOutcome {
        do {
            try await repositoryService.runNetworkMutation(
                PullCommand.fetch,
                repository.rootURL,
                authenticationResponder
            )
        } catch is CancellationError {
            return .cancelled
        } catch {
            return .fetchFailed(pullError(error))
        }

        // A Cancel that lands between the halves stops the Pull here rather than starting a
        // command that could not then be stopped.
        guard !Task.isCancelled else {
            return .cancelled
        }
        pullProgress = PullProgress(upstream: upstream, phase: .integrating)

        do {
            try await repositoryService.runMutation(
                PullCommand.fastForward,
                nil,
                repository.rootURL
            )
            return .fastForwarded
        } catch {
            return .integrationRefused(pullError(error))
        }
    }

    // MARK: - Reporting

    /// Works out what to say about a Pull that failed, from the Repository as it is now.
    ///
    /// The order is the order of what the user has to act on. A connection that was never trusted
    /// or never authenticated explains a Pull better than anything about its Branch does, and it
    /// is the one answer that means the remote was never reached at all.
    private func pullFailure(
        _ outcome: PullOutcome
    ) async -> RepositoryFailurePresentation? {
        guard let error = outcome.error else {
            return nil
        }
        if let details = error.failureDetails,
           let failure = details.authenticationFailure
               ?? AuthenticationFailure.detect(in: details.output) {
            return .authenticationAlert(failure, error: error)
        }
        guard case .integrationRefused = outcome, let repository else {
            return .mutationAlert(error, title: .pullFailed)
        }
        if let divergence = PullDivergence.evaluate(in: repository) {
            return .pullDivergedAlert(divergence, error: error)
        }
        if let obstruction = await pullObstruction(in: repository) {
            return .pullBlockedAlert(obstruction, error: error)
        }
        return .mutationAlert(error, title: .pullFailed)
    }

    /// The local work advancing the Branch would have overwritten, or `nil` when there is none.
    ///
    /// Asked only after Git has already refused, so it explains a refusal rather than deciding
    /// one. The comparison is Git's own name-status walk against the upstream it just fetched,
    /// not text scraped from a translated message.
    ///
    /// A comparison that itself fails is deliberately discarded rather than raised: the refusal
    /// the user needs to see is Git's, and the caller still shows it in full — this walk only
    /// adds the paths it protected.
    private func pullObstruction(
        in repository: RepositorySnapshot
    ) async -> CheckoutObstruction? {
        guard let comparison = try? await repositoryService.loadCheckoutComparison(
            CheckoutComparisonRequest(
                repositoryURL: repository.rootURL,
                revision: PullCommand.upstreamRevision,
                hasHeadCommit: repository.headCommit != nil
            )
        ) else {
            return nil
        }
        let obstruction = CheckoutObstruction.evaluate(comparison: comparison, in: repository)
        return obstruction.isEmpty ? nil : obstruction
    }

    /// Git's own sanitized failure when Git produced one, and Colofa's description of the error
    /// when Git never got far enough to write one.
    private func pullError(_ error: any Error) -> RepositoryOpenError {
        guard let error = error as? RepositoryOpenError else {
            return .commandFailed(
                GitFailureDetails(command: "git pull", output: error.localizedDescription)
            )
        }
        return error
    }
}
