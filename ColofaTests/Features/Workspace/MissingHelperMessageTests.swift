////
//  MissingHelperMessageTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation
import Testing
@testable import Colofa

/// Which failures are allowed to be explained as a program Git could not find.
///
/// The reported symptom is a Git that says `the remote end hung up unexpectedly` about a remote
/// that was never the problem. Naming the program is only an improvement where Colofa had nothing
/// better to say; where it had already established what happened, replacing that answer would be
/// replacing it with a guess.
struct MissingHelperMessageTests {

    /// The failure as Git actually reports it, with the real cause on the line above the one that
    /// blames the remote.
    private let missingLFS = """
        git-lfs filter-process: git-lfs: command not found
        fatal: the remote end hung up unexpectedly
        """

    private func failure(_ output: String) -> RepositoryOpenError {
        .commandFailed(GitFailureDetails(command: "git fetch", output: output, exitStatus: 128))
    }

    @Test
    func repositoryOpenNamesTheProgramInsteadOfBlamingTheRepository() throws {
        let named = RepositoryFailurePresentation.repositoryOpenAlert(failure(missingLFS))
        let unnamed = RepositoryFailurePresentation.repositoryOpenAlert(failure("fatal: bad object"))

        #expect(englishText(try #require(named.message)).contains("git-lfs"))
        #expect(unnamed.message == .gitCommandFailedDescription)
    }

    @Test
    func commandFailureNamesTheProgramWhileTheTitleStaysTheOperation() throws {
        let alert = RepositoryFailurePresentation.mutationAlert(
            failure(missingLFS),
            title: .pullFailed
        )

        #expect(alert.title == .pullFailed)
        #expect(englishText(try #require(alert.message)).contains("git-lfs"))
    }

    @Test
    func commandFailureThatNamesNoProgramKeepsTheSharedNextStep() {
        let alert = RepositoryFailurePresentation.mutationAlert(
            failure("fatal: could not read from remote repository"),
            title: .pullFailed
        )

        #expect(alert.message == .gitMutationFailedDescription)
    }

    /// No remote refused anything, so listing them points the user at the part that worked.
    @Test
    func fetchNamesTheProgramInsteadOfTheRemotes() throws {
        let alert = RepositoryFailurePresentation.fetchAlert(
            .failed(remotes: ["origin"], fetched: [], error: failure(missingLFS))
        )
        let message = englishText(try #require(alert.message))

        #expect(message.contains("git-lfs"))
        #expect(message.contains("origin") == false)
    }

    /// A failure Colofa already classified keeps its own explanation, even though the output it
    /// carries would also parse.
    @Test
    func aFailureAlreadyExplainedIsNotReExplained() {
        let alert = RepositoryFailurePresentation.authenticationAlert(
            .declinedCredentials,
            error: failure(missingLFS)
        )

        #expect(alert.message == AuthenticationFailure.declinedCredentials.message)
    }

    /// The alert and the details it expands into say the same thing, so reading Git's own output
    /// never loses the explanation that brought the user there.
    @Test
    func theExpandedDetailsCarryTheSameExplanation() throws {
        let alert = RepositoryFailurePresentation.mutationAlert(
            failure(missingLFS),
            title: .pullFailed
        )
        let expanded = try #require(alert.expandedDetails)

        #expect(expanded.message == alert.message)
    }
}
