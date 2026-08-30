////
//  WorkspaceStatePushStalenessTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// What happens to an open Push or Publish dialog when the Repository is read again underneath it.
///
/// A dialog outlives a reload — the window becoming active causes one — so it has to be checked
/// against what is there now rather than trusted. The line these tests draw is between a reload
/// that changed nothing, which must leave the dialog alone, and one that changed what the dialog
/// showed, which must close it and say so.
@Suite(.serialized)
final class WorkspaceStatePushStalenessTests {
    private let defaults: UserDefaults
    private let suiteName = "com.anemoris.Colofa.WorkspaceStatePushStalenessTests"
    private let repositoryURL = pushRepositoryURL

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    @MainActor
    private func workspace(_ stub: RepositoryServiceStub) async -> WorkspaceState {
        await pushWorkspace(stub, at: repositoryURL, defaults: defaults)
    }

    private func stub() -> RepositoryServiceStub {
        RepositoryServiceStub(
            snapshots: [repositoryURL: [pushRepository(), pushRepository(ahead: 0)]],
            pushTarget: pushTarget()
        )
    }

    /// A Repository whose Branch moves on the second read, which is what an external Commit or
    /// reset looks like to a dialog that is already open.
    private func movedBranchStub() -> RepositoryServiceStub {
        RepositoryServiceStub(
            snapshots: [
                repositoryURL: [
                    pushRepository(),
                    pushRepository(headObjectID: "a commit made since"),
                ],
            ],
            pushTarget: pushTarget(),
            remoteObjectID: pushExpectedObjectID
        )
    }

    /// The window becoming active reloads the Repository, and a confirmation that closed every
    /// time one happened would be unusable. Nothing changed, so nothing closes.
    @Test
    @MainActor
    func areloadThatChangedNothingLeavesTheConfirmationOpen() async throws {
        let fixture = stub()
        let state = await workspace(fixture)
        await state.beginPush()

        await state.refresh()

        #expect(state.isConfirmingPush)
        #expect(!state.isShowingStalePushAlert)
    }

    /// The Branch is the first thing the dialog shows. Once the Repository is on another one, the
    /// dialog is describing a Push nobody asked for, so it goes — and says why rather than
    /// vanishing as though the user had dismissed it.
    @Test
    @MainActor
    func abranchThatChangedUnderThedialogClosesItAndSaysSo() async throws {
        let fixture = RepositoryServiceStub(
            snapshots: [
                repositoryURL: [pushRepository(), pushRepository(head: .branch("other"))],
            ],
            pushTarget: pushTarget()
        )
        let state = await workspace(fixture)
        await state.beginPush()

        await state.refresh()

        #expect(state.pushDialog == nil)
        #expect(state.isShowingStalePushAlert)
        await state.confirmPush()
        #expect(await fixture.recordedNetworkMutations().isEmpty)
    }

    /// A Commit made while the dialog was open does not invalidate an ordinary Push: the remote
    /// refuses anything that is no longer a fast-forward, so there is nothing here to protect and
    /// closing the dialog would only be in the way.
    @Test
    @MainActor
    func anordinaryPushSurvivesAcommitMadeUnderThedialog() async throws {
        let state = await workspace(movedBranchStub())
        await state.beginPush()

        await state.refresh()

        #expect(state.isConfirmingPush)
        #expect(!state.isShowingStalePushAlert)
    }

    /// A force has no such refusal on the local side. The history it would install at the
    /// upstream is only the history the box was ticked against for as long as the Branch has not
    /// moved, so a Branch that moved closes the dialog rather than replacing the remote with
    /// something the user never saw.
    @Test
    @MainActor
    func aforceStopsOnceTheBranchMovedUnderThedialog() async throws {
        let state = await workspace(movedBranchStub())
        await state.beginPush()
        state.pushDialog?.confirmation?.forcesWithLease = true

        await state.refresh()

        #expect(state.pushDialog == nil)
        #expect(state.isShowingStalePushAlert)
    }

    /// Ticking the box after the reload is the same danger arriving in the other order, so the
    /// confirmation itself checks rather than trusting that a reload has already been through.
    @Test
    @MainActor
    func tickingTheBoxAfterAreloadIsCheckedAtTheConfirmationItself() async throws {
        let fixture = movedBranchStub()
        let state = await workspace(fixture)
        await state.beginPush()
        await state.refresh()
        #expect(state.isConfirmingPush, "An ordinary Push should have survived the reload")

        state.pushDialog?.confirmation?.forcesWithLease = true
        await state.confirmPush()

        #expect(state.pushDialog == nil)
        #expect(state.isShowingStalePushAlert)
        #expect(await fixture.recordedNetworkMutations().isEmpty)
    }

    /// The Publish dialog assumes the remote it offers still exists. One removed under it makes
    /// the selection unpublishable, so the question is asked again rather than answered wrongly.
    @Test
    @MainActor
    func aremoteRemovedUnderThePublishdialogClosesIt() async throws {
        let fixture = RepositoryServiceStub(
            snapshots: [
                repositoryURL: [
                    pushRepository(upstream: nil, remotes: ["origin", "mirror"]),
                    pushRepository(upstream: nil, remotes: ["origin"]),
                ],
            ],
            pushTarget: nil
        )
        let state = await workspace(fixture)
        await state.beginPush()
        state.pushDialog?.publishRemote?.selectedRemote = "mirror"

        await state.refresh()

        #expect(state.pushDialog == nil)
        #expect(state.isShowingStalePushAlert)
        await state.confirmPublishRemote()
        #expect(await fixture.recordedNetworkMutations().isEmpty)
    }
}
