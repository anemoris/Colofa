////
//  AuthenticationFailureTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// Telling a connection that was refused apart from a remote that could not be reached.
struct AuthenticationFailureTests {

    /// The failure Colofa must never smooth over, read out of OpenSSH's own warning.
    @Test
    func readsAChangedHostKeyOutOfOpenSSHsWarning() {
        let output = """
            @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
            @    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @
            @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
            Host key verification failed.
            fatal: Could not read from remote repository.
            """

        #expect(AuthenticationFailure.detect(in: output) == .changedHostKey)
    }

    /// A changed key also fails verification, so the general answer must not hide the specific
    /// one.
    @Test
    func prefersTheChangedKeyOverTheVerificationItAlsoFailed() {
        #expect(
            AuthenticationFailure.detect(
                in: "HOST IDENTIFICATION HAS CHANGED\nHost key verification failed."
            ) == .changedHostKey
        )
    }

    @Test
    func readsAnUnverifiedHostOutOfWhatOpenSSHWrote() {
        #expect(
            AuthenticationFailure.detect(
                in: "Host key verification failed.\nfatal: Could not read from remote repository."
            ) == .unverifiedHostKey
        )
    }

    @Test
    func readsAnUnansweredCredentialQuestionOutOfWhatGitWrote() {
        #expect(
            AuthenticationFailure.detect(
                in: "fatal: could not read Username for 'https://x': terminal prompts disabled"
            ) == .declinedCredentials
        )
        #expect(
            AuthenticationFailure.detect(
                in: "fatal: could not read Password for 'https://x': No such device or address"
            ) == .declinedCredentials
        )
    }

    /// A remote nobody could reach says nothing about authentication and must not be dressed up
    /// as though it did.
    @Test
    func saysNothingAboutAFailureThatWasNotAboutAuthentication() {
        #expect(
            AuthenticationFailure.detect(in: "fatal: could not read from remote repository") == nil
        )
        #expect(AuthenticationFailure.detect(in: "") == nil)
    }

    /// A refusal Colofa decided is classified by the question it refused, because the question
    /// is redacted out of everything the command reports afterwards.
    @Test
    func classifiesARefusedQuestionByWhatItAsked() {
        #expect(AuthenticationFailure.refusing(.changedHostKey) == .changedHostKey)
        #expect(
            AuthenticationFailure.refusing(.newHostKey(fingerprint: nil)) == .unverifiedHostKey
        )
        #expect(
            AuthenticationFailure.refusing(.newHostKey(fingerprint: "SHA256:0oIf")) == .unverifiedHostKey
        )
        for kind: AuthenticationRequestKind in [.username, .password, .keyPassphrase, .unrecognized] {
            #expect(AuthenticationFailure.refusing(kind) == .declinedCredentials)
        }
    }

    /// Each failure explains itself rather than falling back to another one's copy.
    @Test
    func givesEveryFailureItsOwnCopy() {
        let failures: [AuthenticationFailure] = [
            .changedHostKey,
            .unverifiedHostKey,
            .declinedCredentials,
            .unavailableChannel(reason: "No space left on device"),
        ]

        #expect(Set(failures.map(\.title.key)).count == failures.count)
        #expect(Set(failures.map(\.message.key)).count == failures.count)
    }
}
