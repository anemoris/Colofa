////
//  WorkspaceStatePullTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation
import Testing
@testable import Colofa

/// Store-level behaviour of Pull: which commands run and in which order, what each refusal is
/// explained as, and what a Pull the user stopped leaves behind.
@Suite(.serialized)
final class WorkspaceStatePullTests {
    private let defaults: UserDefaults
    private let suiteName = "com.anemoris.Colofa.WorkspaceStatePullTests"
    private let repositoryURL = pullRepositoryURL

    private static let refusal = RepositoryOpenError.commandFailed(
        GitFailureDetails(
            command: "git merge",
            output: "fatal: Not possible to fast-forward, aborting.",
            exitStatus: 128
        )
    )

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    @MainActor
    private func workspace(_ stub: RepositoryServiceStub) async -> WorkspaceState {
        await pullWorkspace(stub, at: repositoryURL, defaults: defaults)
    }

    // MARK: - Fast-forward

    /// The two halves, in order: contact the remote, then advance the Branch — and nothing else.
    @Test
    @MainActor
    func fetchesTheUpstreamThenFastForwardsOntoIt() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [pullRepository(), pullRepository(behind: 0)]]
        )
        let state = await workspace(stub)

        await state.pull()

        #expect(await stub.recordedNetworkMutations() == [PullCommand.fetch])
        #expect(await stub.recordedArguments() == [PullCommand.fastForward])
        #expect(state.repositoryFailure == nil)
    }

    /// A Pull reads Repository state back afterwards, because where the Branch ended up is Git's
    /// answer rather than something Colofa can assume.
    @Test
    @MainActor
    func reloadsTheRepositoryAfterPulling() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [
                repositoryURL: [
                    pullRepository(behind: 2, totalCommitCount: 12),
                    pullRepository(behind: 0, totalCommitCount: 14),
                ],
            ]
        )
        let state = await workspace(stub)
        #expect(state.repository?.upstream?.behind == 2)

        await state.pull()

        #expect(state.repository?.upstream?.behind == 0)
        #expect(state.repository?.totalCommitCount == 14)
    }

    /// A Branch already at its upstream is still a Pull: whether anything is there to download is
    /// the remote's answer, not the last Fetch's.
    @Test
    @MainActor
    func runsBothHalvesForABranchThatTurnsOutToBeAlreadyCurrent() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [pullRepository(behind: 0), pullRepository(behind: 0)]]
        )
        let state = await workspace(stub)

        await state.pull()

        #expect(await stub.recordedNetworkMutations() == [PullCommand.fetch])
        #expect(await stub.recordedArguments() == [PullCommand.fastForward])
        #expect(state.repositoryFailure == nil)
        #expect(state.lastFetchDate != nil)
    }

    // MARK: - Last Fetch

    @Test
    @MainActor
    func recordsTheLastFetchTimeAPullEarned() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [pullRepository(), pullRepository(behind: 0)]]
        )
        let state = await workspace(stub)
        #expect(state.lastFetchDate == nil)

        await state.pull()

        let recorded = try #require(state.lastFetchDate)
        #expect(recorded.timeIntervalSinceNow < 5)
    }

    /// A Pull whose Fetch answered and whose fast-forward was then refused still fetched, and the
    /// counts now on screen are exactly as fresh as a Fetch would have left them.
    @Test
    @MainActor
    func recordsTheLastFetchTimeEvenWhenTheBranchCouldNotBeAdvanced() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [
                repositoryURL: [pullRepository(), pullRepository(ahead: 2, behind: 3)],
            ],
            mutationError: Self.refusal
        )
        let state = await workspace(stub)

        await state.pull()

        #expect(state.lastFetchDate != nil)
    }

    // MARK: - Authentication

    /// A Pull's Fetch asks for a secret the same way any command that contacts a remote does, and
    /// refusing the question stops the Pull rather than letting it fail on its own.
    @Test
    @MainActor
    func asksForASecretThroughTheEstablishedRequestAndStopsWhenItIsRefused() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [pullRepository()]],
            authenticationPrompts: ["Password for 'https://octocat@example.invalid': "]
        )
        let state = await workspace(stub)

        let pulling = Task { await state.pull() }
        try await waitForFetch(
            { state.authenticationRequest != nil },
            "The Pull never asked for anything"
        )
        #expect(state.authenticationRequest?.kind == .password)

        state.cancelAuthentication()
        await pulling.value

        #expect(await stub.recordedArguments().isEmpty, "A refused question still advanced HEAD")
        #expect(state.repositoryFailure == nil, "A Cancel the user pressed was reported as one")
        #expect(state.lastFetchDate == nil)
    }

    // MARK: - Refusing before the command

    @Test
    @MainActor
    func refusesToPullWithoutAnUpstream() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [pullRepository(upstream: nil)]]
        )
        let state = await workspace(stub)

        #expect(!state.canPull)
        #expect(state.pullUnavailabilityReason == .noUpstream)
        await state.pull()

        #expect(await stub.recordedNetworkMutations().isEmpty)
        #expect(await stub.recordedArguments().isEmpty)
    }

    /// Colofa contacts a remote only when the user asks, and a Pull is no exception.
    @Test
    @MainActor
    func neverPullsWithoutBeingAsked() async throws {
        let stub = RepositoryServiceStub(snapshots: [repositoryURL: [pullRepository()]])
        let state = await workspace(stub)

        await state.start()
        await state.refresh()

        #expect(await stub.recordedNetworkMutations().isEmpty)
        #expect(await stub.recordedArguments().isEmpty)
    }
}
