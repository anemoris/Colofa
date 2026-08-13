////
//  GitObjectSizeParserTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Testing
@testable import Colofa

struct GitObjectSizeParserTests {
    @Test
    func parsesLooseAndPackedKilobytes() throws {
        let output = """
        count: 3
        size: 4
        in-pack: 5
        packs: 1
        size-pack: 6
        prune-packable: 0
        garbage: 0
        size-garbage: 0
        """

        #expect(try GitObjectSizeParser.parse(output) == 10 * 1_024)
    }

    @Test
    func rejectsMissingInvalidAndOverflowingSizes() {
        #expect(throws: GitOutputParsingError.self) {
            try GitObjectSizeParser.parse("size: 4")
        }
        #expect(throws: GitOutputParsingError.self) {
            try GitObjectSizeParser.parse("size: invalid\nsize-pack: 6")
        }
        #expect(throws: GitOutputParsingError.self) {
            try GitObjectSizeParser.parse("size: -1\nsize-pack: 6")
        }
        #expect(throws: GitOutputParsingError.self) {
            try GitObjectSizeParser.parse("size: \(Int64.max)\nsize-pack: 1")
        }
    }
}
