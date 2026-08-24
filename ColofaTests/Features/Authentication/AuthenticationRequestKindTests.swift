////
//  AuthenticationRequestKindTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// What each question allows, which is what the prompt is built out of.
struct AuthenticationRequestKindTests {
    private static let everyKind: [AuthenticationRequestKind] = [
        .username,
        .password,
        .keyPassphrase,
        .newHostKey(fingerprint: "SHA256:abc"),
        .changedHostKey,
        .unrecognized,
    ]

    /// A username is read back to the user as they type it; everything typed as an answer to an
    /// unclassified question is not.
    @Test
    func hidesEveryTypedAnswerExceptAnAccountName() {
        #expect(!AuthenticationRequestKind.username.isSecret)
        #expect(AuthenticationRequestKind.password.isSecret)
        #expect(AuthenticationRequestKind.keyPassphrase.isSecret)
        #expect(AuthenticationRequestKind.unrecognized.isSecret)
    }

    /// A host key is recognized, not entered.
    @Test
    func treatsOnlyANewHostKeyAsAConfirmation() {
        let confirmations = Self.everyKind.filter(\.isConfirmation)

        #expect(confirmations == [.newHostKey(fingerprint: "SHA256:abc")])
    }

    /// Exactly one question has no answer Colofa will pass on.
    @Test
    func refusesOnlyAChangedHostKey() {
        #expect(Self.everyKind.filter(\.isRefused) == [.changedHostKey])
    }

    /// OpenSSH reads the literal word, so it is not localized with the rest of the prompt.
    @Test
    func agreesInTheWordOpenSSHReads() {
        #expect(AuthenticationRequestKind.confirmation == "yes")
    }

    /// Every question names what it is about in the user's own vocabulary rather than in Git's.
    @Test
    func labelsWhatEachQuestionIsAbout() {
        #expect(AuthenticationRequestKind.username.subjectLabel.key == "remote")
        #expect(AuthenticationRequestKind.password.subjectLabel.key == "remote")
        #expect(AuthenticationRequestKind.keyPassphrase.subjectLabel.key == "authenticationKey")
        #expect(AuthenticationRequestKind.changedHostKey.subjectLabel.key == "authenticationHost")
        #expect(AuthenticationRequestKind.unrecognized.subjectLabel.key == "authenticationSubject")
    }

    /// Every question has its own title, message, field label, and button, so no prompt falls
    /// back to another one's copy.
    @Test
    func givesEveryQuestionItsOwnCopy() {
        let titles = Set(Self.everyKind.map(\.title.key))
        let messages = Set(Self.everyKind.map(\.message.key))

        #expect(titles.count == Self.everyKind.count)
        #expect(messages.count == Self.everyKind.count)
        #expect(
            AuthenticationRequestKind.newHostKey(fingerprint: "SHA256:abc").submitTitle.key
                == "authenticationTrustHost"
        )
        #expect(AuthenticationRequestKind.password.submitTitle.key == "authenticationContinue")
    }
}
