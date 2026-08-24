////
//  RealProcessAskPassIntegrationTests.swift
//  ColofaGitIntegrationTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// Colofa's channel against the Git and OpenSSH the machine actually has.
///
/// Everything else in this target controls what Git asks by standing in for Git. That is the right
/// tool for a question about Colofa's own behaviour — how a refusal is reported, what a teardown
/// leaves behind — because it makes the question deterministic. It is the wrong tool for three
/// claims, because in each of them the thing under test belongs to Git or OpenSSH rather than to
/// Colofa: that Git consults a configured credential helper before it reaches an AskPass program,
/// that Git's own credential questions are the ones Colofa classifies, and that OpenSSH writes its
/// passphrase question the way Colofa reads it. A stand-in asked those questions would only repeat
/// the assumption being tested.
///
/// Isolated the same way every suite here is: a redirected home and configuration, a controlled
/// locale, a loopback address, and keys generated into a temporary directory. Nothing reaches the
/// network or the developer's own configuration.
@Suite(.serialized)
struct RealProcessAskPassIntegrationTests {
    // Read from inside the closure that answers a question, which runs off the main actor.
    private nonisolated static let account = "octocat"
    private nonisolated static let token = "ghp_ColofaIntegrationToken"
    private nonisolated static let passphrase = "colofa-integration-passphrase"

    // MARK: - Real Git

    /// Git asks for a credential only once a server has refused one, and it asks its own two
    /// questions in its own words. Both arrive over Colofa's channel and are answered back into
    /// the request Git retries with.
    @Test
    func answersTheCredentialQuestionsRealGitAsks() async throws {
        try InstalledTool.require(InstalledTool.git)
        let remote = try LocalHTTPRemote()
        defer { remote.stop() }
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()

        let responder = RecordingResponder { request in
            .answer(request.kind == .username ? Self.account : Self.token)
        }
        await #expect(throws: RepositoryOpenError.self) {
            try await Self.backend(for: fixture).runNetworkMutation(
                Self.lsRemote(from: remote),
                in: repositoryURL,
                responder: responder.responder
            )
        }

        let asked = await responder.recordedRequests()
        #expect(asked.map(\.kind) == [.username, .password])
        // Git's own wording, which is what the parser has to keep reading correctly.
        #expect(asked.first?.prompt.hasPrefix("Username for ") == true)
        #expect(asked.last?.prompt.hasPrefix("Password for ") == true)
        #expect(asked.first?.subject?.contains("127.0.0.1:\(remote.port)") == true)
        // The answers reached the remote as the credential Git retried with, which is the only
        // proof that they went back into the command rather than merely into Colofa.
        #expect(
            remote.receivedAuthorizations.contains(
                basicAuthorization(username: Self.account, password: Self.token)
            )
        )
    }

    /// A credential helper the user configured answers first, and Git never reaches an AskPass
    /// program at all. Colofa adds a program; it does not take the place of one.
    @Test
    func leavesAConfiguredCredentialHelperAnsweringFirst() async throws {
        try InstalledTool.require(InstalledTool.git)
        let remote = try LocalHTTPRemote()
        defer { remote.stop() }
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()

        let helperURL = fixture.rootURL.appending(path: "credential-helper")
        let invocationsURL = fixture.rootURL.appending(path: "credential-helper-invocations")
        try writeGitCredentialHelper(
            at: helperURL,
            username: "helper-account",
            password: "helper-secret",
            reporting: invocationsURL
        )

        let responder = RecordingResponder(answering: Self.token)
        await #expect(throws: RepositoryOpenError.self) {
            try await Self.backend(for: fixture).runNetworkMutation(
                ["-c", "credential.helper=\(helperURL.normalizedFilePath)"]
                    + Self.lsRemote(from: remote),
                in: repositoryURL,
                responder: responder.responder
            )
        }

        #expect(
            try String(contentsOf: invocationsURL, encoding: .utf8).contains("get"),
            "Git never consulted the configured credential helper"
        )
        #expect(
            await responder.recordedRequests().isEmpty,
            "Colofa was asked for a credential the configured helper had already answered"
        )
        #expect(
            remote.receivedAuthorizations.contains(
                basicAuthorization(username: "helper-account", password: "helper-secret")
            )
        )
    }

    // MARK: - Real OpenSSH

    /// OpenSSH asks for a key passphrase in its own words and quotes the key its own way. Colofa
    /// reads that question, answers it, and the key decrypts — which is the whole of what a
    /// passphrase prompt has to achieve.
    @Test
    func answersThePassphraseQuestionRealOpenSSHAsks() async throws {
        try InstalledTool.require(InstalledTool.sshKeygen)
        let fixture = try GitTestRepository()
        let keyURL = fixture.rootURL.appending(path: "id_ed25519")
        let keyPath = keyURL.normalizedFilePath
        // Given rather than asked for, so generating the key is not itself a prompt under test.
        let generated = try runTool(
            InstalledTool.sshKeygen,
            ["-q", "-t", "ed25519", "-N", Self.passphrase, "-C", "colofa", "-f", keyPath],
            environment: fixture.environment
        )
        try #require(generated.status == 0)

        let responder = RecordingResponder(answering: Self.passphrase)
        let bridge = try GitAskPassBridge(
            helperURL: try askPassHelperURL(),
            responder: responder.responder
        )
        defer { bridge.stop() }

        // Printing the public half of an encrypted private key is work OpenSSH can only do once
        // the passphrase has decrypted it, so the output is what says the answer was right.
        let read = try runTool(
            InstalledTool.sshKeygen,
            ["-y", "-f", keyPath],
            environment: fixture.environment.merging(bridge.environment) { _, asked in asked }
        )

        #expect(read.status == 0)
        let published = try String(contentsOf: keyURL.appendingPathExtension("pub"), encoding: .utf8)
        #expect(Self.publicKey(in: read.output) == Self.publicKey(in: published))

        let asked = try #require(await responder.recordedRequests().first)
        #expect(await responder.recordedRequests().count == 1)
        #expect(asked.kind == .keyPassphrase)
        #expect(asked.kind.isSecret)
        // OpenSSH quotes the key with double quotes where Git quotes a remote with single ones,
        // and the user is shown whichever it wrote.
        #expect(asked.prompt.contains("Enter passphrase"))
        #expect(asked.subject == keyPath)
    }

    // MARK: - Fixture

    private static func backend(for fixture: GitTestRepository) throws -> GitRepositoryService {
        GitRepositoryService(
            candidateURLs: [InstalledTool.git],
            environment: fixture.environment,
            askPassHelperURL: try askPassHelperURL()
        )
    }

    /// Reading a remote's refs is the smallest command that contacts one, and the fixture's
    /// system-wide proxy is turned off for it so the loopback address is reached directly.
    private static func lsRemote(from remote: LocalHTTPRemote) -> [String] {
        ["-c", "http.proxy=", "ls-remote", remote.repositoryURL(named: "colofa.git")]
    }

    /// The algorithm and the key itself, without the comment either end may or may not carry.
    private static func publicKey(in text: String) -> String {
        text.split(separator: " ").prefix(2).joined(separator: " ")
    }
}
