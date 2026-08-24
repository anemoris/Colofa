////
//  AuthenticationChannelIntegrationTests.swift
//  ColofaGitIntegrationTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// The channel rather than the questions it carries: who is allowed to use it, what it keeps out
/// of what a command reports, and what it leaves behind once that command has ended.
///
/// Nothing here stubs the bridge either. What is controlled is only which Git runs and what it
/// asks; the socket, the token, the AskPass program, and the teardown are the ones that ship.
struct AuthenticationChannelIntegrationTests {
    // MARK: - Whose question it is

    /// A program presenting another operation's token is answered with nothing, and the question
    /// it carried never reaches the user.
    @Test
    func refusesAProgramThatCannotAddressThisOperation() async throws {
        let responder = RecordingResponder(answering: AskedCredential.secret)
        let bridge = try GitAskPassBridge(
            helperURL: try askPassHelperURL(),
            responder: responder.responder
        )
        defer { bridge.stop() }

        var environment = bridge.environment
        environment[GitAskPassSocket.tokenVariable] = UUID().uuidString
        let refused = try runAskPassHelper(prompt: AskedCredential.prompt, environment: environment)

        #expect(refused.status != 0)
        #expect(refused.output.isEmpty)
        #expect(await responder.recordedRequests().isEmpty)

        // The bridge's own token still works, so the refusal was about the token rather than
        // about the channel being unusable.
        let accepted = try runAskPassHelper(
            prompt: AskedCredential.prompt,
            environment: bridge.environment
        )
        #expect(accepted.status == 0)
        #expect(accepted.output == "\(AskedCredential.secret)\n")
    }

    /// A program that arrives after the operation ended finds nothing to connect to. The socket
    /// is gone from disk with it, so nothing is left behind that could be reached later.
    @Test
    func leavesNothingBehindForAProgramThatArrivesTooLate() throws {
        let responder = RecordingResponder(answering: AskedCredential.secret)
        let bridge = try GitAskPassBridge(
            helperURL: try askPassHelperURL(),
            responder: responder.responder
        )
        let environment = bridge.environment
        let socketPath = try #require(environment[GitAskPassSocket.socketVariable])
        bridge.stop()

        let stale = try runAskPassHelper(prompt: AskedCredential.prompt, environment: environment)

        #expect(stale.status != 0)
        #expect(stale.output.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: socketPath))
        #expect(
            !FileManager.default.fileExists(
                atPath: URL(filePath: socketPath).deletingLastPathComponent().normalizedFilePath
            )
        )
    }

    /// A valid token is not a licence to ask. A program that has this command's socket path and
    /// this command's token, presented while both are still live, is still refused unless the
    /// command itself started it — which is what stops a duplicate of an AskPass program from
    /// asking again, and again, for as long as the operation lasts.
    @Test
    func refusesAValidTokenReplayedFromOutsideTheCommand() async throws {
        let (git, releaseURL) = try waitingAskingGit(prompt: AskedCredential.prompt)
        let responder = RecordingResponder(answering: AskedCredential.secret)

        let command = Task {
            try await git.backend().runNetworkMutation(
                FetchCommand.fetch("origin"),
                in: git.repositoryURL,
                responder: responder.responder
            )
        }
        // The command's own program has already been answered, so the socket and the token the
        // replay below presents are the live ones rather than the remains of a finished command.
        #expect(try await waitForFile(at: git.answerURL) == AskedCredential.secret)

        let replayed = try runAskPassHelper(
            prompt: AskedCredential.prompt,
            environment: try reportedChannel(in: git.report.environmentURL)
        )

        #expect(replayed.status != 0)
        #expect(replayed.output.isEmpty)
        #expect(
            await responder.recordedRequests().count == 1,
            "A replayed token reached the user a second time"
        )

        try Data().write(to: releaseURL)
        try await command.value
    }

    /// Two questions asked at once are two conversations. Each answer goes back to the program
    /// that asked for it, and neither consumes the other's.
    @Test
    func answersTwoQuestionsAskedAtOnceSeparately() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        let promptURLs = (
            fixture.rootURL.appending(path: "prompt-1"),
            fixture.rootURL.appending(path: "prompt-2")
        )
        let answerURLs = (
            fixture.rootURL.appending(path: "answer-1"),
            fixture.rootURL.appending(path: "answer-2")
        )
        try Data("Username for 'https://example.invalid': ".utf8).write(to: promptURLs.0)
        try Data(AskedCredential.prompt.utf8).write(to: promptURLs.1)
        let executableURL = fixture.rootURL.appending(path: "double-asking-git")
        try writeDoubleAskingGit(
            at: executableURL,
            promptURLs: promptURLs,
            answerURLs: answerURLs
        )

        // Each question is answered with what it asked about, so an answer delivered to the wrong
        // conversation is visible rather than merely possible.
        let secret = AskedCredential.secret
        let responder = RecordingResponder { request in
            .answer(request.kind == .username ? "octocat" : secret)
        }
        try await GitRepositoryService(
            candidateURLs: [executableURL],
            environment: fixture.environment,
            askPassHelperURL: try askPassHelperURL()
        ).runNetworkMutation(
            FetchCommand.fetch("origin"),
            in: repositoryURL,
            responder: responder.responder
        )

        #expect(await responder.recordedRequests().count == 2)
        #expect(try String(contentsOf: answerURLs.0, encoding: .utf8) == "octocat\n")
        #expect(try String(contentsOf: answerURLs.1, encoding: .utf8) == "\(secret)\n")
    }

    // MARK: - Keeping nothing

    /// The one way an answer could reach a failure banner is Git quoting it back. It does not
    /// survive that: the question and the answer are both removed from what Colofa reports.
    @Test
    func keepsTheQuestionAndTheAnswerOutOfWhatItReports() async throws {
        let git = try askingGit(prompt: AskedCredential.prompt, leaksTheConversation: true)
        let secret = AskedCredential.secret
        let responder = RecordingResponder(answering: secret)

        let failure = await #expect(throws: RepositoryOpenError.self) {
            try await git.backend().runNetworkMutation(
                FetchCommand.fetch("origin"),
                in: git.repositoryURL,
                responder: responder.responder
            )
        }
        let details = try #require(failure?.failureDetails)

        #expect(!details.output.contains(secret))
        #expect(!details.output.contains("octocat"))
        #expect(!details.command.contains(secret))
        #expect(details.output.contains("rejected credential"), "Git's own words were lost")
    }

    /// A host key question names a host, an address, and a fingerprint, and OpenSSH prints the
    /// same words it asked with. None of it survives into what the refusal reports — and the
    /// refusal is still explained as the one it was, because what it was about travels as state
    /// rather than as the text that was removed.
    @Test
    func keepsAHostKeyQuestionOutOfWhatItReports() async throws {
        let fingerprint = "SHA256:8mFqR2vDpZ0oXbLcE7yTnW1sKjA5gHuQiN3rYxV6dPw"
        let git = try askingGit(
            prompt: """
                The authenticity of host 'example.invalid (203.0.113.9)' can't be established.
                ED25519 key fingerprint is \(fingerprint).
                Are you sure you want to continue connecting (yes/no/[fingerprint])?
                """,
            leaksTheConversation: true
        )
        let responder = RecordingResponder { _ in .cancelled }

        let failure = await #expect(throws: RepositoryOpenError.self) {
            try await git.backend().runNetworkMutation(
                FetchCommand.fetch("origin"),
                in: git.repositoryURL,
                responder: responder.responder
            )
        }
        let details = try #require(failure?.failureDetails)

        #expect(!details.output.contains(fingerprint))
        #expect(!details.output.contains("example.invalid"))
        #expect(!details.output.contains("203.0.113.9"))
        #expect(details.output.contains("rejected credential"), "Git's own words were lost")
        #expect(details.authenticationFailure == .unverifiedHostKey)
    }

    // MARK: - Everything the user already configured

    /// The helper the user already configured answers first, and Colofa is never reached at all:
    /// no prompt, no question on the channel, and the answer the command used is the helper's.
    ///
    /// Colofa's own part in this is only that it disables nothing — the test below asserts that
    /// directly. This one asserts what that produces once a helper is in place.
    @Test
    func answersFromACredentialHelperWithoutEverAskingColofa() async throws {
        let git = try helperFirstGit(answeredBy: "helper-token")
        let responder = RecordingResponder(answering: AskedCredential.secret)

        try await git.backend().runNetworkMutation(
            FetchCommand.fetch("origin"),
            in: git.repositoryURL,
            responder: responder.responder
        )

        #expect(
            await responder.recordedRequests().isEmpty,
            "Colofa was asked something the helper had already answered"
        )
        #expect(try String(contentsOf: git.answerURL, encoding: .utf8) == "helper-token")
        // The channel was there the whole time. It went unused because the helper answered, not
        // because Colofa never offered one.
        let environment = try String(contentsOf: git.report.environmentURL, encoding: .utf8)
        #expect(environment.contains("GIT_ASKPASS=\(try askPassHelperURL().normalizedFilePath)"))
    }

    /// Colofa adds an AskPass program and nothing else. It never disables a credential helper,
    /// a Keychain integration, an SSH agent, or the user's OpenSSH configuration, because those
    /// are what answer first — an AskPass program is only reached once they have not.
    @Test
    func addsAnAskPassProgramWithoutDisablingAnythingElse() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        let executableURL = fixture.rootURL.appending(path: "reporting-git")
        let environmentURL = fixture.rootURL.appending(path: "environment")
        try writeReportingGit(at: executableURL, environmentURL: environmentURL)

        try await GitRepositoryService(
            candidateURLs: [executableURL],
            environment: fixture.environment,
            askPassHelperURL: try askPassHelperURL()
        ).runNetworkMutation(
            FetchCommand.fetch("origin"),
            in: repositoryURL,
            responder: AuthenticationResponder.refusing
        )

        let environment = try String(contentsOf: environmentURL, encoding: .utf8)
        let helperPath = try askPassHelperURL().normalizedFilePath
        #expect(environment.contains("GIT_ASKPASS=\(helperPath)"))
        #expect(environment.contains("SSH_ASKPASS=\(helperPath)"))
        #expect(environment.contains("SSH_ASKPASS_REQUIRE=force"))
        for disabling in ["GIT_CONFIG_NOSYSTEM", "GIT_SSH_COMMAND", "GIT_SSH", "SSH_AUTH_SOCK="] {
            #expect(
                !environment.contains("\(disabling)="),
                "Colofa set \(disabling), which overrides what the user configured"
            )
        }
    }

    /// The channel exists for one command and no longer. Nothing about it survives the command
    /// that opened it, whether it succeeded or failed.
    @Test
    func tearsDownTheChannelWhenTheCommandEnds() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        let executableURL = fixture.rootURL.appending(path: "reporting-git")
        let environmentURL = fixture.rootURL.appending(path: "environment")
        try writeReportingGit(at: executableURL, environmentURL: environmentURL)

        try await GitRepositoryService(
            candidateURLs: [executableURL],
            environment: fixture.environment,
            askPassHelperURL: try askPassHelperURL()
        ).runNetworkMutation(
            FetchCommand.fetch("origin"),
            in: repositoryURL,
            responder: AuthenticationResponder.refusing
        )

        let socketPath = try reportedSocketPath(in: environmentURL)

        #expect(!FileManager.default.fileExists(atPath: socketPath))
    }
}
