////
//  WorkspaceStateAuthenticationTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation
import Testing
@testable import Colofa

/// Store-level behaviour of an Authentication Request: what appears while a command waits, what
/// the answer does, what cancelling does to the command that asked, and what is left behind
/// afterwards — which must be nothing.
@Suite(.serialized)
final class WorkspaceStateAuthenticationTests {
    private let defaults: UserDefaults
    private let suiteName = "com.anemoris.Colofa.WorkspaceStateAuthenticationTests"
    private let repositoryURL = fetchRepositoryURL

    private static let passwordPrompt = "Password for 'https://octocat@example.invalid': "
    private static let usernamePrompt = "Username for 'https://example.invalid': "
    private static let passphrasePrompt = "Enter passphrase for key '/keys/id_ed25519': "
    private static let secret = "ghp_ColofaFixtureToken"

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

    // MARK: - Asking

    /// Nothing is on screen until Git asks, and what it asked is what the prompt reports.
    @Test
    @MainActor
    func showsTheQuestionGitAskedWhileTheCommandWaits() async throws {
        let stub = stub(prompts: [Self.passwordPrompt])
        let state = await workspace(stub)
        #expect(state.authenticationRequest == nil)

        let fetching = Task { await state.fetch() }
        try await waitForFetch(
            { state.authenticationRequest != nil },
            "The Fetch never asked for anything"
        )

        let request = try #require(state.authenticationRequest)
        #expect(request.kind == .password)
        #expect(request.subject == "https://octocat@example.invalid")
        #expect(state.isPresentingAuthenticationRequest)
        #expect(state.isFetching)

        state.cancelAuthentication()
        await fetching.value
    }

    /// A username is the one answer that has to be something, because Git refuses an empty one
    /// itself and asking twice is worse than not accepting it here.
    @Test
    @MainActor
    func requiresAnAccountNameButAcceptsAnEmptySecret() async throws {
        let stub = stub(prompts: [Self.usernamePrompt])
        let state = await workspace(stub)

        let fetching = Task { await state.fetch() }
        try await waitForFetch({ state.authenticationRequest != nil }, "Nothing was asked")

        #expect(!state.canSubmitAuthentication)
        state.authenticationAnswer = "   "
        #expect(!state.canSubmitAuthentication)
        state.authenticationAnswer = "octocat"
        #expect(state.canSubmitAuthentication)

        state.submitAuthentication()
        await fetching.value

        #expect(await stub.recordedAuthenticationResponses() == [.answer("octocat")])
    }

    // MARK: - Answering

    /// The answer reaches the command that asked, and the Fetch it was blocking finishes.
    @Test
    @MainActor
    func handsTheAnswerToTheCommandThatAskedForIt() async throws {
        let stub = stub(prompts: [Self.passwordPrompt])
        let state = await workspace(stub)

        let fetching = Task { await state.fetch() }
        try await waitForFetch({ state.authenticationRequest != nil }, "Nothing was asked")
        state.authenticationAnswer = Self.secret
        state.submitAuthentication()
        await fetching.value

        #expect(await stub.recordedAuthenticationResponses() == [.answer(Self.secret)])
        #expect(state.repositoryFailure == nil)
        #expect(state.lastFetchDate != nil)
    }

    /// A host key is agreed to rather than typed into, and OpenSSH reads the literal word.
    @Test
    @MainActor
    func answersAHostKeyQuestionWithOpenSSHsOwnWord() async throws {
        let stub = stub(
            prompts: [
                """
                The authenticity of host 'example.invalid (203.0.113.9)' can't be established.
                ED25519 key fingerprint is SHA256:abcdef.
                Are you sure you want to continue connecting (yes/no/[fingerprint])?
                """,
            ]
        )
        let state = await workspace(stub)

        let fetching = Task { await state.fetch() }
        try await waitForFetch({ state.authenticationRequest != nil }, "Nothing was asked")

        #expect(state.authenticationRequest?.fingerprint == "SHA256:abcdef")
        #expect(state.canSubmitAuthentication)
        state.submitAuthentication()
        await fetching.value

        #expect(await stub.recordedAuthenticationResponses() == [.answer("yes")])
    }

    /// The prompt goes away and what was typed goes with it, whichever way it ended.
    @Test
    @MainActor
    func clearsWhatWasTypedTheMomentTheQuestionIsAnswered() async throws {
        let stub = stub(prompts: [Self.passwordPrompt])
        let state = await workspace(stub)

        let fetching = Task { await state.fetch() }
        try await waitForFetch({ state.authenticationRequest != nil }, "Nothing was asked")
        state.authenticationAnswer = Self.secret
        state.submitAuthentication()

        #expect(state.authenticationRequest == nil)
        #expect(state.authenticationAnswer.isEmpty)
        #expect(!state.isPresentingAuthenticationRequest)
        await fetching.value
    }

    // MARK: - Cancelling

    /// Cancelling the prompt cancels the command it belongs to, so nothing is left blocked on an
    /// answer that will never arrive — and a Cancel is not reported as a failure.
    @Test
    @MainActor
    func cancellingTheQuestionCancelsTheCommandThatAskedIt() async throws {
        let stub = stub(prompts: [Self.passwordPrompt])
        let state = await workspace(stub)

        let fetching = Task { await state.fetch() }
        try await waitForFetch({ state.authenticationRequest != nil }, "Nothing was asked")
        state.authenticationAnswer = Self.secret
        state.cancelAuthentication()
        await fetching.value

        #expect(await stub.recordedAuthenticationResponses() == [.cancelled])
        #expect(state.authenticationRequest == nil)
        #expect(state.authenticationAnswer.isEmpty)
        #expect(!state.isFetching)
        #expect(state.repositoryFailure == nil)
        #expect(state.lastFetchDate == nil)
    }

    /// Dismissing the sheet is the same decision as pressing Cancel.
    @Test
    @MainActor
    func dismissingTheSheetCancelsTheCommandTheSameWay() async throws {
        let stub = stub(prompts: [Self.passwordPrompt])
        let state = await workspace(stub)

        let fetching = Task { await state.fetch() }
        try await waitForFetch({ state.authenticationRequest != nil }, "Nothing was asked")
        state.isPresentingAuthenticationRequest = false
        await fetching.value

        #expect(await stub.recordedAuthenticationResponses() == [.cancelled])
        #expect(!state.isFetching)
    }

    /// A command stopped from anywhere else takes its prompt with it: nothing may be left on
    /// screen waiting for an answer nobody is waiting for.
    @Test
    @MainActor
    func takesThePromptDownWhenTheOperationEndsUnderneathIt() async throws {
        let stub = stub(prompts: [Self.passphrasePrompt])
        let state = await workspace(stub)

        let fetching = Task { await state.fetch() }
        try await waitForFetch({ state.authenticationRequest != nil }, "Nothing was asked")
        state.cancelFetch()
        await fetching.value

        #expect(state.authenticationRequest == nil)
        #expect(state.pendingAuthentication == nil)
        #expect(!state.isFetching)
    }

    // MARK: - One question at a time

    /// An answer belongs to the prompt it was typed into. A second question arriving while one is
    /// open is refused rather than shown, so no answer can be consumed by the wrong asker.
    @Test
    @MainActor
    func refusesASecondQuestionWhileOneIsAlreadyOpen() async throws {
        let stub = stub(prompts: [Self.passwordPrompt])
        let state = await workspace(stub)

        let fetching = Task { await state.fetch() }
        try await waitForFetch({ state.authenticationRequest != nil }, "Nothing was asked")
        let open = try #require(state.authenticationRequest)

        let intruder = AuthenticationRequest(
            kind: .password,
            subject: "https://elsewhere.invalid",
            prompt: "Password for 'https://elsewhere.invalid': "
        )
        let refused = await state.authenticationResponder.respond(intruder)

        #expect(refused == .cancelled)
        #expect(state.authenticationRequest?.id == open.id)

        state.cancelAuthentication()
        await fetching.value
    }

    /// A refused question belongs to no prompt, so the command it belonged to ending must not
    /// take the prompt somebody else is answering down with it.
    @Test
    @MainActor
    func aRefusedQuestionEndingDoesNotCloseThePromptThatIsOpen() async throws {
        let stub = stub(prompts: [Self.passwordPrompt])
        let state = await workspace(stub)

        let fetching = Task { await state.fetch() }
        try await waitForFetch({ state.authenticationRequest != nil }, "Nothing was asked")
        let open = try #require(state.authenticationRequest)

        let intruder = AuthenticationRequest(
            kind: .keyPassphrase,
            subject: "/keys/id_rsa",
            prompt: Self.passphrasePrompt
        )
        // Cancelled before its body runs, which is the case where the question is refused and
        // the cancellation lands in the same breath.
        let asking = Task { await state.authenticationResponder.respond(intruder) }
        asking.cancel()
        #expect(await asking.value == .cancelled)
        await Task.yield()

        #expect(state.authenticationRequest?.id == open.id)
        #expect(state.pendingAuthentication != nil)

        state.authenticationAnswer = Self.secret
        state.submitAuthentication()
        await fetching.value

        #expect(await stub.recordedAuthenticationResponses() == [.answer(Self.secret)])
    }

    // MARK: - Keeping nothing

    /// Colofa is not a credential store. Nothing about a question or its answer may reach the
    /// app's own preferences, before or after the command that asked succeeds.
    @Test
    @MainActor
    func writesNothingAboutTheQuestionOrItsAnswerToItsOwnDefaults() async throws {
        let stub = stub(prompts: [Self.passwordPrompt])
        let state = await workspace(stub)

        let fetching = Task { await state.fetch() }
        try await waitForFetch({ state.authenticationRequest != nil }, "Nothing was asked")
        state.authenticationAnswer = Self.secret
        state.submitAuthentication()
        await fetching.value

        let stored = String(describing: defaults.dictionaryRepresentation())
        #expect(!stored.contains(Self.secret))
        #expect(!stored.contains("octocat"))
        #expect(!stored.contains("Password for"))
    }
}
