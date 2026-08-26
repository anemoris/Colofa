////
//  CheckoutObstructionTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

struct CheckoutObstructionTests {
    private static let repositoryURL = URL(filePath: "/tmp/colofa-branch-tests")

    private static func snapshot(
        staged: [RepositoryChange] = [],
        unstaged: [RepositoryChange] = []
    ) -> RepositorySnapshot {
        repository(
            at: repositoryURL,
            head: .branch("main"),
            stagedChanges: staged,
            unstagedChanges: unstaged
        )
    }

    /// A local change to a path the Ref also changes is exactly what Git protects.
    @Test
    func namesTrackedChangesTheRefWouldOverwrite() {
        let obstruction = CheckoutObstruction.evaluate(
            comparison: CheckoutComparison(
                changedPaths: ["shared.swift", "elsewhere.swift"],
                addedPaths: []
            ),
            in: Self.snapshot(
                unstaged: [RepositoryChange(path: "shared.swift", kind: .modified)]
            )
        )

        #expect(obstruction.modifiedPaths == ["shared.swift"])
        #expect(obstruction.untrackedPaths.isEmpty)
        #expect(!obstruction.isEmpty)
    }

    /// A Staged Change is local work too, and Git refuses to overwrite it just the same.
    @Test
    func namesStagedChangesTheRefWouldOverwrite() {
        let obstruction = CheckoutObstruction.evaluate(
            comparison: CheckoutComparison(changedPaths: ["staged.swift"], addedPaths: []),
            in: Self.snapshot(
                staged: [RepositoryChange(path: "staged.swift", kind: .modified)]
            )
        )

        #expect(obstruction.modifiedPaths == ["staged.swift"])
    }

    /// An untracked file is only in the way where the Ref actually writes a file of that name.
    @Test
    func namesOnlyUntrackedFilesTheRefWouldWriteOver() {
        let obstruction = CheckoutObstruction.evaluate(
            comparison: CheckoutComparison(
                changedPaths: ["arriving.swift", "changed.swift"],
                addedPaths: ["arriving.swift"]
            ),
            in: Self.snapshot(
                unstaged: [
                    RepositoryChange(path: "arriving.swift", kind: .untracked),
                    RepositoryChange(path: "unrelated.swift", kind: .untracked),
                ]
            )
        )

        #expect(obstruction.untrackedPaths == ["arriving.swift"])
        #expect(obstruction.modifiedPaths.isEmpty)
    }

    /// A rename is one Change over two paths, and either of them can be the one in the way.
    @Test
    func namesBothPathsOfALocalRename() {
        let obstruction = CheckoutObstruction.evaluate(
            comparison: CheckoutComparison(changedPaths: ["old.swift"], addedPaths: []),
            in: Self.snapshot(
                staged: [RepositoryChange(path: "new.swift", kind: .renamed(from: "old.swift"))]
            )
        )

        #expect(obstruction.modifiedPaths == ["old.swift"])
    }

    /// An unmerged path is refused before a Checkout is ever attempted, so listing it here would
    /// explain the wrong refusal.
    @Test
    func leavesConflictsOutOfTheRefusal() {
        let obstruction = CheckoutObstruction.evaluate(
            comparison: CheckoutComparison(changedPaths: ["conflict.txt"], addedPaths: []),
            in: Self.snapshot(
                unstaged: [RepositoryChange(path: "conflict.txt", kind: .conflict)]
            )
        )

        #expect(obstruction.isEmpty)
    }

    /// A change to a path the Ref does not touch is carried along, not refused.
    @Test
    func reportsNothingWhenTheRefTouchesNoChangedPath() {
        let obstruction = CheckoutObstruction.evaluate(
            comparison: CheckoutComparison(changedPaths: ["elsewhere.swift"], addedPaths: []),
            in: Self.snapshot(
                unstaged: [RepositoryChange(path: "local.swift", kind: .modified)]
            )
        )

        #expect(obstruction.isEmpty)
    }

    /// Committing an untracked file is not what Git asks for, so the guidance differs by what is
    /// actually in the way.
    @Test
    func choosesItsGuidanceByWhatIsInTheWay() {
        let tracked = CheckoutObstruction(modifiedPaths: ["a.swift"], untrackedPaths: [])
        let untracked = CheckoutObstruction(modifiedPaths: [], untrackedPaths: ["b.swift"])
        let both = CheckoutObstruction(modifiedPaths: ["a.swift"], untrackedPaths: ["b.swift"])

        #expect(String(localized: tracked.message).contains("a.swift"))
        #expect(String(localized: untracked.message).contains("b.swift"))
        #expect(String(localized: both.message).contains("a.swift"))
        #expect(String(localized: tracked.message) != String(localized: untracked.message))
        #expect(String(localized: both.message) != String(localized: tracked.message))
    }

    /// A Checkout can be blocked by hundreds of paths, and an alert listing all of them stops
    /// being readable.
    @Test
    func summarizesThePathsThatDoNotFit() {
        let paths = (0..<15).map { "file\($0).swift" }
        let obstruction = CheckoutObstruction(modifiedPaths: paths, untrackedPaths: [])

        let listed = obstruction.pathList.split(separator: "\n")
        #expect(listed.count == CheckoutObstruction.listedPathLimit + 1)
        #expect(listed.last?.contains("5") == true)
    }

    /// Tracked work comes first: it is what Git protected, and an untracked file merely sitting
    /// in the way is the easier one to move.
    @Test
    func listsTrackedWorkBeforeUntrackedFiles() {
        let obstruction = CheckoutObstruction(
            modifiedPaths: ["z-tracked.swift"],
            untrackedPaths: ["a-untracked.swift"]
        )

        #expect(obstruction.paths == ["z-tracked.swift", "a-untracked.swift"])
    }

    /// The same protected work explains a refused Pull, but the guidance has to name the command
    /// the user actually pressed.
    @Test
    func namesPullRatherThanCheckoutWhenAPullWasRefused() {
        let tracked = CheckoutObstruction(modifiedPaths: ["a.swift"], untrackedPaths: [])
        let untracked = CheckoutObstruction(modifiedPaths: [], untrackedPaths: ["b.swift"])
        let both = CheckoutObstruction(modifiedPaths: ["a.swift"], untrackedPaths: ["b.swift"])

        for obstruction in [tracked, untracked, both] {
            let message = englishText(obstruction.pullMessage)
            #expect(message.contains("Pull"))
            #expect(!message.contains("Checkout"))
            #expect(message != englishText(obstruction.message))
        }
        #expect(englishText(tracked.pullMessage).contains("a.swift"))
        #expect(englishText(untracked.pullMessage).contains("b.swift"))
        #expect(englishText(tracked.pullMessage) != englishText(untracked.pullMessage))
    }
}
