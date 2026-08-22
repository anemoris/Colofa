////
//  TagFetchConflictTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// Which local tags a Fetch Tags left alone, and how the refusal names them.
struct TagFetchConflictTests {
    private let local = "1111111111111111111111111111111111111111"
    private let remote = "2222222222222222222222222222222222222222"

    @Test
    func namesATagBothSidesHoldAtDifferentObjects() {
        let conflict = TagFetchConflict.evaluate(
            remoteTags: ["v1.0": remote],
            localTags: ["v1.0": local]
        )

        #expect(conflict.tags == ["v1.0"])
        #expect(!conflict.isEmpty)
    }

    /// A tag only the remote holds is one the Fetch adds, and a tag both hold at the same object
    /// is one it leaves alone. Neither is a refusal.
    @Test
    func ignoresTagsThatAreAddedOrAlreadyAgree() {
        let conflict = TagFetchConflict.evaluate(
            remoteTags: ["v1.0": local, "v2.0": remote],
            localTags: ["v1.0": local]
        )

        #expect(conflict.isEmpty)
    }

    /// A tag only the Repository holds is untouched, because an explicit Fetch Tags never prunes.
    @Test
    func ignoresATagTheRemoteDoesNotHave() {
        let conflict = TagFetchConflict.evaluate(
            remoteTags: [:],
            localTags: ["local-only": local]
        )

        #expect(conflict.isEmpty)
    }

    @Test
    func listsConflictingTagsInAStableOrder() {
        let conflict = TagFetchConflict.evaluate(
            remoteTags: ["b": remote, "a": remote, "c": remote],
            localTags: ["b": local, "a": local, "c": local]
        )

        #expect(conflict.tags == ["a", "b", "c"])
        #expect(conflict.tagList == "a\nb\nc")
    }

    /// A remote that disagrees about hundreds of tags still produces an alert somebody can read.
    @Test
    func summarizesTheTagsThatDoNotFit() {
        let names = (1...12).map { "v\($0)" }
        let conflict = TagFetchConflict(tags: names)

        let lines = conflict.tagList.split(separator: "\n")
        #expect(lines.count == TagFetchConflict.listedTagLimit + 1)
        #expect(
            lines.prefix(TagFetchConflict.listedTagLimit).map(String.init)
                == Array(names.prefix(TagFetchConflict.listedTagLimit))
        )
        #expect(lines.last?.contains("2") == true)
    }

    @Test
    func listsEveryTagWhenTheyAllFit() {
        let conflict = TagFetchConflict(tags: ["a", "b"])

        #expect(conflict.tagList == "a\nb")
    }

    // MARK: - Reading a refusal

    /// Git's rejection line names the ref it kept, and the ref name is the part of that line
    /// Git does not translate.
    @Test(
        arguments: [
            " ! [rejected]        v1.0       -> v1.0  (would clobber existing tag)",
            " ! [已拒绝]           v1.0       -> v1.0  (会覆盖现有的标签)",
        ]
    )
    func readsARefusalThatNamesTheTag(_ output: String) {
        #expect(TagFetchConflict(tags: ["v1.0"]).isNamed(in: output))
    }

    /// A Hook, a bad refspec, or an unreachable remote fails the same command. A remote that
    /// happens to disagree about a tag name is not why any of those failed.
    @Test(
        arguments: [
            "fatal: could not read from remote repository",
            "error: hook declined to update refs/tags/other",
            "",
        ]
    )
    func readsAFailureAboutSomethingElseAsUnexplained(_ output: String) {
        #expect(!TagFetchConflict(tags: ["v1.0"]).isNamed(in: output))
    }

    /// A name is matched whole, so a refusal about one tag is not read as a refusal about
    /// another whose name it starts with.
    @Test
    func doesNotReadOneTagNameInsideAnother() {
        let output = " ! [rejected]  v1.0.1 -> v1.0.1  (would clobber existing tag)"

        #expect(!TagFetchConflict(tags: ["v1.0"]).isNamed(in: output))
        #expect(TagFetchConflict(tags: ["v1.0", "v1.0.1"]).isNamed(in: output))
    }

    /// Nothing to name means nothing to explain, whatever Git wrote.
    @Test
    func readsNoConflictAsExplainingNothing() {
        #expect(!TagFetchConflict.empty.isNamed(in: " ! [rejected] v1.0 -> v1.0"))
    }
}
