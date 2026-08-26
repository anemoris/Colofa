////
//  WorkspaceStatePullRefusalTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation
import Testing
@testable import Colofa

/// What a Pull that could not fast-forward is explained as.
///
/// Kept apart from the Pull suite itself because these are all the same question asked once per
/// refusal: which half of the Pull ended it, and what the user has to do about that.
@Suite(.serialized)
final class WorkspaceStatePullRefusalTests {
    private let defaults: UserDefaults
    private let suiteName = "com.anemoris.Colofa.WorkspaceStatePullRefusalTests"
    private let repositoryURL = pullRepositoryURL

    private static let refusal = RepositoryOpenError.commandFailed(
        GitFailureDetails(
            command: "git merge",
            output: "fatal: Not possible to fast-forward, aborting.",
            exitStatus: 128
        )
    )

    private static let unreachable = RepositoryOpenError.commandFailed(
        GitFailureDetails(
            command: "git fetch",
            output: "fatal: could not read from remote repository",
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

    // MARK: - The remote was never reached

    /// A Pull that never reached the remote has nothing to date.
    @Test
    @MainActor
    func recordsNoTimeForAPullThatNeverReachedTheRemote() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [pullRepository()]],
            networkMutationError: Self.unreachable
        )
        let state = await workspace(stub)

        await state.pull()

        #expect(state.lastFetchDate == nil)
        #expect(await stub.recordedArguments().isEmpty, "The fast-forward ran without a Fetch")
        #expect(state.repositoryFailureTitle == .pullFailed)
        #expect(state.canShowRepositoryFailureDetails)
    }

    // MARK: - Divergence

    /// The Fetch answered and the Branch turned out to have moved too, which is the one thing a
    /// fast-forward can never resolve.
    @Test
    @MainActor
    func explainsADivergenceAndNamesMergeAndRebase() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [
                repositoryURL: [pullRepository(), pullRepository(ahead: 2, behind: 3)],
            ],
            mutationError: Self.refusal
        )
        let state = await workspace(stub)

        await state.pull()

        let title = englishText(try #require(state.repositoryFailureTitle))
        #expect(title.contains("main"))
        #expect(title.contains("origin/main"))
        let message = englishText(try #require(state.repositoryFailureMessage))
        #expect(message.contains("Merge"))
        #expect(message.contains("Rebase"))
        #expect(state.canShowRepositoryFailureDetails)
    }

    /// A refused fast-forward starts nothing: there is no Merge to abort, so no Abort is offered.
    @Test
    @MainActor
    func leavesNoGitOperationBehindWhenTheFastForwardIsRefused() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [
                repositoryURL: [pullRepository(), pullRepository(ahead: 2, behind: 3)],
            ],
            mutationError: Self.refusal
        )
        let state = await workspace(stub)

        await state.pull()

        #expect(state.repository?.operation == nil)
        #expect(await stub.recordedArguments() == [PullCommand.fastForward])
    }

    // MARK: - Local work in the way

    /// Git refused because advancing the Branch would have overwritten local work, so the refusal
    /// names it — from Git's own walk against the upstream, not from Git's message.
    @Test
    @MainActor
    func namesTheLocalWorkAPullWouldHaveOverwritten() async throws {
        let path = "本地更改.txt"
        let stub = RepositoryServiceStub(
            snapshots: [
                repositoryURL: [
                    pullRepository(),
                    pullRepository(
                        unstagedChanges: [RepositoryChange(path: path, kind: .modified)]
                    ),
                ],
            ],
            mutationError: .commandFailed(
                GitFailureDetails(command: "git merge", output: "would be overwritten")
            ),
            checkoutComparison: CheckoutComparison(changedPaths: [path], addedPaths: [])
        )
        let state = await workspace(stub)

        await state.pull()

        #expect(state.repositoryFailureTitle == .pullBlockedTitle)
        let message = englishText(try #require(state.repositoryFailureMessage))
        #expect(message.contains(path))
        let comparisons = await stub.recordedCheckoutComparisonRequests()
        #expect(comparisons.map { $0.revision } == [PullCommand.upstreamRevision])
    }

    /// A refusal Colofa cannot explain is still Git's refusal, shown in full rather than dressed
    /// up as one of the two it does understand.
    @Test
    @MainActor
    func fallsBackToGitsOwnRefusalWhenNeitherExplanationFits() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [pullRepository(), pullRepository()]],
            mutationError: .commandFailed(
                GitFailureDetails(command: "git merge", output: "hook refused the update")
            )
        )
        let state = await workspace(stub)

        await state.pull()

        #expect(state.repositoryFailureTitle == .pullFailed)
        #expect(state.canShowRepositoryFailureDetails)
    }

    // MARK: - Authentication

    /// A connection that was never trusted or never authenticated explains a Pull better than
    /// anything about its Branch does.
    @Test
    @MainActor
    func reportsAnAuthenticationFailureAsItself() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [pullRepository()]],
            networkMutationError: .commandFailed(
                GitFailureDetails(
                    command: "git fetch",
                    output: "Host key verification failed.",
                    exitStatus: 128
                )
            )
        )
        let state = await workspace(stub)

        await state.pull()

        #expect(state.repositoryFailureTitle != .pullFailed)
        #expect(state.canShowRepositoryFailureDetails)
        #expect(await stub.recordedArguments().isEmpty)
    }
}
