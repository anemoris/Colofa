////
//  WorkspaceStateFetchCancellationTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation
import Testing
@testable import Colofa

/// What a running Fetch holds and for how long: when the Cancel it offers actually reaches the
/// command, when it stops offering one, and what stays refused until the reload it owes lands.
@Suite(.serialized)
final class WorkspaceStateFetchCancellationTests {
    private let defaults: UserDefaults
    private let suiteName = "com.anemoris.Colofa.WorkspaceStateFetchCancellationTests"
    private let repositoryURL = fetchRepositoryURL

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    @MainActor
    private func workspace(_ stub: RepositoryServiceStub) async -> WorkspaceState {
        await fetchWorkspace(stub, at: repositoryURL, defaults: defaults)
    }

    // MARK: - Stopping one

    /// A Fetch the user stopped still reloads: refs are as far along as Git wrote them, and only
    /// a real read can say where that is.
    @Test
    @MainActor
    func cancellingAFetchStopsItAndStillReloads() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [
                repositoryURL: [
                    fetchRepository(),
                    fetchRepository(remoteBranches: ["origin/main", "origin/feature"]),
                ],
            ],
            networkMutationDelay: .seconds(30)
        )
        let state = await workspace(stub)

        let fetching = Task { await state.fetch() }
        try await waitForFetch(
            { await stub.recordedNetworkMutations().count == 1 },
            "The Fetch never contacted a remote"
        )
        state.cancelFetch()
        await fetching.value

        #expect(await stub.recordedNetworkMutations() == [["fetch", "--", "origin"]])
        #expect(!state.isFetching)
        #expect(state.repositoryFailure == nil)
        #expect(state.repository?.remoteBranches == ["origin/main", "origin/feature"])
        #expect(state.lastFetchDate == nil)
    }

    /// The Cancel is offered the instant the Fetch appears on screen, so it has to work from that
    /// instant: a press that lands before the Fetch's first `await` must reach the command, not
    /// fall into the gap before there is a task to reach.
    @Test
    @MainActor
    func stopsAFetchPressedTheMomentItIsOfferedAsStoppable() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [fetchRepository(), fetchRepository()]],
            networkMutationDelay: .seconds(30)
        )
        let state = await workspace(stub)

        let fetching = Task { await state.fetch() }
        try await waitForFetch({ state.isFetching }, "The Fetch never started")
        #expect(state.canCancelFetch)

        let pressed = ContinuousClock.now
        state.cancelFetch()
        await fetching.value

        #expect(
            ContinuousClock.now - pressed < .seconds(5),
            "The Cancel never reached the Fetch it was offered for"
        )
        #expect(
            await stub.recordedNetworkMutations().isEmpty,
            "A Fetch stopped before it began still contacted a remote"
        )
        #expect(!state.isFetching)
        #expect(state.lastFetchDate == nil)
    }

    // MARK: - Holding the Repository

    /// A Fetch is not over when Git is: it still owes an authoritative read of refs Git has just
    /// moved. The hold lasts until that read lands, rather than reopening the Repository to the
    /// next command in the middle of it.
    @Test
    @MainActor
    func keepsHoldingTheRepositoryUntilItsReloadLands() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [
                repositoryURL: [
                    fetchRepository(),
                    fetchRepository(remoteBranches: ["origin/main", "origin/feature"]),
                ],
            ],
            delays: [repositoryURL: .milliseconds(300)]
        )
        let state = await workspace(stub)

        let fetching = Task { await state.fetch() }
        try await waitForFetch(
            { await stub.recordedNetworkMutations().count == 2 && state.isLoadingRepository },
            "The Fetch never reached the reload it owes"
        )

        #expect(state.isFetching, "The Fetch let go of the Repository before its reload landed")
        #expect(state.fetchUnavailabilityReason == .fetchInProgress)
        #expect(!state.canMutateRepository)
        #expect(!state.canReplaceRepository)
        // Nothing is out at a remote any more, so there is nothing left to interrupt.
        #expect(!state.canCancelFetch)

        await fetching.value
        #expect(!state.isFetching)
        #expect(state.canMutateRepository)
        #expect(state.repository?.remoteBranches == ["origin/main", "origin/feature"])
    }

    @Test
    @MainActor
    func reportsAFetchWhileItRuns() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [fetchRepository()]],
            networkMutationDelay: .seconds(30)
        )
        let state = await workspace(stub)

        let fetching = Task { await state.fetch() }
        try await waitForFetch({ state.fetchProgress?.remote == "origin" }, "Fetch never started")

        #expect(state.isFetching)
        #expect(!state.canFetch)
        #expect(state.fetchUnavailabilityReason == .fetchInProgress)
        #expect(!state.canMutateRepository)

        state.cancelFetch()
        await fetching.value
        #expect(state.fetchProgress == nil)
    }
}
