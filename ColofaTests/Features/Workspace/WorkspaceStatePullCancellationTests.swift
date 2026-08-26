////
//  WorkspaceStatePullCancellationTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation
import Testing
@testable import Colofa

/// What a running Pull holds and for how long: when the Cancel it offers actually reaches the
/// command, when it stops offering one, and what stays refused until the reload it owes lands.
@Suite(.serialized)
final class WorkspaceStatePullCancellationTests {
    private let defaults: UserDefaults
    private let suiteName = "com.anemoris.Colofa.WorkspaceStatePullCancellationTests"
    private let repositoryURL = pullRepositoryURL

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    @MainActor
    private func workspace(_ stub: RepositoryServiceStub) async -> WorkspaceState {
        await pullWorkspace(stub, at: repositoryURL, defaults: defaults)
    }

    // MARK: - Stopping one

    /// Stopping the network half stops the whole Pull: the fast-forward that would have followed
    /// never runs, and the reload still reports where Git actually got to.
    @Test
    @MainActor
    func stoppingTheNetworkHalfLeavesTheFastForwardUnrun() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [pullRepository(), pullRepository(behind: 1)]],
            networkMutationDelay: .seconds(30)
        )
        let state = await workspace(stub)

        let pulling = Task { await state.pull() }
        try await waitForFetch(
            { await stub.recordedNetworkMutations().count == 1 },
            "The Pull never contacted the remote"
        )
        #expect(state.canCancelPull)
        state.cancelPull()
        await pulling.value

        #expect(await stub.recordedArguments().isEmpty)
        #expect(!state.isPulling)
        #expect(state.repositoryFailure == nil)
        #expect(state.lastFetchDate == nil)
        #expect(state.repository?.upstream?.behind == 1)
    }

    /// The Cancel is offered the instant the Pull appears on screen, so it has to work from that
    /// instant: a press that lands before the Pull's first `await` must reach the command, not
    /// fall into the gap before there is a task to reach.
    @Test
    @MainActor
    func stopsAPullPressedTheMomentItIsOfferedAsStoppable() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [pullRepository(), pullRepository(behind: 1)]],
            networkMutationDelay: .seconds(30)
        )
        let state = await workspace(stub)

        let pulling = Task { await state.pull() }
        try await waitForFetch({ state.isPulling }, "The Pull never started")
        #expect(state.canCancelPull)

        let pressed = ContinuousClock.now
        state.cancelPull()
        await pulling.value

        #expect(
            ContinuousClock.now - pressed < .seconds(5),
            "The Cancel never reached the Pull it was offered for"
        )
        #expect(await stub.recordedArguments().isEmpty, "A stopped Pull still advanced the Branch")
        #expect(!state.isPulling)
        #expect(state.lastFetchDate == nil)
    }

    /// Once the remote is done with, there is nothing left that Colofa is willing to interrupt:
    /// a local index write must not stop halfway.
    @Test
    @MainActor
    func refusesToStopThePullOnceItIsPastTheRemote() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [pullRepository(), pullRepository(behind: 0)]],
            mutationDelay: .milliseconds(500)
        )
        let state = await workspace(stub)

        let pulling = Task { await state.pull() }
        try await waitForFetch(
            { state.pullProgress?.phase == .integrating },
            "The Pull never reached its fast-forward"
        )
        #expect(!state.canCancelPull)
        state.cancelPull()
        await pulling.value

        #expect(await stub.recordedArguments() == [PullCommand.fastForward])
        #expect(state.repository?.upstream?.behind == 0)
        #expect(state.lastFetchDate != nil)
    }

    // MARK: - Holding the Repository

    /// A Pull holds the Repository the way a mutation does, so nothing else may land in the
    /// middle of one.
    @Test
    @MainActor
    func holdsTheRepositoryWhileItRuns() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [pullRepository()]],
            networkMutationDelay: .seconds(30)
        )
        let state = await workspace(stub)

        let pulling = Task { await state.pull() }
        try await waitForFetch({ state.isPulling }, "The Pull never started")

        #expect(state.pullUnavailabilityReason == .pullInProgress)
        #expect(!state.canPull)
        #expect(!state.canFetch)
        #expect(!state.canMutateRepository)
        #expect(!state.canReplaceRepository)

        state.cancelPull()
        await pulling.value
        #expect(state.pullProgress == nil)
    }

    /// A Pull is not over when Git is: it still owes an authoritative read, and the explanation
    /// of a refusal is read out of what that returns. So the hold lasts until both are done,
    /// rather than reopening the Repository to the next command in the middle of them.
    @Test
    @MainActor
    func keepsHoldingTheRepositoryUntilItsReloadLands() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [pullRepository(), pullRepository(behind: 0)]],
            delays: [repositoryURL: .milliseconds(300)]
        )
        let state = await workspace(stub)

        let pulling = Task { await state.pull() }
        try await waitForFetch(
            { await stub.recordedArguments() == [PullCommand.fastForward] && state.isLoadingRepository },
            "The Pull never reached the reload it owes"
        )

        #expect(state.isPulling, "The Pull let go of the Repository before its reload landed")
        #expect(state.pullUnavailabilityReason == .pullInProgress)
        #expect(!state.canMutateRepository)
        #expect(!state.canReplaceRepository)
        // Git is done, so there is nothing left to interrupt even though the Pull is still here.
        #expect(!state.canCancelPull)

        await pulling.value
        #expect(!state.isPulling)
        #expect(state.canMutateRepository)
        #expect(state.repository?.upstream?.behind == 0)
    }

    /// The panel that replaces the open Repository is opened while nothing is running, but it
    /// can still be sitting there when a Pull starts. A selection that lands mid-Pull is refused
    /// rather than swapping out the Repository the running Pull is about to reload and report on.
    @Test
    @MainActor
    func refusesToReplaceTheRepositoryWhileAPullRuns() async throws {
        let otherURL = URL(filePath: "/tmp/Other Pull Store")
        let stub = RepositoryServiceStub(
            snapshots: [
                repositoryURL: [pullRepository()],
                otherURL: [pullRepository(at: otherURL)],
            ],
            networkMutationDelay: .seconds(30)
        )
        let state = await workspace(stub)

        let pulling = Task { await state.pull() }
        try await waitForFetch(
            { await stub.recordedNetworkMutations().count == 1 },
            "The Pull never contacted the remote"
        )

        await state.handleRepositorySelection(.success(otherURL))
        #expect(state.repository?.rootURL == repositoryURL)

        state.cancelPull()
        await pulling.value
        #expect(state.repository?.rootURL == repositoryURL)
    }
}
