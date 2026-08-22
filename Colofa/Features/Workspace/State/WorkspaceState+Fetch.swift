////
//  WorkspaceState+Fetch.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation

/// Manually refreshing remote-tracking refs, and explicitly downloading one remote's tags.
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
        fetchTask?.cancel()
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

    // MARK: - Last Fetch

    /// When Colofa last fetched `url`, or `nil` when it never has.
    ///
    /// Kept per Repository so reopening an earlier one never inherits another's time.
    func storedFetchDate(of url: URL) -> Date? {
        userDefaults.dictionary(forKey: Self.lastFetchDatesKey)?[url.normalizedFilePath] as? Date
    }

    private static let lastFetchDatesKey = "lastFetchDates"

    private func recordFetch(at date: Date) {
        guard let repository else {
            return
        }
        lastFetchDate = date
        guard !isUITesting else {
            return
        }
        var dates = userDefaults.dictionary(forKey: Self.lastFetchDatesKey) ?? [:]
        dates[repository.rootURL.normalizedFilePath] = date
        userDefaults.set(dates, forKey: Self.lastFetchDatesKey)
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

        // Kept alive past the initiating view task: a Fetch is stopped by Cancel, not by a view
        // going away, and the reload that follows it has to happen either way.
        await Task { [self] in
            let task = Task { [self] in
                await fetchReport(on: work, in: repository)
            }
            fetchTask = task
            let report = await task.value

            // Cleared only once the task is finished with the remote, not once the Fetch itself
            // is. Explaining a refused Fetch Tags contacts the remote a second time, and while
            // anything is out there the Cancel that stops it has to stay on screen and a second
            // Fetch has to stay refused.
            fetchTask = nil
            fetchProgress = nil

            if report.outcome.isSuccessful {
                recordFetch(at: .now)
            }
            await refresh()
            guard let failure = report.failure else {
                return
            }
            presentFailure(failure)
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
            await fetchEveryRemote(of: repository)
        case .tags(let remote):
            await fetchTags(from: remote, of: repository)
        }
    }

    /// Contacts each eligible remote in turn.
    ///
    /// A remote that fails decides nothing about the others, so the rest are still contacted and
    /// whatever already arrived stays. That is what `git fetch --all` does too — Colofa runs the
    /// remotes one at a time so the one that failed can be named.
    private func fetchEveryRemote(of repository: RepositorySnapshot) async -> FetchOutcome {
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
                    FetchCommand.fetch(remote),
                    repository.rootURL
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
                repository.rootURL
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

/// What one Fetch is: every eligible remote, or every tag from one chosen remote.
///
/// Declared alongside rather than nested, because the Store is one type and this is a detail of
/// how its Fetch runs rather than part of its published state.
private enum FetchWork: Equatable, Sendable {
    case everyRemote
    case tags(from: String)

    /// A Fetch of every remote starts before its first remote is known, because which remotes are
    /// eligible is the first thing it has to ask Git.
    var progress: FetchProgress {
        switch self {
        case .everyRemote: FetchProgress(remote: nil)
        case .tags(let remote): FetchProgress(remote: remote)
        }
    }
}
