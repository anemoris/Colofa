////
//  GitStashParserTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation
import Testing
@testable import Colofa

/// Reading the field stream `git stash list -z` writes.
struct GitStashParserTests {
    private func record(
        selector: String = "stash@{0}",
        objectID: String = "b6f099be23cb1c196838f0ccf785b00dfdb29ec1",
        abbreviated: String = "b6f099b",
        parents: String = "b680b3d 7abb5e6",
        authorName: String = "Fixture Author",
        authorEmail: String = "fixture@example.invalid",
        timestamp: String = "1788965867",
        message: String = "On main: parser rewrite"
    ) -> String {
        let fields = [
            selector, objectID, abbreviated, parents,
            authorName, authorEmail, timestamp, message,
        ]
        // `-z` terminates every field, the record's last one included, with NUL.
        return fields.map { $0 + "\u{0}" }.joined()
    }

    private func parse(_ text: String) throws -> [Stash] {
        try GitStashParser.parse(Data(text.utf8))
    }

    @Test
    func aRecordBecomesTheEntryGitDescribed() throws {
        let stashes = try parse(record())

        #expect(stashes.count == 1)
        let stash = try #require(stashes.first)
        #expect(stash.selector == "stash@{0}")
        #expect(stash.id == "stash@{0}")
        #expect(stash.objectID == "b6f099be23cb1c196838f0ccf785b00dfdb29ec1")
        #expect(stash.abbreviatedObjectID == "b6f099b")
        #expect(stash.baseObjectID == "b680b3d")
        #expect(stash.authorName == "Fixture Author")
        #expect(stash.authorEmail == "fixture@example.invalid")
        #expect(stash.authoredDate == Date(timeIntervalSince1970: 1_788_965_867))
        // Git's own words, prefix and all: trimming it would claim the entry says something else.
        #expect(stash.message == "On main: parser rewrite")
    }

    /// Two parents is a Stash that saved nothing untracked; the third parent is where Git puts
    /// the untracked files when it did.
    @Test
    func twoParentsMeanNoUntrackedFilesWereSaved() throws {
        let stash = try #require(try parse(record(parents: "base index")).first)

        #expect(stash.untrackedObjectID == nil)
        #expect(!stash.includesUntrackedFiles)
    }

    @Test
    func aThirdParentIsTheUntrackedFilesTheStashSaved() throws {
        let stash = try #require(try parse(record(parents: "base index untracked")).first)

        #expect(stash.untrackedObjectID == "untracked")
        #expect(stash.includesUntrackedFiles)
    }

    @Test
    func everyRecordInTheStreamIsRead() throws {
        let stashes = try parse(
            record(selector: "stash@{0}", objectID: "aaa")
                + record(selector: "stash@{1}", objectID: "bbb")
        )

        #expect(stashes.map(\.selector) == ["stash@{0}", "stash@{1}"])
        #expect(stashes.map(\.objectID) == ["aaa", "bbb"])
    }

    @Test
    func noEntriesReadAsAnEmptyList() throws {
        #expect(try parse("").isEmpty)
    }

    /// A description holding a newline is still one record: only the count of fields ends one.
    @Test
    func aDescriptionMayHoldANewline() throws {
        let stash = try #require(try parse(record(message: "On main: first\nsecond")).first)

        #expect(stash.message == "On main: first\nsecond")
    }

    /// Git keeps a `0x1e` a message carried in the description it stores, so no printable byte can
    /// be what separates one record from the next.
    @Test
    func aDescriptionMayHoldTheASCIIRecordSeparator() throws {
        let stashes = try parse(
            record(selector: "stash@{0}", message: "On main: subject\u{1e}separator")
                + record(selector: "stash@{1}", message: "On main: next")
        )

        #expect(stashes.map(\.selector) == ["stash@{0}", "stash@{1}"])
        #expect(stashes.first?.message == "On main: subject\u{1e}separator")
    }

    /// Git ends the stream with the last record's NUL; a stream missing it was cut off mid-field.
    @Test
    func aStreamThatStopsMidFieldIsRefused() {
        #expect(throws: GitOutputParsingError.self) {
            try parse(String(record().dropLast()))
        }
    }

    /// Records are counted rather than separated, so a stream one field short would shift every
    /// later entry onto the wrong fields.
    @Test
    func aStreamThatDoesNotDivideIntoWholeRecordsIsRefused() {
        #expect(throws: GitOutputParsingError.self) {
            try parse(record() + "stash@{1}\u{0}")
        }
    }

    /// A record Colofa cannot read is a failure rather than a row with holes in it: a list that
    /// quietly dropped an entry would read as everything the user had saved.
    @Test
    func aRecordWithTooFewFieldsIsRefused() {
        #expect(throws: GitOutputParsingError.self) {
            try parse("stash@{0}\u{0}abc\u{0}")
        }
    }

    @Test
    func aRecordWithAnUnreadableTimeIsRefused() {
        #expect(throws: GitOutputParsingError.self) {
            try parse(record(timestamp: "not a time"))
        }
    }

    /// Every Stash Git builds has the Commit it was saved on and the index at the time, so a
    /// record with fewer parents is not one this parser understands.
    @Test(arguments: ["", "onlyone"])
    func aRecordWithTooFewParentsIsRefused(parents: String) {
        #expect(throws: GitOutputParsingError.self) {
            try parse(record(parents: parents))
        }
    }

    @Test
    func aRecordWithNoObjectIDIsRefused() {
        #expect(throws: GitOutputParsingError.self) {
            try parse(record(objectID: ""))
        }
    }
}
