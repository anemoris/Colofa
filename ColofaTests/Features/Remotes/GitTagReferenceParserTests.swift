////
//  GitTagReferenceParserTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// Reading tag names and the objects they point at, from both sides of a Fetch Tags.
struct GitTagReferenceParserTests {
    @Test
    func readsTheRemoteTabSeparatedListing() throws {
        let output = """
        1111111111111111111111111111111111111111\trefs/tags/v1.0
        2222222222222222222222222222222222222222\trefs/tags/发布 1
        """

        let tags = try GitTagReferenceParser.parseRemote(Data(output.utf8))

        #expect(
            tags == [
                "v1.0": "1111111111111111111111111111111111111111",
                "发布 1": "2222222222222222222222222222222222222222",
            ]
        )
    }

    @Test
    func readsTheLocalNULSeparatedListing() throws {
        let output = "1111111111111111111111111111111111111111\0refs/tags/v1.0\n"

        let tags = try GitTagReferenceParser.parseLocal(Data(output.utf8))

        #expect(tags == ["v1.0": "1111111111111111111111111111111111111111"])
    }

    @Test
    func readsNothingFromARepositoryWithNoTags() throws {
        #expect(try GitTagReferenceParser.parseLocal(Data()).isEmpty)
        #expect(try GitTagReferenceParser.parseRemote(Data()).isEmpty)
    }

    @Test
    func refusesARecordThatIsNotATag() {
        #expect(throws: GitOutputParsingError.self) {
            try GitTagReferenceParser.parseRemote(Data("1111\trefs/heads/main".utf8))
        }
    }

    @Test
    func refusesARecordWithoutBothFields() {
        #expect(throws: GitOutputParsingError.self) {
            try GitTagReferenceParser.parseRemote(Data("refs/tags/v1.0".utf8))
        }
    }
}
