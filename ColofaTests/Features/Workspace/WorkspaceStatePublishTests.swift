////
//  WorkspaceStatePublishTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// Store-level behaviour of Publish: where a Branch nobody has pushed yet goes, when Colofa asks
/// rather than decides, and what one Publish actually runs.
@Suite(.serialized)
final class WorkspaceStatePublishTests {
    private let defaults: UserDefaults
    private let suiteName = "com.anemoris.Colofa.WorkspaceStatePublishTests"
    private let repositoryURL = pushRepositoryURL

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    @MainActor
    private func workspace(_ stub: RepositoryServiceStub) async -> WorkspaceState {
        await pushWorkspace(stub, at: repositoryURL, defaults: defaults)
    }

    /// A Branch with no upstream is not being sent anywhere yet, so the toolbar offers the other
    /// thing entirely.
    @Test
    @MainActor
    func abranchWithNoUpstreamOffersPublishRatherThanPush() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [pushRepository(upstream: nil)]]
        )
        let state = await workspace(stub)

        #expect(state.isCurrentBranchUnpublished)
        #expect(state.canPush)
    }

    @Test
    @MainActor
    func abranchWithAnupstreamIsPushedRatherThanPublished() async throws {
        let stub = RepositoryServiceStub(snapshots: [repositoryURL: [pushRepository()]])
        let state = await workspace(stub)

        #expect(!state.isCurrentBranchUnpublished)
    }

    /// Detached HEAD is on no Branch, so it is neither published nor pushed — and it says why.
    @Test
    @MainActor
    func detachedHeadNeitherPublishesNorPushes() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [pushRepository(head: .detached("0123456"), upstream: nil)]]
        )
        let state = await workspace(stub)

        #expect(!state.canPush)
        #expect(state.pushUnavailabilityReason == .detachedHead)
        #expect(!state.isCurrentBranchUnpublished)
        await state.beginPush()

        #expect(await stub.recordedNetworkMutations().isEmpty)
        #expect(state.pushDialog == nil)
    }

    // MARK: - Where it goes

    /// Git's own configuration is honored before any rule of Colofa's, even where the Repository
    /// has other remotes that would otherwise raise a question.
    @Test
    @MainActor
    func aconfiguredPushRemoteIsHonoredWithoutAsking() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [pushRepository(upstream: nil, remotes: ["origin", "mirror"])]],
            publishRemote: "mirror"
        )
        let state = await workspace(stub)

        await state.beginPush()

        #expect(state.pushDialog == nil, "A configured remote was asked about anyway")
        #expect(await stub.recordedNetworkMutations() == [PushCommand.publish("main", to: "mirror")])
        #expect(
            await stub.recordedPublishRemoteRequests().map(\.branch) == ["main"],
            "Publish never asked where this Branch goes"
        )
    }

    /// One remote is the answer rather than a question.
    @Test
    @MainActor
    func asoleRemoteIsUsedWithoutAsking() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [pushRepository(upstream: nil)]]
        )
        let state = await workspace(stub)

        await state.beginPush()

        #expect(state.pushDialog == nil)
        #expect(await stub.recordedNetworkMutations() == [PushCommand.publish("main", to: "origin")])
    }

    /// Several remotes and nothing configured is genuinely ambiguous, so Colofa asks — and
    /// publishes nothing until the dialog's own button is pressed.
    @Test
    @MainActor
    func severalRemotesWithNoConfigurationOpenThedialogWithOriginPreselected() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [pushRepository(upstream: nil, remotes: ["mirror", "origin"])]]
        )
        let state = await workspace(stub)

        await state.beginPush()

        #expect(state.isChoosingPublishRemote)
        #expect(state.pushDialog?.publishRemote?.selectedRemote == "origin")
        #expect(state.pushDialog?.publishRemote?.remotes == ["mirror", "origin"])
        #expect(await stub.recordedNetworkMutations().isEmpty, "The dialog published on its own")
    }

    /// The dialog's answer is the one that travels, not the one it opened on.
    @Test
    @MainActor
    func theSelectedRemoteIsWhatIsPublishedTo() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [pushRepository(upstream: nil, remotes: ["mirror", "origin"])]]
        )
        let state = await workspace(stub)
        await state.beginPush()

        state.pushDialog?.publishRemote?.selectedRemote = "mirror"
        await state.confirmPublishRemote()

        #expect(await stub.recordedNetworkMutations() == [PushCommand.publish("main", to: "mirror")])
        #expect(state.pushDialog == nil)
    }

    @Test
    @MainActor
    func cancellingThedialogPublishesNothing() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [pushRepository(upstream: nil, remotes: ["mirror", "origin"])]]
        )
        let state = await workspace(stub)
        await state.beginPush()

        state.cancelPublishRemote()

        #expect(state.pushDialog == nil)
        #expect(await stub.recordedNetworkMutations().isEmpty)
    }

    // MARK: - What it leaves behind

    /// A Publish is only over once an authoritative read has said what it did, which is where the
    /// new upstream comes from.
    @Test
    @MainActor
    func asuccessfulPublishReloadsTheRepositoryAndReportsTheNewUpstream() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [
                repositoryURL: [pushRepository(upstream: nil), pushRepository(ahead: 0)],
            ]
        )
        let state = await workspace(stub)
        #expect(state.repository?.upstream == nil)

        await state.beginPush()

        #expect(state.repositoryFailure == nil)
        #expect(state.repository?.upstream?.name == "origin/main")
        #expect(!state.isPushing)
    }

    /// Nothing about a Push is a Fetch, so the app-owned last-Fetch time is left exactly as it
    /// was rather than dated against work that never arrived.
    @Test
    @MainActor
    func nopublishEverRecordsAlastFetchTime() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [
                repositoryURL: [pushRepository(upstream: nil), pushRepository(ahead: 0)],
            ]
        )
        let state = await workspace(stub)

        await state.beginPush()

        #expect(state.lastFetchDate == nil)
    }

    /// Colofa contacts a remote only when the user asks, and a Publish is no exception.
    @Test
    @MainActor
    func neverPublishesWithoutBeingAsked() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [pushRepository(upstream: nil)]]
        )
        let state = await workspace(stub)

        await state.start()
        await state.refresh()

        #expect(await stub.recordedNetworkMutations().isEmpty)
    }
}
