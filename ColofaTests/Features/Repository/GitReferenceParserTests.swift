////
//  GitReferenceParserTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

struct GitReferenceParserTests {
    @Test
    func groupsRealReferencesAndOmitsSymbolicRemoteHead() throws {
        let output = """
        refs/heads/feat/真实状态\0
        refs/heads/main\0
        refs/remotes/origin/HEAD\0refs/remotes/origin/main
        refs/remotes/origin/main\0
        refs/tags/v1.0 β\0
        """

        let references = try GitReferenceParser.parse(Data(output.utf8))

        #expect(references.localBranches == ["feat/真实状态", "main"])
        #expect(references.remoteBranches == ["origin/main"])
        #expect(references.tags == ["v1.0 β"])
    }

    @Test
    func rejectsMalformedReferenceOutput() {
        #expect(throws: GitOutputParsingError.self) {
            try GitReferenceParser.parse(Data("refs/heads/main\n".utf8))
        }
    }
}
