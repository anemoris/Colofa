////
//  WorkspaceStatePushSecurityTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// What a Push must never keep or repeat back.
///
/// A Push is the one ordinary command that both writes to a remote and can be asked for a secret,
/// so the two things it must not do sit together: it must not carry what was typed in anything it
/// describes, and it must not leave it anywhere afterwards.
@Suite(.serialized)
final class WorkspaceStatePushSecurityTests {
    private let defaults: UserDefaults
    private let suiteName = "com.anemoris.Colofa.WorkspaceStatePushSecurityTests"
    private let repositoryURL = pushRepositoryURL
    private static let secret = "ghp_ColofaPushFixtureToken"
    private static let prompt = "Password for 'https://octocat@example.invalid': "

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    @MainActor
    private func pushAnswering(_ stub: RepositoryServiceStub) async throws -> WorkspaceState {
        let state = await pushWorkspace(stub, at: repositoryURL, defaults: defaults)
        await state.beginPush()

        let pushing = Task { await state.confirmPush() }
        try await waitForFetch(
            { state.authenticationRequest != nil },
            "The Push never asked for anything"
        )
        state.authenticationAnswer = Self.secret
        state.submitAuthentication()
        await pushing.value
        return state
    }

    private func stub() -> RepositoryServiceStub {
        RepositoryServiceStub(
            snapshots: [repositoryURL: [pushRepository(), pushRepository(ahead: 0)]],
            authenticationPrompts: [Self.prompt],
            pushTarget: pushTarget()
        )
    }

    /// What Colofa asks Git is echoed back in sanitized failure details, so an answer given
    /// halfway through must never have been part of it.
    @Test
    @MainActor
    func theAnswerNeverTravelsInTheCommandItself() async throws {
        let fixture = stub()
        _ = try await pushAnswering(fixture)

        for command in await fixture.recordedNetworkMutations() {
            #expect(!command.contains(Self.secret))
            #expect(!command.contains { $0.localizedStandardContains("octocat") })
        }
    }

    /// The answer lives for as long as the field is on screen and no longer, whatever the Push
    /// went on to do.
    @Test
    @MainActor
    func theAnswerIsClearedInTheSameStepThatHandsItOver() async throws {
        let state = try await pushAnswering(stub())

        #expect(state.authenticationRequest == nil)
        #expect(state.authenticationAnswer.isEmpty)
        #expect(state.pendingAuthentication == nil)
    }

    /// Colofa is not a credential store, and a Push does not become one by succeeding.
    @Test
    @MainActor
    func nothingAboutTheQuestionOrItsAnswerReachesTheAppsOwnDefaults() async throws {
        _ = try await pushAnswering(stub())

        let stored = String(describing: defaults.dictionaryRepresentation())
        #expect(!stored.contains(Self.secret))
        #expect(!stored.contains("octocat"))
        #expect(!stored.contains("Password for"))
    }

    /// A Push that failed shows Git's own words, and an answer given to it may not be among them.
    @Test
    @MainActor
    func theAnswerNeverAppearsInWhatArefusedPushReportsBack() async throws {
        let fixture = RepositoryServiceStub(
            snapshots: [repositoryURL: [pushRepository(), pushRepository()]],
            networkMutationError: .commandFailed(
                GitFailureDetails(
                    command: "git push",
                    output: "!\trefs/heads/main:refs/heads/main\t[rejected] (fetch first)",
                    exitStatus: 1
                )
            ),
            authenticationPrompts: [Self.prompt],
            pushTarget: pushTarget()
        )
        let state = try await pushAnswering(fixture)

        let reported = String(describing: state.repositoryFailure)
        #expect(!reported.contains(Self.secret))
        #expect(!reported.contains("Password for"))
    }
}
