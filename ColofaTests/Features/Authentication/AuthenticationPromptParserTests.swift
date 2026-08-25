////
//  AuthenticationPromptParserTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// Every question Git and OpenSSH actually ask, read the way they actually write it.
///
/// The prompts below are the real ones, punctuation and all. Classifying them is what decides
/// whether an answer is hidden while it is typed, whether a fingerprint is put in front of the
/// user, and whether the question is refused outright.
struct AuthenticationPromptParserTests {
    @Test
    func readsAnHTTPSAccountNameQuestion() {
        let request = AuthenticationPromptParser.request(
            for: "Username for 'https://github.example': "
        )

        #expect(request.kind == .username)
        #expect(request.subject == "https://github.example")
        #expect(!request.kind.isSecret)
        #expect(request.isAnswerable)
    }

    @Test
    func readsAnHTTPSPasswordQuestionAsASecret() {
        let request = AuthenticationPromptParser.request(
            for: "Password for 'https://octocat@github.example': "
        )

        #expect(request.kind == .password)
        #expect(request.subject == "https://octocat@github.example")
        #expect(request.kind.isSecret)
    }

    /// OpenSSH's own passphrase question, which names the key file rather than a remote.
    @Test
    func readsAnSSHKeyPassphraseQuestion() {
        let request = AuthenticationPromptParser.request(
            for: "Enter passphrase for key '/Users/colofa/.ssh/id_ed25519': "
        )

        #expect(request.kind == .keyPassphrase)
        #expect(request.subject == "/Users/colofa/.ssh/id_ed25519")
        #expect(request.kind.isSecret)
    }

    /// `ssh-add` writes the same question without quoting the path.
    /// The same question as `ssh-keygen` writes it, which quotes the key with double quotes
    /// rather than Git's single ones. Reading only Git's would leave the marks in the name the
    /// user is shown.
    @Test
    func readsAPassphraseQuestionQuotedTheWaySSHKeygenQuotesIt() {
        let request = AuthenticationPromptParser.request(
            for: "Enter passphrase for \"/Users/colofa/.ssh/id_ed25519\": "
        )

        #expect(request.kind == .keyPassphrase)
        #expect(request.subject == "/Users/colofa/.ssh/id_ed25519")
    }

    @Test
    func readsAnUnquotedPassphraseQuestion() {
        let request = AuthenticationPromptParser.request(
            for: "Enter passphrase for /Users/colofa/.ssh/id_rsa: "
        )

        #expect(request.kind == .keyPassphrase)
        #expect(request.subject == "/Users/colofa/.ssh/id_rsa")
    }

    /// A host OpenSSH has never seen arrives as the whole warning, and the fingerprint inside it
    /// is what the user has to recognize.
    @Test
    func readsANewHostQuestionWithItsFingerprint() {
        let fingerprint = "SHA256:8mFqR2vDpZ0oXbLcE7yTnW1sKjA5gHuQiN3rYxV6dPw"
        let request = AuthenticationPromptParser.request(
            for: """
            The authenticity of host 'github.example (203.0.113.9)' can't be established.
            ED25519 key fingerprint is \(fingerprint).
            This key is not known by any other names.
            Are you sure you want to continue connecting (yes/no/[fingerprint])?
            """
        )

        #expect(request.kind == .newHostKey(fingerprint: fingerprint))
        #expect(request.fingerprint == fingerprint)
        #expect(request.subject == "github.example")
        #expect(request.kind.isConfirmation)
        #expect(request.isAnswerable)
    }

    /// A host key question with nothing to compare cannot be confirmed, because agreeing to it
    /// would be agreeing to something unread.
    @Test
    func refusesANewHostQuestionThatCarriesNoFingerprint() {
        let request = AuthenticationPromptParser.request(
            for: "Are you sure you want to continue connecting (yes/no/[fingerprint])? "
        )

        #expect(request.kind == .newHostKey(fingerprint: nil))
        #expect(!request.isAnswerable)
    }

    /// The one question Colofa answers itself. Its warning ends with the same offer to continue
    /// that a new host's does, so reading them in the wrong order would turn a refusal into a
    /// prompt.
    @Test
    func refusesAChangedHostKeyRatherThanAskingAboutIt() {
        let request = AuthenticationPromptParser.request(
            for: """
            @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
            @    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @
            @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
            The ED25519 host key for github.example has changed,
            and the key for the corresponding IP address is unknown.
            Are you sure you want to continue connecting (yes/no/[fingerprint])?
            """
        )

        #expect(request.kind == .changedHostKey)
        #expect(request.kind.isRefused)
        #expect(!request.isAnswerable)
    }

    /// OpenSSH's other wording for the same thing.
    @Test
    func refusesAHostKeyReportedAsJustChanged() {
        let request = AuthenticationPromptParser.request(
            for: "The host key has just been changed. Continue connecting?"
        )

        #expect(request.kind == .changedHostKey)
    }

    /// A question Colofa cannot place is still asked, and is asked secretly: an unrecognized
    /// question is more likely to be about a secret than not.
    @Test
    func asksAnUnrecognizedQuestionSecretly() {
        let request = AuthenticationPromptParser.request(for: "Insert your smart card and press y")

        #expect(request.kind == .unrecognized)
        #expect(request.kind.isSecret)
        #expect(request.isAnswerable)
    }

    /// The question is kept exactly as asked, minus the trailing space every prompt ends with.
    @Test
    func keepsTheQuestionAsItWasAsked() {
        let request = AuthenticationPromptParser.request(for: "  Username for 'https://x': \n")

        #expect(request.prompt == "Username for 'https://x':")
    }

    /// A prompt that names nobody yields no subject rather than a fabricated one.
    @Test
    func reportsNoSubjectWhenTheQuestionNamesNobody() {
        #expect(AuthenticationPromptParser.request(for: "Password:").subject == nil)
    }

    /// Two requests for the same question are still two requests: an answer belongs to the prompt
    /// it was typed into, and nothing else may consume it.
    @Test
    func identifiesEveryQuestionSeparately() {
        let prompt = "Password for 'https://github.example': "
        let first = AuthenticationPromptParser.request(for: prompt)
        let second = AuthenticationPromptParser.request(for: prompt)

        #expect(first.id != second.id)
        #expect(first != second)
    }
}
