////
//  WorkspaceStateFetchRemotesTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation
import Testing
@testable import Colofa

/// Store-level behaviour of Fetch Remotes: which commands run, what a partial or stopped one
/// leaves behind, and the promise that it changes nothing about the ordinary Fetch beside it.
@Suite(.serialized)
final class WorkspaceStateFetchRemotesTests {
    private let defaults: UserDefaults
    private let suiteName = "com.anemoris.Colofa.WorkspaceStateFetchRemotesTests"
    private let repositoryURL = fetchRepositoryURL

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    @MainActor
    private func workspace(_ stub: RepositoryServiceStub) async -> WorkspaceState {
        await fetchWorkspace(stub, at: repositoryURL, defaults: defaults)
    }

    private func fetchRemotes(_ remote: String) -> [String] {
        FetchCommand.fetchRemotes(from: remote)
    }

    // MARK: - What it runs

    @Test
    @MainActor
    func reconcilesEveryConfiguredRemoteOneAtATime() async throws {
        let stub = RepositoryServiceStub(snapshots: [repositoryURL: [fetchRepository()]])
        let state = await workspace(stub)

        await state.fetchRemotes()

        #expect(
            await stub.recordedNetworkMutations() == [
                fetchRemotes("origin"),
                fetchRemotes("mirror"),
            ]
        )
        #expect(state.repositoryFailure == nil)
    }

    /// A remote Git leaves out of a Fetch of all of them is one Colofa leaves out too: pruning
    /// behind Git's own eligibility rule would contact a remote the user excluded.
    @Test
    @MainActor
    func leavesOutTheRemotesGitExcludesFromAFetchOfAllOfThem() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [fetchRepository()]],
            skippedRemotes: ["mirror"]
        )
        let state = await workspace(stub)

        await state.fetchRemotes()

        #expect(await stub.recordedNetworkMutations() == [fetchRemotes("origin")])
    }

    @Test
    @MainActor
    func runsNoCommandWhenGitExcludesEveryRemote() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [fetchRepository()]],
            skippedRemotes: ["origin", "mirror"]
        )
        let state = await workspace(stub)

        await state.fetchRemotes()

        #expect(await stub.recordedNetworkMutations().isEmpty)
        #expect(state.repositoryFailureTitle == .fetchNothingEligibleTitle)
        #expect(state.lastFetchDate == nil)
    }

    /// The toolbar's Fetch is untouched by this: it still adds no option, so a Repository that
    /// was already pruning on Fetch keeps pruning and one that was not still does not.
    @Test
    @MainActor
    func leavesTheOrdinaryFetchExactlyAsItWas() async throws {
        let stub = RepositoryServiceStub(snapshots: [repositoryURL: [fetchRepository()]])
        let state = await workspace(stub)

        await state.fetch()

        #expect(
            await stub.recordedNetworkMutations() == [
                ["fetch", "--", "origin"],
                ["fetch", "--", "mirror"],
            ]
        )
    }

    // MARK: - What it leaves behind

    /// The refs on screen are the ones the reload read back, not the ones Colofa expected.
    @Test
    @MainActor
    func reloadsTheRepositoryAfterReconciling() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [
                repositoryURL: [
                    fetchRepository(remoteBranches: ["origin/main", "origin/gone"]),
                    fetchRepository(remoteBranches: ["origin/main"]),
                ],
            ]
        )
        let state = await workspace(stub)
        #expect(state.repository?.remoteBranches == ["origin/main", "origin/gone"])

        await state.fetchRemotes()

        #expect(state.repository?.remoteBranches == ["origin/main"])
    }

    @Test
    @MainActor
    func recordsTheLastFetchTimeOnlyWhenEveryRemoteAnswered() async throws {
        let stub = RepositoryServiceStub(snapshots: [repositoryURL: [fetchRepository()]])
        let state = await workspace(stub)
        #expect(state.lastFetchDate == nil)

        await state.fetchRemotes()

        let recorded = try #require(state.lastFetchDate)
        #expect(recorded.timeIntervalSinceNow < 5)
    }

    // MARK: - Partial failure

    /// One remote failing says nothing about the next: the failing one is named, the rest are
    /// still contacted, and whatever a remote already pruned stays pruned.
    @Test
    @MainActor
    func namesTheFailingRemoteAndKeepsWhatTheOthersReconciled() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [
                repositoryURL: [
                    fetchRepository(
                        remotes: ["mirror", "origin"],
                        remoteBranches: ["origin/main", "origin/gone"]
                    ),
                    fetchRepository(remotes: ["mirror", "origin"]),
                ],
            ],
            failingRemotes: ["mirror"]
        )
        let state = await workspace(stub)

        await state.fetchRemotes()

        #expect(
            await stub.recordedNetworkMutations() == [
                fetchRemotes("mirror"),
                fetchRemotes("origin"),
            ]
        )
        let message = try #require(state.repositoryFailureMessage)
        #expect(String(localized: message).contains("mirror"))
        #expect(state.canShowRepositoryFailureDetails)
        #expect(state.repository?.remoteBranches == ["origin/main"])
        #expect(state.lastFetchDate == nil)
    }

    /// A failure that never reached a remote is reported as itself rather than blamed on one.
    @Test
    @MainActor
    func reportsAConfigurationItCouldNotRead() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [fetchRepository()]],
            skippedRemotesError: .commandFailed(
                GitFailureDetails(command: "git config", output: "fatal: bad config", exitStatus: 1)
            )
        )
        let state = await workspace(stub)

        await state.fetchRemotes()

        #expect(await stub.recordedNetworkMutations().isEmpty)
        #expect(state.repositoryFailureTitle == .fetchFailed)
        #expect(state.lastFetchDate == nil)
    }

    // MARK: - Cancellation

    /// Stopping it leaves the remotes it already reconciled reconciled, raises no alert about
    /// what the user just did, and still reloads.
    @Test
    @MainActor
    func canBeStoppedAndStillReloads() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [
                repositoryURL: [
                    fetchRepository(remoteBranches: ["origin/main", "origin/gone"]),
                    fetchRepository(remoteBranches: ["origin/main"]),
                ],
            ],
            networkMutationDelay: .seconds(30)
        )
        let state = await workspace(stub)

        let running = Task { await state.fetchRemotes() }
        try await waitForFetch(
            { state.canCancelFetch },
            "The Fetch Remotes never became something that could be stopped"
        )
        state.cancelFetch()
        await running.value

        #expect(state.repositoryFailure == nil)
        #expect(state.lastFetchDate == nil)
        #expect(state.repository?.remoteBranches == ["origin/main"])
    }

    // MARK: - Availability

    /// It is unavailable for the same reasons Fetch is, and says so in the same words.
    @Test
    @MainActor
    func refusesToRunWithoutARemote() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [fetchRepository(remotes: [])]]
        )
        let state = await workspace(stub)

        #expect(!state.canFetchRemotes)
        #expect(state.fetchUnavailabilityReason == .noRemotes)
        await state.fetchRemotes()

        #expect(await stub.recordedNetworkMutations().isEmpty)
    }

    /// A Fetch already out at a remote holds this one, exactly as it holds a second Fetch.
    @Test
    @MainActor
    func isHeldByACommandAlreadyRunning() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [fetchRepository()]],
            networkMutationDelay: .seconds(30)
        )
        let state = await workspace(stub)

        let running = Task { await state.fetch() }
        // Waited for the command rather than for the spinner: the progress is claimed before the
        // task starts, so a wait on it alone could cancel a Fetch that never reached a remote.
        try await waitForFetch(
            { await stub.recordedNetworkMutations().count == 1 },
            "The Fetch never reached a remote"
        )

        #expect(!state.canFetchRemotes)
        #expect(state.fetchUnavailabilityReason == .fetchInProgress)
        await state.fetchRemotes()
        #expect(await stub.recordedNetworkMutations() == [["fetch", "--", "origin"]])

        state.cancelFetch()
        await running.value
    }

    /// Nothing contacts a remote on its own, and reconciling refs is no exception.
    @Test
    @MainActor
    func neverRunsWithoutBeingAsked() async throws {
        let stub = RepositoryServiceStub(snapshots: [repositoryURL: [fetchRepository()]])
        let state = await workspace(stub)

        await state.start()
        await state.refresh()

        #expect(await stub.recordedNetworkMutations().isEmpty)
    }
}
