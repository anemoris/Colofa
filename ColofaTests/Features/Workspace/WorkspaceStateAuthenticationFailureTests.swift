////
//  WorkspaceStateAuthenticationFailureTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation
import Testing
@testable import Colofa

/// What the Store says about a command that failed over the connection's identity rather than
/// over what it was asked to do.
///
/// Kept apart from the prompt's own behaviour because these never reach a prompt at all: they are
/// what the user is told once Git has already refused.
@Suite(.serialized)
final class WorkspaceStateAuthenticationFailureTests {
    private let defaults: UserDefaults
    private let suiteName = "com.anemoris.Colofa.WorkspaceStateAuthenticationFailureTests"
    private let repositoryURL = fetchRepositoryURL

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    @MainActor
    private func workspace(_ stub: RepositoryServiceStub) async -> WorkspaceState {
        await fetchWorkspace(stub, at: repositoryURL, defaults: defaults)
    }

    private func stub(
        prompts: [String],
        failureOutput: String = RepositoryServiceStub.declinedAuthenticationOutput
    ) -> RepositoryServiceStub {
        RepositoryServiceStub(
            snapshots: [repositoryURL: [fetchRepository(remotes: ["origin"])]],
            authenticationPrompts: prompts,
            authenticationFailureOutput: failureOutput
        )
    }

    /// A host whose key changed is refused without an override anywhere in the app, and the
    /// refusal says so rather than reading as a remote that could not be reached.
    @Test
    @MainActor
    func explainsAChangedHostKeyRatherThanOfferingAWayPastIt() async throws {
        let stub = stub(
            prompts: [
                """
                @    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @
                Are you sure you want to continue connecting (yes/no/[fingerprint])?
                """,
            ],
            failureOutput: """
                @    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @
                Host key verification failed.
                fatal: Could not read from remote repository.
                """
        )
        let state = await workspace(stub)

        await state.fetch()

        #expect(state.authenticationRequest == nil, "A changed host key was put to the user")
        #expect(await stub.recordedAuthenticationResponses().isEmpty)
        #expect(state.repositoryFailureTitle == .authenticationHostKeyChangedTitle)
        #expect(state.repositoryFailureMessage == .authenticationHostKeyChangedMessage)
        #expect(state.canShowRepositoryFailureDetails)
        #expect(state.lastFetchDate == nil)
    }

    /// A host that was never confirmed is a different refusal from one that changed, and says so.
    @Test
    @MainActor
    func explainsAHostThatWasNeverConfirmed() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [fetchRepository(remotes: ["origin"])]],
            failingRemotes: ["origin"],
            networkFailureOutput: """
                Host key verification failed.
                fatal: Could not read from remote repository.
                """
        )
        let state = await workspace(stub)

        await state.fetch()

        #expect(state.repositoryFailureTitle == .authenticationHostKeyUnverifiedTitle)
        #expect(state.repositoryFailureMessage == .authenticationHostKeyUnverifiedMessage)
    }

    /// The one thing redaction must not take with it. Every question is removed from what a
    /// command reports, so nothing in the output of a refused connection says what it was about
    /// any more — and the refusal still has to be explained as the one it was.
    @Test
    @MainActor
    func explainsARefusalWhoseOutputNoLongerSaysWhatItWasAbout() async throws {
        let stub = stub(
            prompts: [
                """
                @    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @
                Are you sure you want to continue connecting (yes/no/[fingerprint])?
                """,
            ],
            failureOutput: "fatal: Could not read from remote repository."
        )
        let state = await workspace(stub)

        await state.fetch()

        #expect(
            AuthenticationFailure.detect(in: "fatal: Could not read from remote repository.") == nil,
            "The output still said what it was about, so this proves nothing"
        )
        #expect(state.repositoryFailureTitle == .authenticationHostKeyChangedTitle)
        #expect(state.repositoryFailureMessage == .authenticationHostKeyChangedMessage)
    }

    /// A remote nobody could reach is still reported as a Fetch that failed, not dressed up as
    /// an authentication problem it was not.
    @Test
    @MainActor
    func leavesAnOrdinaryFetchFailureAlone() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [fetchRepository(remotes: ["origin"])]],
            failingRemotes: ["origin"]
        )
        let state = await workspace(stub)

        await state.fetch()

        #expect(state.repositoryFailureTitle == .fetchFailed)
    }
}
