////
//  GitSecretRedactionTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// What a running command learned that must never reach a failure message.
struct GitSecretRedactionTests {
    /// Every form of a multi-line answer, so a message quoting one line of it cannot leave the
    /// other behind, and longest first because that is the order redaction has to apply them in.
    @Test
    func recordsEveryFormOfAValueLongestFirst() {
        let secrets = GitSecretRedaction()
        secrets.record("  hunter2\ntoken  ")

        let values = secrets.values
        #expect(values.contains("hunter2\ntoken"))
        #expect(values.contains { $0.contains("hunter2") })
        #expect(values.contains { $0.contains("token") })
        #expect(values == values.sorted { $0.count > $1.count })
    }

    /// Redaction replaces the longest match first, so a message quoting part of a secret cannot
    /// leave the rest of it behind.
    @Test
    func removesARecordedValueFromWhatGitWrote() {
        let secrets = GitSecretRedaction()
        secrets.record("ghp_ExampleTokenValue")

        let redacted = GitOutputRedaction.redactingSensitiveValues(
            secrets.values,
            in: "remote: Invalid credentials for ghp_ExampleTokenValue"
        )

        #expect(!redacted.contains("ghp_ExampleTokenValue"))
        #expect(redacted.contains("<Sensitive Input>"))
    }

    /// Redaction replaces whole words and a space is a word boundary, so an answer that is only
    /// whitespace must record nothing: recording it would blank out the spacing of every message
    /// Git wrote.
    @Test
    func recordsNothingForAnEmptyValue() {
        let secrets = GitSecretRedaction()
        secrets.record("")
        secrets.record("   \n  ")

        #expect(secrets.values.isEmpty)
    }

    /// The same answer given twice is one value, not two.
    @Test
    func recordsOneValueOnce() {
        let secrets = GitSecretRedaction()
        secrets.record("hunter2")
        secrets.record("hunter2")

        #expect(secrets.values == ["hunter2"])
    }
}
