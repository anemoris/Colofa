////
//  GitPushDestinationParserTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// Reading every address one Push would write to, which is the count that decides whether a
/// destination can be confirmed at all.
struct GitPushDestinationParserTests {
    private func parse(_ output: String) throws -> [PushDestination] {
        try GitPushDestinationParser.parse(Data(output.utf8))
    }

    @Test
    func onepushAddressIsOneDestination() throws {
        #expect(
            try parse("ssh://example.invalid/Colofa.git\n")
                == [PushDestination("ssh://example.invalid/Colofa.git")]
        )
    }

    /// The case this whole read exists for: `remote.<name>.pushurl` may be set more than once,
    /// and Git reports every one of them because it writes to every one of them.
    @Test
    func severalPushAddressesAreAllReported() throws {
        let destinations = try parse(
            """
            ssh://example.invalid/Colofa.git
            ssh://example.invalid/Mirror.git
            """
        )

        #expect(destinations.map(\.url) == [
            "ssh://example.invalid/Colofa.git",
            "ssh://example.invalid/Mirror.git",
        ])
    }

    /// Git ends its answer with a newline, which is not an address.
    @Test
    func blankLinesAreNotDestinations() throws {
        #expect(try parse("\n\nssh://example.invalid/Colofa.git\n\n").count == 1)
    }

    @Test
    func anemptyAnswerReportsNothing() throws {
        #expect(try parse("").isEmpty)
    }

    /// Git writes a Repository's own configuration back verbatim, so an answer that is not text
    /// is one this parser does not understand rather than one to guess at.
    @Test
    func answersThatAreNotTextAreRefused() {
        #expect(throws: GitOutputParsingError.self) {
            try GitPushDestinationParser.parse(Data([0xFF, 0xFE, 0xFF]))
        }
    }
}
