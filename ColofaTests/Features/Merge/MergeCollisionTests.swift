////
//  MergeCollisionTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation
import Testing
@testable import Colofa

/// Which untracked files a refused Merge names, once Git has already refused it.
struct MergeCollisionTests {
    private func untracked(_ paths: [String]) -> [RepositoryChange] {
        paths.map { RepositoryChange(path: $0, kind: .untracked) }
    }

    @Test
    func aMergeThatAddsNothingTheTreeHoldsCollidesWithNothing() {
        let collision = MergeCollision.evaluate(
            comparison: CheckoutComparison(changedPaths: ["src.swift"], addedPaths: ["new.swift"]),
            in: mergeRepository(unstagedChanges: untracked(["notes.txt"]))
        )

        #expect(collision.isEmpty)
    }

    @Test
    func onlyTheUntrackedPathsTheMergeWouldAddAreNamed() {
        let collision = MergeCollision.evaluate(
            comparison: CheckoutComparison(
                changedPaths: ["src.swift"],
                addedPaths: ["notes.txt", "docs/guide.md", "unrelated.txt"]
            ),
            in: mergeRepository(unstagedChanges: untracked(["notes.txt", "docs/guide.md"]))
        )

        #expect(collision.paths == ["docs/guide.md", "notes.txt"])
    }

    /// Tracked work is refused before the command runs, with Commit or Stash guidance, so listing
    /// it here would explain the wrong refusal.
    @Test
    func trackedChangesAreNotReportedAsACollision() {
        let collision = MergeCollision.evaluate(
            comparison: CheckoutComparison(changedPaths: [], addedPaths: ["src.swift"]),
            in: mergeRepository(
                unstagedChanges: [RepositoryChange(path: "src.swift", kind: .modified)]
            )
        )

        #expect(collision.isEmpty)
    }

    /// An alert that listed hundreds of paths would stop being readable, so the rest are counted.
    @Test
    func aLongCollisionListEndsWithACountOfWhatDidNotFit() {
        let paths = (1...12).map { "file\($0).txt" }
        let collision = MergeCollision.evaluate(
            comparison: CheckoutComparison(changedPaths: [], addedPaths: Set(paths)),
            in: mergeRepository(unstagedChanges: untracked(paths))
        )

        let lines = collision.pathList.split(separator: "\n").map(String.init)
        #expect(lines.count == MergeCollision.listedPathLimit + 1)
        #expect(lines.last?.contains("2") == true)
    }

    @Test
    func theMessageSaysWhatToDoWithTheFilesItNames() {
        let collision = MergeCollision(paths: ["notes.txt"])

        #expect(
            englishText(collision.message)
                == """
                These untracked files would be overwritten by the Merge:

                notes.txt

                Move or remove them first.
                """
        )
    }
}
