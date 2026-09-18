////
//  StashTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation
import Testing
@testable import Colofa

/// Which comparison each of a Stash's saved paths is read as, and which path a selection finds.
struct StashTests {
    private let repositoryURL = URL(filePath: "/tmp/Stash Model")

    private func stash(untrackedObjectID: String? = "untracked") -> Stash {
        Stash(
            selector: "stash@{0}",
            objectID: "stash",
            abbreviatedObjectID: "stas",
            baseObjectID: "base",
            untrackedObjectID: untrackedObjectID,
            message: "On main: parser rewrite",
            authorName: "Fixture Author",
            authorEmail: "fixture@example.invalid",
            authoredDate: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    private func file(
        _ path: String,
        oldPath: String? = nil,
        isUntracked: Bool
    ) -> StashFile {
        StashFile(
            summary: DiffFileSummary(
                oldPath: oldPath,
                newPath: path,
                stats: DiffStats(additions: 1, deletions: 0)
            ),
            isUntracked: isUntracked
        )
    }

    /// A tracked change is what the Stash did to the Commit it was saved on.
    @Test
    func aTrackedPathIsComparedAgainstTheCommitTheStashWasSavedOn() throws {
        let source = try #require(stash().diffSource(of: file("a.txt", isUntracked: false)))

        #expect(source == .commit(objectID: "stash", parentObjectID: "base", paths: ["a.txt"]))
    }

    /// An untracked file lives in a Commit of its own with no parent, so it is read the way a
    /// root Commit is: everything that Commit introduced, narrowed to the one path.
    @Test
    func anUntrackedPathIsComparedAgainstNothing() throws {
        let source = try #require(stash().diffSource(of: file("notes.txt", isUntracked: true)))

        #expect(source == .commit(objectID: "untracked", parentObjectID: nil, paths: ["notes.txt"]))
    }

    /// Rename detection needs both paths in the pathspec.
    @Test
    func aRenamedPathAsksForBothOfItsNames() throws {
        let source = try #require(
            stash().diffSource(of: file("new.txt", oldPath: "old.txt", isUntracked: false))
        )

        #expect(
            source == .commit(
                objectID: "stash",
                parentObjectID: "base",
                paths: ["new.txt", "old.txt"]
            )
        )
    }

    /// A pairing that cannot come from one read: a Stash that saved no untracked files has no
    /// Commit for one to have come from.
    @Test
    func anUntrackedPathOnAStashThatSavedNoneHasNoComparison() {
        #expect(
            stash(untrackedObjectID: nil)
                .diffSource(of: file("notes.txt", isUntracked: true)) == nil
        )
    }

    @Test
    func theDetailRequestCarriesEveryObjectTheReadNeeds() {
        let request = stash().detailRequest(in: repositoryURL)

        #expect(request.repositoryURL == repositoryURL)
        #expect(request.objectID == "stash")
        #expect(request.baseObjectID == "base")
        #expect(request.untrackedObjectID == "untracked")
        #expect(request.trackedSource == .commit(objectID: "stash", parentObjectID: "base"))
        #expect(request.untrackedSource == .commit(objectID: "untracked", parentObjectID: nil))
    }

    @Test
    func aStashThatSavedNoUntrackedFilesAsksForNoSecondComparison() {
        #expect(stash(untrackedObjectID: nil).detailRequest(in: repositoryURL).untrackedSource == nil)
    }

    @Test
    func theDetailFindsTheFileTheSelectionNames() throws {
        let tracked = file("a.txt", isUntracked: false)
        let untracked = file("notes.txt", isUntracked: true)
        let detail = StashDetail(objectID: "stash", files: [tracked, untracked])

        #expect(detail.file(untracked.id) == untracked)
        #expect(detail.file("nothing.txt") == nil)
    }

    /// `git rm --cached` on a file that is then edited saves the path twice: as a tracked change
    /// and as an untracked file. Each is its own row and its own comparison, so neither may stand
    /// in for the other.
    @Test
    func onePathOnBothSidesIsTwoFiles() throws {
        let tracked = file("a.txt", isUntracked: false)
        let untracked = file("a.txt", isUntracked: true)
        let detail = StashDetail(objectID: "stash", files: [tracked, untracked])

        #expect(tracked.id != untracked.id)
        #expect(detail.file(tracked.id) == tracked)
        #expect(detail.file(untracked.id) == untracked)
    }
}
