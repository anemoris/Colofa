////
//  WorkspaceState+Fetch.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation

/// Manually refreshing remote-tracking refs, explicitly reconciling them with what the remotes
/// still hold, and explicitly downloading one remote's tags.
///
/// Every command here is one the user pressed. Colofa has no periodic Fetch, no Fetch when the
/// window becomes active, and no Fetch hidden inside another operation: contacting a remote is
/// always something the user asked for, and always something the user can stop.
extension WorkspaceState {

    // MARK: - Availability

    var isFetching: Bool {
        fetchProgress != nil
    }

    var fetchUnavailabilityReason: FetchUnavailabilityReason? {
        FetchUnavailabilityReason.evaluate(
            repository: repository,
            isMutating: !canMutateRepository,
            isFetching: isFetching
        )
    }

    var canFetch: Bool {
        fetchUnavailabilityReason == nil
    }

    /// Fetch Tags contacts a remote exactly the way Fetch does, so the same things stand in its
    /// way: no Repository, no remote to ask, or a command already holding this one.
    var canFetchTags: Bool {
        canFetch
    }

    /// Fetch Remotes contacts a remote exactly the way Fetch does, so the same things stand in
    /// its way, and they are reported in the same words.
    var canFetchRemotes: Bool {
        canFetch
    }

    /// Whether the running Fetch is still the part of itself that can be stopped.
    ///
    /// Everything a Fetch takes out to a remote lives inside its task, including the second read
    /// that explains a refused Fetch Tags. The reload that follows is Colofa's own read of a
    /// Repository Git has finished writing, and offering to interrupt that would be offering
    /// something Colofa will not do.
    var canCancelFetch: Bool {
        fetchTask != nil
    }

    // MARK: - Fetch

    /// Refreshes every remote Git's own configuration lets a Fetch of all remotes contact.
    func fetch() async {
        guard let repository, canFetch else {
            return
        }
        await runFetch(.everyRemote, in: repository)
    }

    /// Stops the running Fetch. What Git already wrote stays written, and the reload that follows
    /// reports exactly how far it got.
    func cancelFetch() {
        guard canCancelFetch else {
            return
        }
        fetchTask?.cancel()
    }

    // MARK: - Fetch Remotes

    /// Downloads every eligible remote's branches and removes the remote-tracking Branches those
    /// remotes no longer have.
    ///
    /// Separate from Fetch rather than folded into it. The toolbar's Fetch adds no option and
    /// lets each remote's own configuration decide what happens, which is a decision recorded in
    /// ADR 0004; this is the explicit action that overrules it, and it sits in the Remotes
    /// section it reconciles for the same reason Fetch Tags sits in the Tags section.
    ///
    /// It walks the same remotes a Fetch of every remote does, including the ones Git's
    /// `remote.<name>.skipFetchAll` excludes: a remote Git leaves out of a Fetch of all of them
    /// is not one Colofa should contact behind Git's back.
    func fetchRemotes() async {
        guard let repository, canFetchRemotes else {
            return
        }
        await runFetch(.remotes, in: repository)
    }

    // MARK: - Fetch Tags

    /// Downloads every tag from one remote.
    ///
    /// A Repository with a single remote has no question to ask, so it is fetched directly.
    /// Several remotes open the dialog instead: tag names are shared across remotes, and pulling
    /// them from whichever remote Colofa guessed is not something to do on the user's behalf.
    func fetchTags() async {
        guard let repository, canFetchTags else {
            return
        }
        let remotes = repository.remotes.map(\.name)
        guard remotes.count > 1 else {
            guard let remote = remotes.first else {
                return
            }
            await runFetch(.tags(from: remote), in: repository)
            return
        }
        tagFetchSelection = TagFetchSelection(remotes: remotes)
    }

    var isChoosingTagFetchRemote: Bool {
        get { tagFetchSelection != nil }
        set {
            if !newValue {
                tagFetchSelection = nil
            }
        }
    }

    func cancelTagFetch() {
        tagFetchSelection = nil
    }

    /// Fetches the tags of the remote the dialog has selected. Nothing here happens on its own:
    /// this runs because the dialog's own button was pressed.
    func confirmTagFetch() async {
        guard let repository, let remote = tagFetchSelection?.selectedRemote, canFetchTags else {
            return
        }
        tagFetchSelection = nil
        await runFetch(.tags(from: remote), in: repository)
    }

    // MARK: - Running one Fetch

    /// Runs one Fetch to completion, then reloads Repository state whatever it did.
    ///
    /// The reload is unconditional on purpose. A Fetch that failed partway and a Fetch the user
    /// stopped both leave refs exactly as far along as Git had written them, and only a real read
    /// can say where that is; reporting the state Colofa expected instead would be reporting a
    /// Repository that does not exist.
    private func runFetch(_ work: FetchWork, in repository: RepositorySnapshot) async {
        // Claimed before anything suspends, so a second press cannot start a second Fetch while
        // the first one is still on its way to the first `await`.
        fetchProgress = work.progress
        // Assigned in the same step, so a Cancel pressed the moment the Fetch appears on screen
        // still reaches the task it is offered for rather than falling into the gap before one
        // exists.
        let task = Task { [self] in
            await fetchReport(on: work, in: repository)
        }
        fetchTask = task

        // Kept alive past the initiating view task: a Fetch is stopped by Cancel, not by a view
        // going away, and the reload that follows it has to happen either way.
        await Task { [self] in
            let report = await task.value

            // Cleared once the task is finished with the remote, which is not where the Fetch
            // itself ends. Explaining a refused Fetch Tags contacts the remote a second time, and
            // while anything is out there the Cancel that stops it has to stay on screen.
            fetchTask = nil

            if report.outcome.reachedRemote {
                recordFetch(at: .now)
            }
            await refresh()
            if let failure = report.failure {
                presentFailure(failure)
            }
            // Released only once the reload has landed, the way a mutation holds the Repository
            // until its own reload does: until then the Fetch is still the command holding it,
            // and a second command landing in the middle of that reload would race it.
            fetchProgress = nil
        }.value
    }

    /// Runs one Fetch and, when it failed, works out what to say about it.
    ///
    /// Both halves live in the cancellable task because both can talk to the remote.
    private func fetchReport(
        on work: FetchWork,
        in repository: RepositorySnapshot
    ) async -> FetchReport {
        let outcome = await perform(work, in: repository)
        guard outcome.needsReporting else {
            return FetchReport(outcome: outcome, failure: nil)
        }
        return FetchReport(
            outcome: outcome,
            failure: await fetchFailure(outcome, of: work, in: repository)
        )
    }

    private func perform(
        _ work: FetchWork,
        in repository: RepositorySnapshot
    ) async -> FetchOutcome {
        switch work {
        case .everyRemote:
            await fetchEveryRemote(of: repository, running: FetchCommand.fetch)
        case .remotes:
            await fetchEveryRemote(of: repository, running: FetchCommand.fetchRemotes(from:))
        case .tags(let remote):
            await fetchTags(from: remote, of: repository)
        }
    }

    /// Contacts each eligible remote in turn, running `command` against each one.
    ///
    /// A remote that fails decides nothing about the others, so the rest are still contacted and
    /// whatever already arrived stays. That is what `git fetch --all` does too — Colofa runs the
    /// remotes one at a time so the one that failed can be named, and so a Fetch Remotes that
    /// pruned one remote leaves that remote pruned when the next one refuses.
    private func fetchEveryRemote(
        of repository: RepositorySnapshot,
        running command: (String) -> [String]
    ) async -> FetchOutcome {
        let plan: FetchPlan
        do {
            plan = FetchPlan.evaluate(
                remotes: repository.remotes,
                skipping: try await repositoryService.loadSkippedRemotes(repository.rootURL)
            )
        } catch is CancellationError {
            return .cancelled(fetched: [])
        } catch {
            return .planFailed(fetchError(error))
        }
        guard !plan.isEmpty else {
            return .nothingEligible
        }

        var fetched: [String] = []
        var failed: [String] = []
        var firstError: RepositoryOpenError?
        for remote in plan.remotes {
            guard !Task.isCancelled else {
                return .cancelled(fetched: fetched)
            }
            fetchProgress = FetchProgress(remote: remote)
            do {
                try await repositoryService.runNetworkMutation(
                    command(remote),
                    repository.rootURL,
                    authenticationResponder
                )
                fetched.append(remote)
            } catch is CancellationError {
                return .cancelled(fetched: fetched)
            } catch {
                failed.append(remote)
                firstError = firstError ?? fetchError(error)
            }
        }

        guard let firstError else {
            return .fetched(fetched)
        }
        return .failed(remotes: failed, fetched: fetched, error: firstError)
    }

    private func fetchTags(
        from remote: String,
        of repository: RepositorySnapshot
    ) async -> FetchOutcome {
        do {
            try await repositoryService.runNetworkMutation(
                FetchCommand.fetchTags(from: remote),
                repository.rootURL,
                authenticationResponder
            )
            return .fetched([remote])
        } catch is CancellationError {
            return .cancelled(fetched: [])
        } catch {
            return .failed(remotes: [remote], fetched: [], error: fetchError(error))
        }
    }

    // MARK: - Reporting

    private func fetchFailure(
        _ outcome: FetchOutcome,
        of work: FetchWork,
        in repository: RepositorySnapshot
    ) async -> RepositoryFailurePresentation {
        // Asked first, because a connection that was never trusted or never authenticated
        // explains both a Fetch and a Fetch Tags better than either of their own answers does.
        //
        // What the command itself decided is preferred over what its output says: prompt text is
        // redacted out of that output, so a refusal Colofa made from a prompt cannot be
        // recognized there again. The output still answers for a refusal that reached no prompt
        // at all, which is how OpenSSH usually refuses a key it already recorded.
        if let error = outcome.error,
           let details = error.failureDetails,
           let failure = details.authenticationFailure
               ?? AuthenticationFailure.detect(in: details.output) {
            return .authenticationAlert(failure, error: error)
        }
        guard case .tags(let remote) = work, let error = outcome.error else {
            return .fetchAlert(outcome)
        }
        return .tagFetchAlert(
            await tagConflict(from: remote, refusing: error, in: repository),
            remote: remote,
            error: error
        )
    }

    /// The local tags Git kept, or `nil` when this failure was not about them.
    ///
    /// Asked only after Git has already refused, so it explains a refusal rather than deciding
    /// one — and only when Git's own output names one of the tags, because the alert it produces
    /// goes on to say every other tag was downloaded. A Hook, a refspec, or an unreachable
    /// remote fails the same command without that being true, and a remote that merely happens
    /// to disagree about a tag name is not evidence that it was the reason.
    ///
    /// A read that itself fails is deliberately discarded rather than raised: the refusal the
    /// user needs to see is Git's, and the caller still shows it in full — this read only adds
    /// the names of the tags that were not replaced.
    private func tagConflict(
        from remote: String,
        refusing error: RepositoryOpenError,
        in repository: RepositorySnapshot
    ) async -> TagFetchConflict? {
        guard let output = error.failureDetails?.output else {
            return nil
        }
        guard let conflict = try? await repositoryService.loadTagConflicts(
            TagConflictRequest(repositoryURL: repository.rootURL, remote: remote)
        ), conflict.isNamed(in: output) else {
            return nil
        }
        return conflict
    }

    /// Git's own sanitized failure when Git produced one, and Colofa's description of the error
    /// when Git never got far enough to write one.
    private func fetchError(_ error: any Error) -> RepositoryOpenError {
        guard let error = error as? RepositoryOpenError else {
            return .commandFailed(
                GitFailureDetails(command: "git fetch", output: error.localizedDescription)
            )
        }
        return error
    }
}

/// What one Fetch is: every eligible remote, every eligible remote reconciled with what it still
/// holds, or every tag from one chosen remote.
///
/// Declared alongside rather than nested, because the Store is one type and this is a detail of
/// how its Fetch runs rather than part of its published state.
private enum FetchWork: Equatable, Sendable {
    case everyRemote
    case remotes
    case tags(from: String)

    /// A Fetch that walks every remote starts before its first remote is known, because which
    /// remotes are eligible is the first thing it has to ask Git.
    var progress: FetchProgress {
        switch self {
        case .everyRemote, .remotes: FetchProgress(remote: nil)
        case .tags(let remote): FetchProgress(remote: remote)
        }
    }
}
