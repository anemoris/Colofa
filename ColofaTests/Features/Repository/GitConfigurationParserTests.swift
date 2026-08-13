////
//  GitConfigurationParserTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation
import Testing
@testable import Colofa

struct GitConfigurationParserTests {
    @Test
    func parsesOriginsScopesEmptyValuesAndEffectivePrecedence() throws {
        let output = Data((
            "system\0file:/etc/gitconfig\0user.name\nSystem Name\0"
                + "global\0file:/home/test/.gitconfig\0user.name\nGlobal Name\0"
                + "global\0file:/home/test/included.gitconfig\0http.proxy\n\0"
                + "local\0file:.git/config\0user.name\nLocal Name\0"
                + "local\0file:.git/config\0user.email\nlocal@example.invalid\0"
        ).utf8)

        let configuration = try GitConfigurationParser.parse(output)

        #expect(configuration.entries.count == 5)
        #expect(configuration.effectiveEntry(for: .userName)?.value == "Local Name")
        #expect(configuration.effectiveEntry(for: .userName)?.scope == .local)
        #expect(configuration.effectiveEntry(for: .httpProxy)?.value == "")
        #expect(
            configuration.effectiveEntry(for: .httpProxy)?.origin.location
                == "/home/test/included.gitconfig"
        )
        #expect(configuration.hasEntry(for: .userName, in: .global))
        #expect(configuration.hasEffectiveIdentity)
    }

    @Test
    func ignoresUnsupportedKeysWithoutChangingSupportedValues() throws {
        let output = Data((
            "global\0file:/home/test/.gitconfig\0core.editor\nvim\0"
                + "global\0file:/home/test/.gitconfig\0user.email\nemail@example.invalid\0"
        ).utf8)

        let configuration = try GitConfigurationParser.parse(output)

        #expect(configuration.entries.count == 1)
        #expect(configuration.effectiveEntry(for: .userEmail)?.value == "email@example.invalid")
    }

    @Test
    func rejectsRecordsMissingScopeOriginOrKeyFields() {
        #expect(throws: GitOutputParsingError()) {
            try GitConfigurationParser.parse(
                Data("global\0file:/tmp/config".utf8)
            )
        }
    }

    /// A key declared without `=` reaches us as a bare key with no value line. Git treats it as
    /// an implicit boolean, so it must not fail the load of an otherwise healthy repository.
    @Test
    func readsValuelessKeysAsEmptyWithoutFailingTheWholeSnapshot() throws {
        let output = Data((
            "global\0file:/home/test/.gitconfig\0user.name\nGlobal Name\0"
                + "local\0file:.git/config\0user.name\0"
                + "local\0file:.git/config\0user.email\nlocal@example.invalid\0"
        ).utf8)

        let configuration = try GitConfigurationParser.parse(output)

        #expect(configuration.entries.count == 3)
        #expect(configuration.effectiveEntry(for: .userName)?.value == "")
        #expect(configuration.effectiveEntry(for: .userName)?.scope == .local)
        #expect(configuration.effectiveEntry(for: .userEmail)?.value == "local@example.invalid")
        #expect(!configuration.hasEffectiveIdentity)
    }
}
