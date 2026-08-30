////
//  WorkspaceStatePushTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// Store-level behaviour of Push: what the confirmation shows, what a normal Push runs, what a
/// Force Push with Lease supplies, and how each refusal is told apart from the others.
@Suite(.serialized)
final class WorkspaceStatePushTests {
    private let defaults: UserDefaults
    private let suiteName = "com.anemoris.Colofa.WorkspaceStatePushTests"
    private let repositoryURL = pushRepositoryURL

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    @MainActor
    private func workspace(_ stub: RepositoryServiceStub) async -> WorkspaceState {
        await pushWorkspace(stub, at: repositoryURL, defaults: defaults)
    }

    private func stub(
        _ extra: RepositoryOpenError? = nil,
        target: PushTarget? = pushTarget(),
        remoteObjectID: String? = nil
    ) -> RepositoryServiceStub {
        RepositoryServiceStub(
            snapshots: [repositoryURL: [pushRepository(), pushRepository(ahead: 0)]],
            networkMutationError: extra,
            pushTarget: target,
            remoteObjectID: remoteObjectID
        )
    }

    // MARK: - The confirmation

    /// Pressing Push sends nothing: it shows where the Push is about to go, which is the whole
    /// reason a confirmation exists.
    @Test
    @MainActor
    func pressingPushOpensAconfirmationAndSendsNothing() async throws {
        let fixture = stub()
        let state = await workspace(fixture)

        await state.beginPush()

        #expect(state.isConfirmingPush)
        #expect(state.pushDialog?.confirmation?.branch == "main")
        #expect(state.pushDialog?.confirmation?.target.upstream == "origin/main")
        #expect(await fixture.recordedNetworkMutations().isEmpty)
    }

    /// The expected object is captured when the dialog opens, because that is what makes a lease
    /// describe the remote the user was actually looking at.
    @Test
    @MainActor
    func theConfirmationCapturesTheExpectedRemoteObject() async throws {
        let fixture = stub()
        let state = await workspace(fixture)

        await state.beginPush()

        #expect(state.pushDialog?.confirmation?.target.expectedObjectID == pushExpectedObjectID)
        #expect(state.pushDialog?.confirmation?.canForceWithLease == true)
        #expect(await fixture.recordedPushTargetRequests().map(\.branch) == ["main"])
    }

    @Test
    @MainActor
    func cancellingTheConfirmationPushesNothing() async throws {
        let fixture = stub()
        let state = await workspace(fixture)
        await state.beginPush()

        state.cancelPushConfirmation()

        #expect(state.pushDialog == nil)
        #expect(await fixture.recordedNetworkMutations().isEmpty)
    }

    /// A read that itself failed says so rather than opening a dialog about a destination nobody
    /// established.
    @Test
    @MainActor
    func areadThatFailedOpensNoConfirmation() async throws {
        let fixture = RepositoryServiceStub(
            snapshots: [repositoryURL: [pushRepository()]],
            pushTargetError: .commandFailed(
                GitFailureDetails(command: "git for-each-ref", output: "fatal", exitStatus: 128)
            )
        )
        let state = await workspace(fixture)

        await state.beginPush()

        #expect(state.pushDialog == nil)
        #expect(state.repositoryFailure != nil)
        #expect(await fixture.recordedNetworkMutations().isEmpty)
    }

    /// A snapshot can name an upstream that Git no longer has, and pressing Push must not then
    /// do nothing at all. Publishing is what resolves it, and it still says where it is going.
    @Test
    @MainActor
    func anupstreamGitNoLongerReportsFallsBackToPublishingRatherThanDoingNothing() async throws {
        let fixture = RepositoryServiceStub(
            snapshots: [
                repositoryURL: [
                    pushRepository(remotes: ["origin", "mirror"]),
                    pushRepository(ahead: 0),
                ],
            ],
            pushTarget: nil
        )
        let state = await workspace(fixture)

        await state.beginPush()

        #expect(state.isChoosingPublishRemote, "Pressing Push left the user with nothing at all")
        #expect(await fixture.recordedNetworkMutations().isEmpty)
    }

    // MARK: - Pushing

    /// Confirming runs exactly the command the dialog described, with no force of any kind.
    @Test
    @MainActor
    func confirmingRunsAnormalPushToTheExactUpstream() async throws {
        let fixture = stub()
        let state = await workspace(fixture)
        await state.beginPush()

        await state.confirmPush()

        #expect(
            await fixture.recordedNetworkMutations()
                == [PushCommand.push("main", to: pushTarget(), lease: nil)]
        )
        #expect(state.repositoryFailure == nil)
        #expect(state.repository?.upstream?.ahead == 0, "The Push never reloaded the Repository")
        #expect(!state.isPushing)
    }

    /// Ticking the box is what turns one Push into a force, and the lease it carries is the exact
    /// object read before the dialog opened.
    @Test
    @MainActor
    func tickingForcePushWithLeaseSuppliesTheCapturedObject() async throws {
        let fixture = stub(remoteObjectID: pushExpectedObjectID)
        let state = await workspace(fixture)
        await state.beginPush()

        state.pushDialog?.confirmation?.forcesWithLease = true
        await state.confirmPush()

        let commands = await fixture.recordedNetworkMutations()
        #expect(
            commands == [
                PushCommand.push("main", to: pushTarget(), lease: pushExpectedObjectID),
            ]
        )
        #expect(state.repositoryFailure == nil)
    }

    /// The lease is the whole protection: a remote that moved after the confirmation opened is
    /// refused rather than overwritten, and the refusal is its own answer.
    @Test
    @MainActor
    func aremoteThatMovedAfterConfirmationRejectsTheLeaseRatherThanBeingOverwritten() async throws {
        let fixture = stub(remoteObjectID: "fedcba9876543210fedcba9876543210fedcba98")
        let state = await workspace(fixture)
        await state.beginPush()

        state.pushDialog?.confirmation?.forcesWithLease = true
        await state.confirmPush()

        let failure = try #require(state.repositoryFailure)
        guard case .pushRejectedAlert(let rejection, _, let upstream, _) = failure else {
            Issue.record("A refused lease was not reported as one")
            return
        }
        #expect(rejection == .staleLease)
        #expect(upstream == "origin/main")
        #expect(state.canShowRepositoryFailureDetails, "Git's own words were not offered")
    }

    /// Nothing ever leaves for the remote spelling force without a value behind it.
    @Test
    @MainActor
    func nopushEverCarriesAnakedForce() async throws {
        let fixture = stub(remoteObjectID: pushExpectedObjectID)
        let state = await workspace(fixture)
        await state.beginPush()
        state.pushDialog?.confirmation?.forcesWithLease = true
        await state.confirmPush()

        for command in await fixture.recordedNetworkMutations() {
            #expect(!command.contains("--force"))
            #expect(!command.contains("-f"))
            #expect(!command.contains("--force-with-lease"))
        }
    }

    // MARK: - Telling the refusals apart

    /// The upstream holding work this Branch does not is the one refusal the user acts on by
    /// integrating first, and it is never reported as a connection that failed.
    @Test
    @MainActor
    func anonFastForwardRefusalIsReportedAsPushRejected() async throws {
        let fixture = stub(
            .commandFailed(
                GitFailureDetails(
                    command: "git push",
                    output: "!\trefs/heads/main:refs/heads/main\t[rejected] (fetch first)",
                    exitStatus: 1
                )
            )
        )
        let state = await workspace(fixture)
        await state.beginPush()

        await state.confirmPush()

        guard case .pushRejectedAlert(let rejection, let branch, _, _) = state.repositoryFailure else {
            Issue.record("A refused Push was not reported as one")
            return
        }
        #expect(rejection == .nonFastForward)
        #expect(branch == "main")
    }

    /// A connection that was never authenticated says nothing about whether the update would have
    /// been accepted, so it is never reported as a rejection.
    @Test
    @MainActor
    func anauthenticationFailureIsToldApartFromPushRejected() async throws {
        let fixture = stub(
            .commandFailed(
                GitFailureDetails(
                    command: "git push",
                    output: RepositoryServiceStub.declinedAuthenticationOutput,
                    exitStatus: 128
                )
            )
        )
        let state = await workspace(fixture)
        await state.beginPush()

        await state.confirmPush()

        guard case .authenticationAlert(let failure, _) = state.repositoryFailure else {
            Issue.record("An unauthenticated Push was not reported as one")
            return
        }
        #expect(failure == .declinedCredentials)
    }

    /// A remote nobody could reach is neither of the two, and its own words are all there is.
    @Test
    @MainActor
    func atransportFailureIsToldApartFromBothOfThem() async throws {
        let fixture = stub(
            .commandFailed(
                GitFailureDetails(
                    command: "git push",
                    output: "fatal: unable to access 'https://example.invalid/': Could not resolve host",
                    exitStatus: 128
                )
            )
        )
        let state = await workspace(fixture)
        await state.beginPush()

        await state.confirmPush()

        guard case .mutationAlert(_, let title) = state.repositoryFailure else {
            Issue.record("A transport failure was reported as something more specific")
            return
        }
        var titled = title
        titled.locale = Locale(identifier: "en")
        #expect(String(localized: titled) == "Push Failed")
    }

    /// A Push asks for a secret the same way every command that contacts a remote does, and
    /// refusing the question stops it rather than letting it fail on its own.
    @Test
    @MainActor
    func asksForAsecretThroughTheEstablishedRequestAndStopsWhenItIsRefused() async throws {
        let fixture = RepositoryServiceStub(
            snapshots: [repositoryURL: [pushRepository()]],
            authenticationPrompts: ["Password for 'https://octocat@example.invalid': "],
            pushTarget: pushTarget()
        )
        let state = await workspace(fixture)
        await state.beginPush()

        let pushing = Task { await state.confirmPush() }
        try await waitForFetch(
            { state.authenticationRequest != nil },
            "The Push never asked for anything"
        )
        #expect(state.authenticationRequest?.kind == .password)
        state.cancelAuthentication()
        await pushing.value

        #expect(state.repositoryFailure == nil, "A Cancel the user pressed was reported as one")
    }
}
