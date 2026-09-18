////
//  GitStashCommandTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation
import Testing
@testable import Colofa

/// What Colofa asks Git for when it reads the Stash list.
struct GitStashCommandTests {
    @Test
    func theListIsReadWithoutTakingALock() {
        #expect(GitStashCommand.list.first == "--no-optional-locks")
        #expect(GitStashCommand.list.contains("stash"))
        #expect(GitStashCommand.list.contains("list"))
    }

    /// Colour, signature verification, and notes each append output that is not part of the
    /// record being parsed.
    @Test(arguments: ["--no-color", "--no-show-signature", "--no-notes"])
    func everyOutputAConfigurationCouldAddIsTurnedOff(option: String) {
        #expect(GitStashCommand.list.contains(option))
    }

    @Test
    func theListAsksForTheRecordFormatItParses() {
        #expect(GitStashCommand.list.contains("--format=\(GitStashCommand.recordFormat)"))
    }

    /// The address, the object, its parents, who saved it when, and Git's own description of it.
    @Test(arguments: ["%gd", "%H", "%h", "%P", "%an", "%ae", "%at", "%gs"])
    func theRecordCarriesEveryFieldARowNeeds(placeholder: String) {
        #expect(GitStashCommand.recordFormat.contains(placeholder))
    }

    /// Every field ends in NUL, the one byte nothing in a record can hold. A printable separator
    /// would not do: Git keeps a `0x1e` a message carried in the description it stores.
    @Test
    func recordsAreNULTerminatedFieldsWithNoOtherSeparator() {
        #expect(GitStashCommand.list.contains("-z"))
        #expect(GitStashCommand.recordFormat.contains("%x00"))
        #expect(!GitStashCommand.recordFormat.contains("%x1e"))
    }

    /// The parser counts records by these, so the format and the count must be one list.
    @Test
    func theFormatIsExactlyTheRecordFields() {
        #expect(
            GitStashCommand.recordFormat.components(separatedBy: "%x00")
                == GitStashCommand.recordFields
        )
    }
}
