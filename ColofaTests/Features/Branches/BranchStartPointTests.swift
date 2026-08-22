////
//  BranchStartPointTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

struct BranchStartPointTests {
    private static let repositoryURL = URL(filePath: "/tmp/colofa-branch-tests")

    @Test
    func namesTheCurrentBranchAsTheHeadStartPoint() throws {
        let startPoint = try #require(
            BranchStartPoint.head(
                of: repository(
                    at: Self.repositoryURL,
                    head: .branch("main"),
                    headCommit: RepositoryHeadCommit(objectID: "abc", summary: "Fixture commit")
                )
            )
        )

        #expect(startPoint.origin == .head)
        #expect(startPoint.revision == "HEAD")
        #expect(startPoint.label == "main")
        #expect(startPoint.summary == "Fixture commit")
    }

    /// A Detached HEAD names no branch, so the Commit it points at is what the dialog shows.
    @Test
    func namesTheCommitWhileHeadIsDetached() throws {
        let startPoint = try #require(
            BranchStartPoint.head(
                of: repository(
                    at: Self.repositoryURL,
                    head: .detached("0123456789abcdef0123456789abcdef01234567")
                )
            )
        )

        #expect(startPoint.revision == "HEAD")
        #expect(startPoint.label == "0123456789ab")
    }

    /// An Unborn Branch names no Commit, so there is nothing for a branch to start at.
    @Test
    func hasNoStartPointOnAnUnbornBranch() {
        #expect(
            BranchStartPoint.head(
                of: repository(at: Self.repositoryURL, head: .unbornBranch("main"))
            ) == nil
        )
    }

    /// The full object ID is what Git is asked for: the abbreviation a row shows is only unique
    /// at the time it was read.
    @Test
    func startsAtTheFullObjectIDOfASelectedCommit() {
        let commit = historyCommit(3)

        let startPoint = BranchStartPoint.commit(commit)

        #expect(startPoint.origin == .commit)
        #expect(startPoint.revision == commit.objectID)
        #expect(startPoint.label == commit.abbreviatedObjectID)
        #expect(startPoint.summary == commit.summary)
    }
}
