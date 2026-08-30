////
//  WorkspaceStatePushDestinationTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// Store-level behaviour of the one thing a remote name cannot establish: where a Push actually
/// writes to.
///
/// A remote name is resolved by Git when the command runs, so a confirmation showing `origin/main`
/// has shown a name rather than a destination. These cover the configurations where that name
/// resolves to something no single confirmation can describe, and the check that the address has
/// not moved between the confirmation opening and its button being pressed.
@Suite(.serialized)
final class WorkspaceStatePushDestinationTests {
    private let defaults: UserDefaults
    private let suiteName = "com.anemoris.Colofa.WorkspaceStatePushDestinationTests"
    private let repositoryURL = pushRepositoryURL

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    @MainActor
    private func workspace(_ stub: RepositoryServiceStub) async -> WorkspaceState {
        await pushWorkspace(stub, at: repositoryURL, defaults: defaults)
    }

    private func refusal(of failure: RepositoryFailurePresentation?) -> PushDestinationRefusal? {
        guard case .pushDestinationAlert(let refusal) = failure else {
            return nil
        }
        return refusal
    }

    // MARK: - The address the confirmation shows

    /// The confirmation captures the address, not only the name, because the name is what Git
    /// resolves again later.
    @Test
    @MainActor
    func theConfirmationCapturesTheAddressTheRemoteResolvesTo() async throws {
        let fixture = RepositoryServiceStub(
            snapshots: [repositoryURL: [pushRepository()]],
            pushTarget: pushTarget()
        )
        let state = await workspace(fixture)

        await state.beginPush()

        #expect(state.pushDialog?.confirmation?.destination == pushDestination())
        #expect(await fixture.recordedPushDestinationRequests().map(\.remote) == ["origin"])
    }

    // MARK: - Destinations no confirmation can describe

    /// `.` is Git's own name for this Repository, and `git branch --track <new> <local>` is all it
    /// takes to configure it. A Push to it rewrites a local Branch, which is not what the word
    /// Push promises anywhere in this dialog.
    @Test
    @MainActor
    func aremoteThatIsThisRepositoryIsRefusedBeforeAnythingIsSent() async throws {
        let fixture = RepositoryServiceStub(
            snapshots: [repositoryURL: [pushRepository()]],
            pushTarget: pushTarget(remote: ".", upstream: "localbase"),
            pushDestinationError: PushDestinationRefusal.localRepository(remote: ".")
        )
        let state = await workspace(fixture)

        await state.beginPush()

        #expect(state.pushDialog == nil, "A destination Colofa refuses was confirmed anyway")
        #expect(refusal(of: state.repositoryFailure) == .localRepository(remote: "."))
        #expect(await fixture.recordedNetworkMutations().isEmpty)
    }

    /// One Push writes to every configured push address in turn. A confirmation naming one of them
    /// would be naming a fraction of what happens, and a Force Push accepted at one address and
    /// refused at another cannot be rolled back as a whole.
    @Test
    @MainActor
    func aremoteWithSeveralPushAddressesIsRefusedBeforeAnythingIsSent() async throws {
        let destinations = [
            PushDestination("ssh://example.invalid/Colofa.git"),
            PushDestination("ssh://example.invalid/Mirror.git"),
        ]
        let fixture = RepositoryServiceStub(
            snapshots: [repositoryURL: [pushRepository()]],
            pushTarget: pushTarget(),
            pushDestinationError: PushDestinationRefusal.severalDestinations(
                remote: "origin",
                destinations
            )
        )
        let state = await workspace(fixture)

        await state.beginPush()

        #expect(state.pushDialog == nil)
        #expect(
            refusal(of: state.repositoryFailure)
                == .severalDestinations(remote: "origin", destinations)
        )
        #expect(await fixture.recordedNetworkMutations().isEmpty)
    }

    /// Publish writes to a remote too, and it opens no confirmation when the answer is
    /// unambiguous — so the same check has to stand in front of it.
    @Test
    @MainActor
    func publishIsRefusedForAdestinationNoConfirmationCouldDescribe() async throws {
        let fixture = RepositoryServiceStub(
            snapshots: [repositoryURL: [pushRepository(upstream: nil)]],
            pushTarget: nil,
            pushDestinationError: PushDestinationRefusal.localRepository(remote: "origin")
        )
        let state = await workspace(fixture)

        await state.beginPush()

        #expect(refusal(of: state.repositoryFailure) == .localRepository(remote: "origin"))
        #expect(await fixture.recordedNetworkMutations().isEmpty)
    }

    /// A refusal is not a command that failed. Nothing ran, so there is no Git output to expand,
    /// and the alert must not offer one.
    @Test
    @MainActor
    func arefusedDestinationOffersNoGitOutputToRead() async throws {
        let fixture = RepositoryServiceStub(
            snapshots: [repositoryURL: [pushRepository()]],
            pushTarget: pushTarget(),
            pushDestinationError: PushDestinationRefusal.localRepository(remote: ".")
        )
        let state = await workspace(fixture)

        await state.beginPush()

        #expect(state.isShowingRepositoryMutationError)
        #expect(!state.canShowRepositoryFailureDetails)
        #expect(state.repositoryFailureDetails == nil)
    }

    /// A read that failed for its own reasons is still a failed read, not a destination Colofa
    /// refuses — the two say different things and the user does different things about them.
    @Test
    @MainActor
    func areadThatFailedIsReportedAsAfailureRatherThanArefusal() async throws {
        let fixture = RepositoryServiceStub(
            snapshots: [repositoryURL: [pushRepository()]],
            pushTarget: pushTarget(),
            pushDestinationError: RepositoryOpenError.gitUnavailable
        )
        let state = await workspace(fixture)

        await state.beginPush()

        #expect(refusal(of: state.repositoryFailure) == nil)
        #expect(state.isShowingRepositoryMutationError)
    }

    // MARK: - The address moving under an open confirmation

    /// The address is read again immediately before the command runs. A remote rebound while the
    /// dialog was open would otherwise send the confirmed Ref to an address nobody confirmed.
    @Test
    @MainActor
    func aremoteReboundUnderTheOpenConfirmationSendsNothing() async throws {
        let fixture = RepositoryServiceStub(
            snapshots: [repositoryURL: [pushRepository(), pushRepository(ahead: 0)]],
            pushTarget: pushTarget(),
            pushDestinations: [
                "origin": [
                    PushDestination("ssh://example.invalid/Colofa.git"),
                    PushDestination("ssh://elsewhere.invalid/Colofa.git"),
                ],
            ]
        )
        let state = await workspace(fixture)
        await state.beginPush()
        #expect(state.isConfirmingPush)

        await state.confirmPush()

        #expect(await fixture.recordedNetworkMutations().isEmpty)
        #expect(state.pushDialog == nil)
        #expect(refusal(of: state.repositoryFailure) == .changed(remote: "origin"))
    }

    /// The check is a comparison, not a second opinion: an address that did not move lets the
    /// Push it was confirmed for run.
    @Test
    @MainActor
    func anaddressThatDidNotMoveLetsThePushRun() async throws {
        let fixture = RepositoryServiceStub(
            snapshots: [repositoryURL: [pushRepository(), pushRepository(ahead: 0)]],
            pushTarget: pushTarget()
        )
        let state = await workspace(fixture)
        await state.beginPush()

        await state.confirmPush()

        #expect(state.repositoryFailure == nil)
        #expect(await fixture.recordedNetworkMutations().count == 1)
        #expect(await fixture.recordedPushDestinationRequests().count == 2)
    }
}
