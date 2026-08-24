////
//  AskPassChannelTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// What a command reports when the channel its questions would have travelled over never opened.
///
/// The command still runs, so the only thing left to get right is what the user is told
/// afterwards: Git failing for want of a question it was never able to ask must not read as a
/// credential the user refused.
struct AskPassChannelTests {
    private static let unopened = AuthenticationFailure.unavailableChannel(
        reason: "No space left on device"
    )

    private static let refusedByGit = RepositoryOpenError.commandFailed(
        GitFailureDetails(
            command: "git fetch",
            output: """
                fatal: could not read Password for 'https://example.invalid': \
                terminal prompts disabled
                """,
            exitStatus: 128
        )
    )

    @Test
    func explainsAFailedCommandWithTheReasonItCouldNotAsk() {
        let channel = AskPassChannel(bridge: nil, unavailability: Self.unopened)

        let explained = channel.explaining(Self.refusedByGit) as? RepositoryOpenError

        #expect(explained?.failureDetails?.authenticationFailure == Self.unopened)
        // Only what the failure was about was added. Git's own words are still Git's own words.
        #expect(explained?.failureDetails?.output == Self.refusedByGit.failureDetails?.output)
        #expect(explained?.failureDetails?.command == Self.refusedByGit.failureDetails?.command)
    }

    /// A command that ran with a channel has nothing to explain, and its failure is left exactly
    /// as Git reported it.
    @Test
    func leavesAFailureItCannotExplainAlone() {
        let channel = AskPassChannel(bridge: nil, unavailability: nil)

        let explained = channel.explaining(Self.refusedByGit) as? RepositoryOpenError

        #expect(explained == Self.refusedByGit)
        #expect(explained?.failureDetails?.authenticationFailure == nil)
    }

    /// A channel that never opened explains only the failures it could have prevented. Everything
    /// else a remote command fails over — an unreachable host, a refused tag, a rejected push —
    /// happens the same way whether or not anybody could have been asked a question, and reporting
    /// it as an authentication problem would put the real reason out of sight.
    @Test
    func leavesAFailureThatWasNeverAboutAQuestionAlone() {
        let channel = AskPassChannel(bridge: nil, unavailability: Self.unopened)
        let unreachable = RepositoryOpenError.commandFailed(
            GitFailureDetails(
                command: "git fetch",
                output: """
                    fatal: unable to access 'https://example.invalid/repository.git/': \
                    Could not resolve host: example.invalid
                    """,
                exitStatus: 128
            )
        )

        let explained = channel.explaining(unreachable) as? RepositoryOpenError

        #expect(explained == unreachable)
        #expect(explained?.failureDetails?.authenticationFailure == nil)
    }

    /// A key that no longer matches is refused by OpenSSH whether or not a channel exists, so the
    /// missing channel explains nothing about it and must not displace what did.
    @Test
    func leavesAChangedHostKeyReadableAsOne() throws {
        let channel = AskPassChannel(bridge: nil, unavailability: Self.unopened)
        let changedKey = RepositoryOpenError.commandFailed(
            GitFailureDetails(
                command: "git fetch",
                output: """
                    @@@@@ WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED! @@@@@
                    Host key verification failed.
                    """,
                exitStatus: 128
            )
        )

        let explained = channel.explaining(changedKey) as? RepositoryOpenError

        #expect(explained?.failureDetails?.authenticationFailure == nil)
        let output = try #require(explained?.failureDetails?.output)
        #expect(AuthenticationFailure.detect(in: output) == .changedHostKey)
    }

    /// A command that never ran cannot have failed over a question. A cancellation, or a Git that
    /// was never found, keeps its own error.
    @Test
    func leavesEveryFailureThatWasNotACommandRefusingAlone() {
        let channel = AskPassChannel(bridge: nil, unavailability: Self.unopened)

        #expect(channel.explaining(CancellationError()) is CancellationError)
        #expect(
            channel.explaining(RepositoryOpenError.gitUnavailable) as? RepositoryOpenError
                == .gitUnavailable
        )
    }
}
