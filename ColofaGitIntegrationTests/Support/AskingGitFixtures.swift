////
//  AskingGitFixtures.swift
//  ColofaGitIntegrationTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// Where a stand-in Git records what happened to it, so a test can read the command rather than
/// only its answer.
struct AskingGitReport {
    /// The answer the command received, which is the only way a test may read one.
    let answerURL: URL

    /// The process the command ran as, so a test can ask whether it is still running.
    let pidURL: URL

    /// The environment the command was given, which is where the channel it was pointed at is
    /// named.
    let environmentURL: URL

    init(in directoryURL: URL) {
        answerURL = directoryURL.appending(path: "answer")
        pidURL = directoryURL.appending(path: "pid")
        environmentURL = directoryURL.appending(path: "environment")
    }
}

/// One command's fixture: a Repository to run in, a stand-in Git, and the files it reads the
/// question from and writes to.
struct AskingGit {
    let fixture: GitTestRepository
    let repositoryURL: URL
    let executableURL: URL
    let report: AskingGitReport

    var answerURL: URL {
        report.answerURL
    }

    /// What this command runs with: the fixture's own environment, plus whatever a stand-in Git
    /// needs to find the rest of its fixture.
    let environment: [String: String]

    /// A backend that runs this stand-in Git with Colofa's real AskPass program behind it.
    func backend() throws -> GitRepositoryService {
        GitRepositoryService(
            candidateURLs: [executableURL],
            environment: environment,
            askPassHelperURL: try askPassHelperURL()
        )
    }
}

/// - Parameter leaksTheConversation: Whether the stand-in Git writes the question it asked and
///   the answer it was told into its own diagnostic, which is the one way either could reach a
///   failure banner.
func askingGit(prompt: String, leaksTheConversation: Bool = false) throws -> AskingGit {
    let fixture = try GitTestRepository()
    let repositoryURL = try fixture.createWorkingRepository()
    let promptURL = fixture.rootURL.appending(path: "prompt")
    try Data(prompt.utf8).write(to: promptURL)

    let executableURL = fixture.rootURL.appending(path: "asking-git")
    let report = AskingGitReport(in: fixture.rootURL)
    if leaksTheConversation {
        try writeLeakingGit(at: executableURL, promptURL: promptURL, reporting: report)
    } else {
        try writeAskingGit(at: executableURL, promptURL: promptURL, reporting: report)
    }

    return AskingGit(
        fixture: fixture,
        repositoryURL: repositoryURL,
        executableURL: executableURL,
        report: report,
        environment: fixture.environment
    )
}

/// A fixture whose Git answers from the credential helper the user already configured, and asks
/// Colofa only if that helper answers nothing.
func helperFirstGit(answeredBy credential: String) throws -> AskingGit {
    let fixture = try GitTestRepository()
    let repositoryURL = try fixture.createWorkingRepository()
    let promptURL = fixture.rootURL.appending(path: "prompt")
    try Data("Password for 'https://example.invalid': ".utf8).write(to: promptURL)

    let helperURL = fixture.rootURL.appending(path: "credential-helper")
    try writeCredentialHelper(at: helperURL, answering: credential)

    let executableURL = fixture.rootURL.appending(path: "helper-first-git")
    let report = AskingGitReport(in: fixture.rootURL)
    try writeHelperFirstGit(at: executableURL, promptURL: promptURL, reporting: report)

    return AskingGit(
        fixture: fixture,
        repositoryURL: repositoryURL,
        executableURL: executableURL,
        report: report,
        environment: fixture.environment.merging(
            ["COLOFA_TEST_CREDENTIAL_HELPER": helperURL.normalizedFilePath]
        ) { _, configured in configured }
    )
}

/// A fixture whose Git asks once and then stays running until `releaseURL` is created.
func waitingAskingGit(prompt: String) throws -> (git: AskingGit, releaseURL: URL) {
    let fixture = try GitTestRepository()
    let repositoryURL = try fixture.createWorkingRepository()
    let promptURL = fixture.rootURL.appending(path: "prompt")
    try Data(prompt.utf8).write(to: promptURL)

    let releaseURL = fixture.rootURL.appending(path: "release")
    let executableURL = fixture.rootURL.appending(path: "waiting-git")
    let report = AskingGitReport(in: fixture.rootURL)
    try writeAskingThenWaitingGit(
        at: executableURL,
        promptURL: promptURL,
        releaseURL: releaseURL,
        reporting: report
    )

    return (
        AskingGit(
            fixture: fixture,
            repositoryURL: repositoryURL,
            executableURL: executableURL,
            report: report,
            environment: fixture.environment
        ),
        releaseURL
    )
}

/// The channel a command was pointed at, as an environment an AskPass program could be run with.
nonisolated func reportedChannel(in environmentURL: URL) throws -> [String: String] {
    let reported = try String(contentsOf: environmentURL, encoding: .utf8)
    let variables = Dictionary(
        reported.split(whereSeparator: \.isNewline).compactMap { line -> (String, String)? in
            guard let separator = line.firstIndex(of: "=") else {
                return nil
            }
            return (
                String(line[line.startIndex..<separator]),
                String(line[line.index(after: separator)...])
            )
        },
        uniquingKeysWith: { _, last in last }
    )

    var channel: [String: String] = [:]
    for variable in [GitAskPassSocket.socketVariable, GitAskPassSocket.tokenVariable] {
        // Bound before it is stored, because assigning straight into the dictionary would give
        // `#require` an optional to expect and leave it with nothing to check.
        let value: String = try #require(
            variables[variable],
            "The command was never told a \(variable)"
        )
        channel[variable] = value
    }
    return channel
}
