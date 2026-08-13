////
//  GitRemoteParserTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

struct GitRemoteParserTests {
    @Test
    func parsesNULTerminatedRemoteConfiguration() throws {
        let output = [
            "remote.origin.url\nssh://example.invalid/项目.git",
            "remote.backup.url\nfile:///tmp/Backup Repo.git",
            "",
        ].joined(separator: "\0")

        let remotes = try GitRemoteParser.parse(Data(output.utf8))

        #expect(remotes == [
            RepositoryRemote(name: "backup", url: "file:///tmp/Backup Repo.git"),
            RepositoryRemote(name: "origin", url: "ssh://example.invalid/项目.git"),
        ])
    }

    @Test
    func rejectsMalformedRemoteConfiguration() {
        #expect(throws: GitOutputParsingError.self) {
            try GitRemoteParser.parse(Data("remote.origin.url without delimiter\0".utf8))
        }
    }
}
