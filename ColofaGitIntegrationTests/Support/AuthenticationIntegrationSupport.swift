////
//  AuthenticationIntegrationSupport.swift
//  ColofaGitIntegrationTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Darwin
import Foundation
import Testing
@testable import Colofa

/// The AskPass program Git and OpenSSH are pointed at, which is the tool bundled inside the app.
///
/// These tests are hosted by the app, so the binary that relays a real question is the one
/// relaying the controlled one here. Nothing stands in for the bridge; only Git does.
nonisolated func askPassHelperURL() throws -> URL {
    try #require(GitRepositoryService.bundledAskPassHelperURL())
}

/// The question and the answer these tests use wherever the question itself is not the point.
///
/// Written the way Git writes them, so what is exercised is the real parser rather than a shape
/// invented for testing.
nonisolated enum AskedCredential {
    static let prompt = "Password for 'https://octocat@example.invalid': "
    static let secret = "ghp_ColofaIntegrationToken"
}

/// Records every question one command asked and answers each of them the same way.
///
/// Declared as an actor because the bridge serves connections off the main actor, and a test has
/// to read what it asked afterwards.
actor RecordingResponder {
    private let answer: @Sendable (AuthenticationRequest) -> AuthenticationResponse
    private var requests: [AuthenticationRequest] = []

    init(answer: @escaping @Sendable (AuthenticationRequest) -> AuthenticationResponse) {
        self.answer = answer
    }

    /// Answers every question with `text`.
    init(answering text: String) {
        self.init { _ in .answer(text) }
    }

    nonisolated var responder: AuthenticationResponder {
        AuthenticationResponder { await self.respond(to: $0) }
    }

    func recordedRequests() -> [AuthenticationRequest] {
        requests
    }

    private func respond(to request: AuthenticationRequest) -> AuthenticationResponse {
        requests.append(request)
        return answer(request)
    }
}

/// A stand-in Git that asks one question through whatever `GIT_ASKPASS` names, then reports what
/// it was told.
///
/// It records the process it runs as and the environment it was given, so a test can ask what
/// became of the command itself rather than only of its answer.
///
/// - Parameters:
///   - promptURL: Holds the question, so a prompt spanning several lines survives being written
///     into a script.
///   - report: Where it writes the answer it was given, and what became of the command itself.
nonisolated func writeAskingGit(
    at executableURL: URL,
    promptURL: URL,
    reporting report: AskingGitReport
) throws {
    try writeExecutable(
        at: executableURL,
        script: """
        if [ "$1" = "--version" ]; then
            echo "git version 2.0.0"
            exit 0
        fi
        echo $$ > "\(report.pidURL.normalizedFilePath)"
        env > "\(report.environmentURL.normalizedFilePath)"
        prompt=$(cat "\(promptURL.normalizedFilePath)")
        if answer=$("$GIT_ASKPASS" "$prompt"); then
            printf '%s' "$answer" > "\(report.answerURL.normalizedFilePath)"
            exit 0
        fi
        echo "fatal: could not read Password for 'https://example.invalid': \
        terminal prompts disabled" >&2
        exit 128
        """
    )
}

/// A stand-in Git that asks, then writes both halves of the conversation into its own diagnostic
/// and fails — which is the one way a question or an answer could reach a failure banner.
///
/// OpenSSH does exactly this with a host key: the warning it puts to an AskPass program is the
/// warning it also prints.
nonisolated func writeLeakingGit(
    at executableURL: URL,
    promptURL: URL,
    reporting report: AskingGitReport
) throws {
    try writeExecutable(
        at: executableURL,
        script: """
        if [ "$1" = "--version" ]; then
            echo "git version 2.0.0"
            exit 0
        fi
        echo $$ > "\(report.pidURL.normalizedFilePath)"
        env > "\(report.environmentURL.normalizedFilePath)"
        prompt=$(cat "\(promptURL.normalizedFilePath)")
        answer=$("$GIT_ASKPASS" "$prompt")
        echo "remote: rejected credential $answer" >&2
        echo "$prompt" >&2
        exit 128
        """
    )
}

/// A stand-in Git that asks one question and then keeps running until it is released.
///
/// It holds a command open at the one moment that matters: its question has been answered and its
/// channel is still live. A test can act against that channel while the command it belongs to is
/// demonstrably still there, instead of racing its exit.
///
/// - Parameter releaseURL: Created by the test when it is done, which is what lets the command
///   finish.
nonisolated func writeAskingThenWaitingGit(
    at executableURL: URL,
    promptURL: URL,
    releaseURL: URL,
    reporting report: AskingGitReport
) throws {
    try writeExecutable(
        at: executableURL,
        script: """
        if [ "$1" = "--version" ]; then
            echo "git version 2.0.0"
            exit 0
        fi
        echo $$ > "\(report.pidURL.normalizedFilePath)"
        env > "\(report.environmentURL.normalizedFilePath)"
        prompt=$(cat "\(promptURL.normalizedFilePath)")
        printf '%s' "$("$GIT_ASKPASS" "$prompt")" > "\(report.answerURL.normalizedFilePath)"
        while [ ! -f "\(releaseURL.normalizedFilePath)" ]; do
            sleep 0.05
        done
        exit 0
        """
    )
}

/// A stand-in Git that answers from a credential helper the way Git does, and reaches an AskPass
/// program only when the helper answered nothing.
///
/// The ordering is Git's, standing in here: what Colofa is responsible for is adding an AskPass
/// program without disabling anything that answers before it, and this is what that ordering
/// produces once it does.
nonisolated func writeHelperFirstGit(
    at executableURL: URL,
    promptURL: URL,
    reporting report: AskingGitReport
) throws {
    try writeExecutable(
        at: executableURL,
        script: """
        if [ "$1" = "--version" ]; then
            echo "git version 2.0.0"
            exit 0
        fi
        echo $$ > "\(report.pidURL.normalizedFilePath)"
        env > "\(report.environmentURL.normalizedFilePath)"
        answer=$("$COLOFA_TEST_CREDENTIAL_HELPER")
        if [ -n "$answer" ]; then
            printf '%s' "$answer" > "\(report.answerURL.normalizedFilePath)"
            exit 0
        fi
        prompt=$(cat "\(promptURL.normalizedFilePath)")
        printf '%s' "$("$GIT_ASKPASS" "$prompt")" > "\(report.answerURL.normalizedFilePath)"
        exit 0
        """
    )
}

/// A credential helper that answers, standing in for the ones a user already configured.
nonisolated func writeCredentialHelper(
    at executableURL: URL,
    answering credential: String
) throws {
    try writeExecutable(at: executableURL, script: "printf '%s' \(credential.debugDescription)")
}

/// A stand-in Git that asks two questions at the same time, the way one connection needing a
/// username and a password does.
nonisolated func writeDoubleAskingGit(
    at executableURL: URL,
    promptURLs: (URL, URL),
    answerURLs: (URL, URL)
) throws {
    try writeExecutable(
        at: executableURL,
        script: """
        if [ "$1" = "--version" ]; then
            echo "git version 2.0.0"
            exit 0
        fi
        "$GIT_ASKPASS" "$(cat "\(promptURLs.0.normalizedFilePath)")" \
        > "\(answerURLs.0.normalizedFilePath)" &
        "$GIT_ASKPASS" "$(cat "\(promptURLs.1.normalizedFilePath)")" \
        > "\(answerURLs.1.normalizedFilePath)" &
        wait
        exit 0
        """
    )
}

/// A stand-in Git that records the arguments and environment it was given, so a test can prove
/// what Colofa added — and what it left alone.
nonisolated func writeReportingGit(at executableURL: URL, environmentURL: URL) throws {
    try writeExecutable(
        at: executableURL,
        script: """
        if [ "$1" = "--version" ]; then
            echo "git version 2.0.0"
            exit 0
        fi
        env > "\(environmentURL.normalizedFilePath)"
        exit 0
        """
    )
}

/// Runs Colofa's AskPass program the way Git would, with the environment it would inherit.
///
/// - Returns: What it printed and what it exited with. An AskPass program declines by exiting
///   non-zero without printing anything.
nonisolated func runAskPassHelper(
    prompt: String,
    environment: [String: String]
) throws -> (status: Int32, output: String) {
    let pipe = Pipe()
    let process = Process()
    process.executableURL = try askPassHelperURL()
    process.arguments = [prompt]
    process.environment = environment
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice

    try process.run()
    let output = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return (process.terminationStatus, String(gitBytes: output))
}

/// Waits for a stand-in Git to write the answer it was given.
nonisolated func waitForFile(at url: URL, timeout: Duration = .seconds(10)) async throws -> String {
    let deadline = ContinuousClock.now.advanced(by: timeout)
    while !FileManager.default.fileExists(atPath: url.normalizedFilePath) {
        try #require(ContinuousClock.now < deadline, "Nothing was ever written to \(url.lastPathComponent)")
        try await Task.sleep(for: .milliseconds(5))
    }
    return try String(contentsOf: url, encoding: .utf8)
}
