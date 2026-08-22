////
//  WorkspaceStateFetchTagsTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation
import Testing
@testable import Colofa

/// Store-level behaviour of Fetch Tags: which remote it asks about, what it runs, and how a
/// refusal Git gave is explained.
@Suite(.serialized)
final class WorkspaceStateFetchTagsTests {
    private let defaults: UserDefaults
    private let suiteName = "com.anemoris.Colofa.WorkspaceStateFetchTagsTests"
    private let repositoryURL = fetchRepositoryURL

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    @MainActor
    private func workspace(_ stub: RepositoryServiceStub) async -> WorkspaceState {
        await fetchWorkspace(stub, at: repositoryURL, defaults: defaults)
    }

    @Test
    @MainActor
    func fetchTagsUsesASoleRemoteWithoutAsking() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [fetchRepository(remotes: ["origin"])]]
        )
        let state = await workspace(stub)

        await state.fetchTags()

        #expect(state.tagFetchSelection == nil)
        #expect(
            await stub.recordedNetworkMutations() == [FetchCommand.fetchTags(from: "origin")]
        )
    }

    /// Several remotes are a question, and opening the dialog is not an answer to it.
    @Test
    @MainActor
    func fetchTagsAsksAmongSeveralRemotesWithOriginPreselected() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [fetchRepository(remotes: ["backup", "origin"])]]
        )
        let state = await workspace(stub)

        await state.fetchTags()

        #expect(state.tagFetchSelection?.selectedRemote == "origin")
        #expect(state.tagFetchSelection?.remotes == ["backup", "origin"])
        #expect(state.isChoosingTagFetchRemote)
        #expect(await stub.recordedNetworkMutations().isEmpty)
    }

    @Test
    @MainActor
    func fetchTagsRunsOnlyTheRemoteTheDialogConfirmed() async throws {
        let stub = RepositoryServiceStub(snapshots: [repositoryURL: [fetchRepository()]])
        let state = await workspace(stub)
        await state.fetchTags()
        state.tagFetchSelection?.selectedRemote = "mirror"

        await state.confirmTagFetch()

        #expect(
            await stub.recordedNetworkMutations() == [FetchCommand.fetchTags(from: "mirror")]
        )
        #expect(state.tagFetchSelection == nil)
    }

    @Test
    @MainActor
    func cancellingTheFetchTagsDialogRunsNothing() async throws {
        let stub = RepositoryServiceStub(snapshots: [repositoryURL: [fetchRepository()]])
        let state = await workspace(stub)
        await state.fetchTags()

        state.cancelTagFetch()

        #expect(state.tagFetchSelection == nil)
        #expect(await stub.recordedNetworkMutations().isEmpty)
    }

    /// A remote chosen from one Repository's remotes answers nothing about another's. Both
    /// Repositories here have an `origin`, so a dialog that survived the switch would contact a
    /// remote of the Repository now open that the user was never asked about.
    @Test
    @MainActor
    func theFetchTagsDialogDoesNotFollowTheUserIntoAnotherRepository() async throws {
        let replacementURL = URL(filePath: "/tmp/Fetch Store Replacement")
        let stub = RepositoryServiceStub(
            snapshots: [
                repositoryURL: [fetchRepository(remotes: ["backup", "origin"])],
                replacementURL: [
                    fetchRepository(at: replacementURL, remotes: ["origin", "mirror"]),
                ],
            ]
        )
        let state = await workspace(stub)
        await state.fetchTags()
        #expect(state.isChoosingTagFetchRemote)

        await state.handleRepositorySelection(.success(replacementURL))

        #expect(state.tagFetchSelection == nil)
        await state.confirmTagFetch()
        #expect(await stub.recordedNetworkMutations().isEmpty)
    }

    @Test
    @MainActor
    func fetchTagsNeverForcesOrPrunes() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [fetchRepository(remotes: ["origin"])]]
        )
        let state = await workspace(stub)

        await state.fetchTags()

        let arguments = try #require(await stub.recordedNetworkMutations().first)
        for option in refusedFetchOptions {
            #expect(!arguments.contains(option), "\(arguments) carries \(option)")
        }
    }

    /// Git refuses to replace a local tag of the same name, and the refusal names the tags it
    /// kept rather than only reporting a non-zero exit.
    @Test
    @MainActor
    func explainsARefusedFetchTagsWithTheTagsGitKept() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [fetchRepository(remotes: ["origin"])]],
            failingRemotes: ["origin"],
            networkFailureOutput: " ! [rejected] v1.0 -> v1.0  (would clobber existing tag)",
            tagConflict: TagFetchConflict(tags: ["v1.0"])
        )
        let state = await workspace(stub)

        await state.fetchTags()

        #expect(
            await stub.recordedTagConflictRequests() == [
                TagConflictRequest(repositoryURL: repositoryURL, remote: "origin"),
            ]
        )
        let message = String(localized: try #require(state.repositoryFailureMessage))
        #expect(message.contains("v1.0"))
        #expect(state.canShowRepositoryFailureDetails)
        #expect(state.repository?.tags == ["v1.0"])
    }

    /// A Fetch Tags that failed for another reason is reported as the command failure it is,
    /// rather than being explained as a tag conflict that does not exist.
    @Test
    @MainActor
    func reportsAFetchTagsFailureThatNoTagConflictExplains() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [fetchRepository(remotes: ["origin"])]],
            failingRemotes: ["origin"]
        )
        let state = await workspace(stub)

        await state.fetchTags()

        #expect(state.repositoryFailureTitle == .fetchTagsFailed)
        #expect(state.canShowRepositoryFailureDetails)
    }

    /// A remote that happens to disagree about a tag name does not explain a failure that was
    /// never about tags. Saying it did would tell the user every other tag was downloaded, which
    /// a Hook, a refspec, or an unreachable remote makes untrue.
    @Test
    @MainActor
    func reportsAFailureATagConflictDoesNotExplain() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [fetchRepository(remotes: ["origin"])]],
            failingRemotes: ["origin"],
            networkFailureOutput: "error: hook declined to update refs/tags/*",
            tagConflict: TagFetchConflict(tags: ["v1.0"])
        )
        let state = await workspace(stub)

        await state.fetchTags()

        #expect(state.repositoryFailureTitle == .fetchTagsFailed)
        #expect(state.canShowRepositoryFailureDetails)
    }

    /// The explanation is a second trip to the remote, so it stays inside the Fetch the user can
    /// stop: Cancel is still on screen while it runs, a second Fetch is still refused, and
    /// pressing Cancel ends it.
    @Test
    @MainActor
    func keepsARefusedFetchTagsStoppableWhileItIsExplained() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [fetchRepository(remotes: ["origin"])]],
            failingRemotes: ["origin"],
            networkFailureOutput: " ! [rejected] v1.0 -> v1.0  (would clobber existing tag)",
            tagConflict: TagFetchConflict(tags: ["v1.0"]),
            tagConflictDelay: .seconds(30)
        )
        let state = await workspace(stub)

        let fetching = Task { await state.fetchTags() }
        try await waitForFetch(
            { await stub.recordedTagConflictRequests().count == 1 },
            "The refusal was never explained"
        )

        #expect(state.isFetching, "Cancel disappeared while a remote was still being contacted")
        #expect(!state.canFetch)
        #expect(state.fetchUnavailabilityReason == .fetchInProgress)

        state.cancelFetch()
        await fetching.value

        #expect(!state.isFetching)
        #expect(state.repositoryFailureTitle == .fetchTagsFailed)
    }

    /// The second read is an explanation, not the answer. One that fails is discarded so Git's
    /// own refusal still reaches the user in full.
    @Test
    @MainActor
    func stillReportsTheRefusalWhenTheExplanationCannotBeRead() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [fetchRepository(remotes: ["origin"])]],
            failingRemotes: ["origin"],
            networkFailureOutput: " ! [rejected] v1.0 -> v1.0  (would clobber existing tag)",
            tagConflictError: .commandFailed(
                GitFailureDetails(command: "git ls-remote", output: "offline", exitStatus: 128)
            )
        )
        let state = await workspace(stub)

        await state.fetchTags()

        #expect(state.repositoryFailureTitle == .fetchTagsFailed)
        #expect(state.canShowRepositoryFailureDetails)
    }
}
