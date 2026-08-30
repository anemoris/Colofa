////
//  WorkspaceStatePushCancellationTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// What a running Push holds and for how long: when the Cancel it offers actually reaches the
/// command, and what stays refused until the reload it owes lands.
@Suite(.serialized)
final class WorkspaceStatePushCancellationTests {
    private let defaults: UserDefaults
    private let suiteName = "com.anemoris.Colofa.WorkspaceStatePushCancellationTests"
    private let repositoryURL = pushRepositoryURL

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    @MainActor
    private func workspace(_ stub: RepositoryServiceStub) async -> WorkspaceState {
        await pushWorkspace(stub, at: repositoryURL, defaults: defaults)
    }

    private func slowStub() -> RepositoryServiceStub {
        RepositoryServiceStub(
            snapshots: [repositoryURL: [pushRepository(), pushRepository()]],
            networkMutationDelay: .seconds(30),
            pushTarget: pushTarget()
        )
    }

    /// The Cancel is offered the instant the Push appears on screen, so it has to work from that
    /// instant rather than falling into the gap before there is a task to reach.
    @Test
    @MainActor
    func stopsApushPressedTheMomentItIsOfferedAsStoppable() async throws {
        let stub = slowStub()
        let state = await workspace(stub)
        await state.beginPush()

        let pushing = Task { await state.confirmPush() }
        try await waitForFetch({ state.isPushing }, "The Push never started")
        #expect(state.canCancelPush)

        let pressed = ContinuousClock.now
        state.cancelPush()
        await pushing.value

        #expect(
            ContinuousClock.now - pressed < .seconds(5),
            "The Cancel never reached the Push it was offered for"
        )
        #expect(!state.isPushing)
        #expect(state.repositoryFailure == nil, "A Cancel the user pressed was reported as one")
    }

    /// A Push holds the Repository the way a mutation does, so nothing else may land in the
    /// middle of one.
    @Test
    @MainActor
    func holdsTheRepositoryWhileItRuns() async throws {
        let stub = slowStub()
        let state = await workspace(stub)
        await state.beginPush()

        let pushing = Task { await state.confirmPush() }
        try await waitForFetch({ state.isPushing }, "The Push never started")

        #expect(state.pushUnavailabilityReason == .pushInProgress)
        #expect(!state.canPush)
        #expect(!state.canFetch)
        #expect(!state.canPull)
        #expect(!state.canMutateRepository)
        #expect(!state.canReplaceRepository)

        state.cancelPush()
        await pushing.value
        #expect(state.pushProgress == nil)
    }

    /// A Push is not over when Git is: it still owes an authoritative read of what the remote
    /// accepted. So the hold lasts until that lands rather than reopening the Repository to the
    /// next command in the middle of it.
    @Test
    @MainActor
    func keepsHoldingTheRepositoryUntilItsReloadLands() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [pushRepository(), pushRepository(ahead: 0)]],
            delays: [repositoryURL: .milliseconds(300)],
            pushTarget: pushTarget()
        )
        let state = await workspace(stub)
        await state.beginPush()

        let pushing = Task { await state.confirmPush() }
        try await waitForFetch(
            { await stub.recordedNetworkMutations().count == 1 && state.isLoadingRepository },
            "The Push never reached the reload it owes"
        )

        #expect(state.isPushing, "The Push let go of the Repository before its reload landed")
        #expect(!state.canMutateRepository)
        #expect(!state.canReplaceRepository)

        await pushing.value
        #expect(!state.isPushing)
        #expect(state.canMutateRepository)
        #expect(state.repository?.upstream?.ahead == 0)
    }

    /// The panel that replaces the open Repository is opened while nothing is running, but it can
    /// still be sitting there when a Push starts. A selection that lands mid-Push is refused
    /// rather than swapping out the Repository the running Push is about to reload.
    @Test
    @MainActor
    func refusesToReplaceTheRepositoryWhileApushRuns() async throws {
        let otherURL = URL(filePath: "/tmp/Other Push Store")
        let stub = RepositoryServiceStub(
            snapshots: [
                repositoryURL: [pushRepository()],
                otherURL: [pushRepository(at: otherURL)],
            ],
            networkMutationDelay: .seconds(30),
            pushTarget: pushTarget()
        )
        let state = await workspace(stub)
        await state.beginPush()

        let pushing = Task { await state.confirmPush() }
        try await waitForFetch(
            { await stub.recordedNetworkMutations().count == 1 },
            "The Push never contacted the remote"
        )

        await state.handleRepositorySelection(.success(otherURL))
        #expect(state.repository?.rootURL == repositoryURL)

        state.cancelPush()
        await pushing.value
        #expect(state.repository?.rootURL == repositoryURL)
    }

    /// A dialog is about one Repository's Branch, remote, and expected object, so it must not
    /// follow the user into another Repository.
    @Test
    @MainActor
    func aconfirmationDoesNotSurviveIntoAnotherRepository() async throws {
        let otherURL = URL(filePath: "/tmp/Other Push Store")
        let stub = RepositoryServiceStub(
            snapshots: [
                repositoryURL: [pushRepository()],
                otherURL: [pushRepository(at: otherURL)],
            ],
            pushTarget: pushTarget()
        )
        let state = await workspace(stub)
        await state.beginPush()
        #expect(state.isConfirmingPush)

        await state.handleRepositorySelection(.success(otherURL))

        #expect(state.pushDialog == nil)
        #expect(await stub.recordedNetworkMutations().isEmpty)
    }
}
