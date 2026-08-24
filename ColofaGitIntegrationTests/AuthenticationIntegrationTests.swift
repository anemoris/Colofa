////
//  AuthenticationIntegrationTests.swift
//  ColofaGitIntegrationTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Darwin
import Foundation
import Testing
@testable import Colofa

/// The AskPass channel driven by real processes: a stand-in Git that asks the way Git asks, and
/// Colofa's own executable relaying the question the way it would for the real one.
///
/// Nothing here stubs the bridge. What is controlled is only which Git runs and what it asks, so
/// the socket, the token, the AskPass program, and the teardown are all the ones that ship.
struct AuthenticationIntegrationTests {
    // MARK: - Answering

    /// The whole channel, end to end: Git asks its AskPass program, Colofa's own executable
    /// relays the question, and what the user typed comes back to the process that asked.
    @Test
    func relaysAnHTTPSPasswordQuestionToColofaAndBackToGit() async throws {
        let git = try askingGit(prompt: AskedCredential.prompt)
        let responder = RecordingResponder(answering: AskedCredential.secret)

        try await git.backend().runNetworkMutation(
            FetchCommand.fetch("origin"),
            in: git.repositoryURL,
            responder: responder.responder
        )

        let asked = await responder.recordedRequests()
        #expect(asked.count == 1)
        #expect(asked.first?.kind == .password)
        #expect(asked.first?.subject == "https://octocat@example.invalid")
        #expect(try String(contentsOf: git.answerURL, encoding: .utf8) == AskedCredential.secret)
    }

    @Test
    func relaysAnSSHKeyPassphraseQuestion() async throws {
        let git = try askingGit(prompt: "Enter passphrase for key '/keys/id_ed25519': ")
        let responder = RecordingResponder(answering: "correct horse")

        try await git.backend().runNetworkMutation(
            FetchCommand.fetch("origin"),
            in: git.repositoryURL,
            responder: responder.responder
        )

        #expect(await responder.recordedRequests().first?.kind == .keyPassphrase)
        #expect(try String(contentsOf: git.answerURL, encoding: .utf8) == "correct horse")
    }

    /// A host OpenSSH has never seen is confirmed with OpenSSH's own word, and the fingerprint
    /// reaches the user exactly as it was read.
    @Test
    func confirmsANewHostKeyWithTheWordOpenSSHReads() async throws {
        let fingerprint = "SHA256:8mFqR2vDpZ0oXbLcE7yTnW1sKjA5gHuQiN3rYxV6dPw"
        let git = try askingGit(
            prompt: """
                The authenticity of host 'example.invalid (203.0.113.9)' can't be established.
                ED25519 key fingerprint is \(fingerprint).
                Are you sure you want to continue connecting (yes/no/[fingerprint])?
                """
        )
        let expected = fingerprint
        let responder = RecordingResponder { request in
            .answer(request.fingerprint == expected ? AuthenticationRequestKind.confirmation : "no")
        }

        try await git.backend().runNetworkMutation(
            FetchCommand.fetch("origin"),
            in: git.repositoryURL,
            responder: responder.responder
        )

        #expect(await responder.recordedRequests().first?.subject == "example.invalid")
        #expect(try String(contentsOf: git.answerURL, encoding: .utf8) == "yes")
    }

    // MARK: - Refusing

    /// A host whose key changed is never put to the user at all: the bridge answers it, and the
    /// answer is no.
    @Test
    func refusesAChangedHostKeyWithoutAskingAnybody() async throws {
        let git = try askingGit(
            prompt: """
                @    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @
                Are you sure you want to continue connecting (yes/no/[fingerprint])?
                """
        )
        let responder = RecordingResponder(answering: AuthenticationRequestKind.confirmation)

        let failure = await #expect(throws: RepositoryOpenError.self) {
            try await git.backend().runNetworkMutation(
                FetchCommand.fetch("origin"),
                in: git.repositoryURL,
                responder: responder.responder
            )
        }

        #expect(await responder.recordedRequests().isEmpty, "A changed host key reached the user")
        #expect(!FileManager.default.fileExists(atPath: git.answerURL.normalizedFilePath))
        // What the refusal was about travels with the failure. It has to: the warning it was read
        // out of is redacted out of everything the command reports.
        #expect(failure?.failureDetails?.authenticationFailure == .changedHostKey)
    }

    /// A cancelled prompt leaves the AskPass program with nothing to print, so Git ends the
    /// command itself rather than waiting on a terminal nobody is watching.
    @Test
    func endsTheCommandWhenTheQuestionIsCancelled() async throws {
        let git = try askingGit(prompt: AskedCredential.prompt)
        let responder = RecordingResponder { _ in .cancelled }

        await #expect(throws: RepositoryOpenError.self) {
            try await git.backend().runNetworkMutation(
                FetchCommand.fetch("origin"),
                in: git.repositoryURL,
                responder: responder.responder
            )
        }

        #expect(await responder.recordedRequests().count == 1)
        #expect(!FileManager.default.fileExists(atPath: git.answerURL.normalizedFilePath))
        // The command went with the question. Its process ended rather than waiting on an answer
        // that will never come, and the channel it was pointed at is gone from disk with it.
        #expect(
            try await waitUntilProcessEnded(reportedAt: git.report.pidURL),
            "The command the prompt belonged to is still running"
        )
        let socketPath = try reportedSocketPath(in: git.report.environmentURL)
        #expect(!FileManager.default.fileExists(atPath: socketPath))
        #expect(
            !FileManager.default.fileExists(
                atPath: URL(filePath: socketPath).deletingLastPathComponent().normalizedFilePath
            )
        )
    }

    /// A program that connects and then says nothing cannot hold the channel open. Colofa reads a
    /// question until the program writing it stops, and one that never stops would otherwise hold
    /// the connection, the descriptor behind it, and the task serving it for as long as it liked
    /// — including past the teardown of the command they all belong to.
    @Test
    func endsAConnectionThatNeverFinishesAsking() async throws {
        let responder = RecordingResponder(answering: AskedCredential.secret)
        let bridge = try GitAskPassBridge(
            helperURL: try askPassHelperURL(),
            responder: responder.responder
        )
        let socketPath = try #require(bridge.environment[GitAskPassSocket.socketVariable])

        let descriptor = try connectedSocket(to: socketPath)
        defer { close(descriptor) }
        // Half a question: enough to be served, never enough to be answered.
        let partial = Data("colofa-askpass-1\n".utf8)
        let written = partial.withUnsafeBytes { bytes in
            Darwin.write(descriptor, bytes.baseAddress, bytes.count)
        }
        #expect(written == partial.count)
        // Long enough for the bridge to have accepted the connection and started reading it,
        // which is the state this is about: a read nobody can finish.
        try await Task.sleep(for: .milliseconds(200))

        bridge.stop()

        #expect(
            readUntilClosed(descriptor) != nil,
            "Colofa is still holding a connection nobody is asking through"
        )
        #expect(await responder.recordedRequests().isEmpty)
    }
}
