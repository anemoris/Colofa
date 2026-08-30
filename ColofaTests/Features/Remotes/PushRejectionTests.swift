////
//  PushRejectionTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// Telling a remote that refused an update apart from a remote that was never reached, out of the
/// one part of `git push` that is written for a machine.
struct PushRejectionTests {

    /// Git spells the same refusal two ways depending on what it already knew, and both are the
    /// answer the user acts on by integrating first.
    @Test(arguments: ["(fetch first)", "(non-fast-forward)"])
    func anupdateTheUpstreamWouldLoseWorkOverIsPushRejected(_ reason: String) {
        let output = """
            To ssh://example.invalid/Colofa.git
            !\trefs/heads/main:refs/heads/main\t[rejected] \(reason)
            Done
            """

        #expect(PushRejection.detect(in: output) == .nonFastForward)
    }

    /// The lease refusing is a different event from the upstream being ahead: the user asked to
    /// replace it and was told the remote is not what they were looking at.
    @Test
    func aleaseThatNoLongerMatchesIsItsOwnAnswer() {
        let output = """
            To ssh://example.invalid/Colofa.git
            !\trefs/heads/main:refs/heads/main\t[rejected] (stale info)
            Done
            """

        #expect(PushRejection.detect(in: output) == .staleLease)
    }

    /// A Hook or a protected branch refuses the update itself, which nothing about the local
    /// Branch explains.
    @Test
    func aremoteThatDeclinedForItsOwnReasonsIsNotAfastForwardProblem() {
        let output = """
            To ssh://example.invalid/Colofa.git
            !\trefs/heads/main:refs/heads/main\t[remote rejected] (pre-receive hook declined)
            Done
            """

        #expect(PushRejection.detect(in: output) == .remoteRefused)
    }

    /// A remote nobody could reach never decided anything, so nothing here may claim it did.
    @Test(
        arguments: [
            "fatal: could not read from remote repository",
            "fatal: Authentication failed for 'https://example.invalid/'",
            "ssh: Could not resolve hostname example.invalid",
            "",
        ]
    )
    func afailureThatNeverReachedTheRemotesAnswerIsNotArejection(_ output: String) {
        #expect(PushRejection.detect(in: output) == nil)
    }

    /// An accepted Push says so on the same kind of line, and saying it was refused would be
    /// reading the report backwards.
    @Test
    func anacceptedPushIsNotArejection() {
        let output = """
            To ssh://example.invalid/Colofa.git
            \trefs/heads/main:refs/heads/main\t0000000..1111111
            Done
            """

        #expect(PushRejection.detect(in: output) == nil)
    }

    /// A stale lease is also a rejection, so the more specific answer has to win over the general
    /// one wherever Git reports both.
    @Test
    func astaleLeaseWinsOverTheGeneralRefusalItIsAlsoReportedAs() {
        let output = """
            !\trefs/heads/main:refs/heads/main\t[rejected] (stale info)
            !\trefs/heads/other:refs/heads/other\t[rejected] (fetch first)
            """

        #expect(PushRejection.detect(in: output) == .staleLease)
    }

    /// An upstream that moved on is one to integrate, and recommending the option that discards
    /// the other side's work would be recommending the thing the refusal just prevented.
    @Test
    func pushRejectedNeverRecommendsAforcePush() {
        let text = englishMessage(.nonFastForward)

        #expect(!text.localizedStandardContains("force"))
        #expect(text.localizedStandardContains("Merge"))
        #expect(text.localizedStandardContains("Rebase"))
    }

    /// Every answer names the Refs the user has to reason about, because a refusal that does not
    /// say which upstream refused is not something anybody can act on.
    @Test(arguments: [PushRejection.nonFastForward, .staleLease, .remoteRefused])
    func everyRefusalNamesTheUpstreamItIsAbout(_ rejection: PushRejection) {
        #expect(englishMessage(rejection).contains("origin/main"))
    }

    /// Read in the language these assertions are written in rather than in whatever language the
    /// machine running them is set to.
    private func englishMessage(_ rejection: PushRejection) -> String {
        var message = rejection.message(branch: "main", upstream: "origin/main")
        message.locale = Locale(identifier: "en")
        return String(localized: message)
    }
}
