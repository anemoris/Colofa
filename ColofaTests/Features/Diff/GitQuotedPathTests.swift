////
//  GitQuotedPathTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

struct GitQuotedPathTests {
    @Test
    func leavesAnUnquotedPathAlone() {
        #expect(GitQuotedPath.decoded("Sources/名称.swift") == "Sources/名称.swift")
        #expect(GitQuotedPath.decoded("\"") == "\"")
    }

    @Test
    func decodesTheEscapesGitWrites() {
        #expect(GitQuotedPath.decoded("\"tab\\there\"") == "tab\there")
        #expect(GitQuotedPath.decoded("\"quote\\\"here\"") == "quote\"here")
        #expect(GitQuotedPath.decoded("\"back\\\\slash\"") == "back\\slash")
        #expect(GitQuotedPath.decoded("\"line\\nbreak\"") == "line\nbreak")
    }

    @Test
    func decodesOctalEscapesAsBytesOfOneCharacter() {
        // Git escapes each byte of "é" separately when it quotes a path.
        #expect(GitQuotedPath.decoded("\"caf\\303\\251\"") == "café")
    }

    @Test
    func splitsAQuotedTokenFromWhatFollowsIt() throws {
        let split = try #require(GitQuotedPath.splitQuoted("\"a/od\\td.bin\" \"b/od\\td.bin\""))

        #expect(split.quoted == "a/od\td.bin")
        #expect(split.remainder == "\"b/od\\td.bin\"")
        #expect(GitQuotedPath.splitQuoted("a/plain b/plain") == nil)
        #expect(GitQuotedPath.splitQuoted("\"never closed") == nil)
    }
}
