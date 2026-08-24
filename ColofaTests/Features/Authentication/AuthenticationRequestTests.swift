////
//  AuthenticationRequestTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// What one question is, and which of them may be answered at all.
struct AuthenticationRequestTests {
    @Test
    func reportsAFingerprintOnlyForAHostKeyQuestion() {
        let hostKey = AuthenticationRequest(
            kind: .newHostKey(fingerprint: "SHA256:abc"),
            subject: "github.example",
            prompt: "Are you sure you want to continue connecting (yes/no/[fingerprint])?"
        )
        let password = AuthenticationRequest(
            kind: .password,
            subject: "https://github.example",
            prompt: "Password for 'https://github.example':"
        )

        #expect(hostKey.fingerprint == "SHA256:abc")
        #expect(password.fingerprint == nil)
    }

    /// Every question that has something to type is answerable, whatever it is about.
    @Test
    func answersEveryQuestionThatCanBeTypedInto() {
        for kind in [AuthenticationRequestKind.username, .password, .keyPassphrase, .unrecognized] {
            let request = AuthenticationRequest(kind: kind, subject: nil, prompt: "?")
            #expect(request.isAnswerable, "\(kind) should be answerable")
        }
    }

    /// A host with an empty fingerprint is the same as a host with none: there is nothing to
    /// compare, so there is nothing to agree to.
    @Test
    func refusesAHostKeyWithNothingToCompare() {
        for fingerprint in [nil, ""] {
            let request = AuthenticationRequest(
                kind: .newHostKey(fingerprint: fingerprint),
                subject: "github.example",
                prompt: "?"
            )
            #expect(!request.isAnswerable)
        }
    }
}
