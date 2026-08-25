////
//  RepositoryServiceStub+Fetch.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
@testable import Colofa

/// What the fixture answers about Fetch.
///
/// Grouped apart because these behave differently from the rest: the command they stand in for
/// can be stopped, and one remote failing says nothing about the next.
extension RepositoryServiceStub {
    /// Every command that contacted a remote, in the order it ran.
    func recordedNetworkMutations() -> [[String]] {
        networkMutations
    }

    func recordedTagConflictRequests() -> [TagConflictRequest] {
        tagConflictRequests
    }

    func skipped() throws -> Set<String> {
        if let skippedRemotesError {
            throw skippedRemotesError
        }
        return skippedRemotes
    }

    func conflicts(_ request: TagConflictRequest) async throws -> TagFetchConflict {
        tagConflictRequests.append(request)
        if let tagConflictDelay {
            try await Task.sleep(for: tagConflictDelay)
        }
        if let tagConflictError {
            throw tagConflictError
        }
        return tagConflict
    }

    /// Every question this fixture asked, in the order it asked them.
    func recordedAuthenticationRequests() -> [AuthenticationRequest] {
        authenticationRequests
    }

    /// Every answer this fixture was given, which is the only place a test may read one.
    func recordedAuthenticationResponses() -> [AuthenticationResponse] {
        authenticationResponses
    }

    /// Answers the way a real Fetch does: it can be stopped while it runs, it may ask for a
    /// secret before it gets anywhere, and one remote failing says nothing about the next.
    func networkMutate(
        _ arguments: [String],
        answeredBy responder: AuthenticationResponder
    ) async throws {
        networkMutations.append(arguments)
        if let networkMutationDelay {
            try await Task.sleep(for: networkMutationDelay)
        }
        if let refusal = try await refusedAuthentication(answeredBy: responder) {
            throw refusal
        }
        // Read the way Git reads it rather than off the end: a tag Fetch carries its refspec
        // after the remote, so the last argument is not the remote it contacted.
        guard let remote = FetchCommand.remote(of: arguments),
              failingRemotes.contains(remote) else {
            return
        }
        throw RepositoryOpenError.commandFailed(
            GitFailureDetails(
                command: "git fetch",
                output: networkFailureOutput,
                exitStatus: 128
            )
        )
    }

    /// Asks this command's question, when the fixture has one left to ask.
    ///
    /// - Returns: `nil` when nothing was asked or the question was answered, which is when the
    ///   command goes on.
    func refusedAuthentication(
        answeredBy responder: AuthenticationResponder
    ) async throws -> RepositoryOpenError? {
        guard askedPromptCount < authenticationPrompts.count else {
            return nil
        }
        let prompt = authenticationPrompts[askedPromptCount]
        askedPromptCount += 1

        let request = AuthenticationPromptParser.request(for: prompt)
        authenticationRequests.append(request)
        guard request.isAnswerable else {
            return .commandFailed(refusal(of: request))
        }

        let response = await responder.respond(request)
        authenticationResponses.append(response)
        guard response == .cancelled else {
            return nil
        }
        // A command the user stopped reports the Cancel rather than the failure it became, the
        // same way the real one does.
        try Task.checkCancellation()
        return .commandFailed(refusal(of: request))
    }

    /// What a refused question leaves behind, carrying what it was about the way the real channel
    /// carries it: as state, because the question itself is redacted out of the output.
    private func refusal(of request: AuthenticationRequest) -> GitFailureDetails {
        GitFailureDetails(
            command: "git fetch",
            output: authenticationFailureOutput,
            exitStatus: 128,
            authenticationFailure: .refusing(request.kind)
        )
    }
}
