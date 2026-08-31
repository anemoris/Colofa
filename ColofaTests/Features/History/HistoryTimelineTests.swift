////
//  HistoryTimelineTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

struct HistoryTimelineTests {
    @Test
    func startsEmpty() {
        let timeline = HistoryTimeline()

        #expect(timeline.commits.isEmpty)
        #expect(!timeline.hasMore)
        #expect(timeline.reportedCount == 0)
    }

    @Test
    func appendsAPageInOrder() {
        var timeline = HistoryTimeline(page: HistoryPage(commits: historyCommits(3), hasMore: true))
        timeline.append(
            HistoryPage(
                commits: (3..<6).map { historyCommit($0) },
                hasMore: false
            )
        )

        #expect(timeline.commits.map(\.summary) == (0..<6).map { "Commit \($0)" })
        #expect(!timeline.hasMore)
        #expect(timeline.reportedCount == 6)
    }

    /// A Commit can only arrive twice when History moved between two reads. Dropping the row
    /// keeps the list truthful; still counting it keeps the next page from skipping past a Commit
    /// that was never shown.
    @Test
    func dropsADuplicateRowWhileStillCountingWhatGitWalked() {
        var timeline = HistoryTimeline(page: HistoryPage(commits: historyCommits(3), hasMore: true))
        timeline.append(
            HistoryPage(commits: [historyCommit(2), historyCommit(3)], hasMore: false)
        )

        #expect(timeline.commits.map(\.objectID) == (0..<4).map { historyObjectID($0) })
        #expect(timeline.reportedCount == 5)
    }

    /// Every page after the first is skipped from this Commit rather than from whatever the Ref
    /// points at by then, which is what stops a Ref that moved from opening a gap in the walk.
    @Test
    func pinsTheCommitTheFirstPageStartedAt() {
        var timeline = HistoryTimeline(page: HistoryPage(commits: historyCommits(3), hasMore: true))

        #expect(timeline.tipObjectID == historyObjectID(0))

        // A later page cannot move the starting point: the walk it belongs to already has one.
        timeline.append(
            HistoryPage(commits: [historyCommit(3), historyCommit(4)], hasMore: false)
        )

        #expect(timeline.tipObjectID == historyObjectID(0))
    }

    /// An empty first page resolves nothing to pin, and there is nothing to page from either.
    @Test
    func pinsNothingWhenTheFirstPageIsEmpty() {
        var timeline = HistoryTimeline(page: HistoryPage(commits: [], hasMore: false))

        #expect(timeline.tipObjectID == nil)

        timeline.append(HistoryPage(commits: historyCommits(2), hasMore: false))

        #expect(timeline.tipObjectID == historyObjectID(0))
    }

    @Test
    func reportsWhetherAnythingFollowsTheLastPageItTook() {
        var timeline = HistoryTimeline(page: HistoryPage(commits: historyCommits(2), hasMore: true))
        #expect(timeline.hasMore)

        timeline.append(HistoryPage(commits: [], hasMore: false))
        #expect(!timeline.hasMore)
    }

    @Test
    func findsALoadedCommitByItsObjectID() {
        let timeline = HistoryTimeline(
            page: HistoryPage(commits: historyCommits(3), hasMore: false)
        )

        #expect(timeline.contains(historyObjectID(1)))
        #expect(timeline.commit(historyObjectID(1))?.summary == "Commit 1")
        #expect(!timeline.contains(historyObjectID(9)))
        #expect(timeline.commit(historyObjectID(9)) == nil)
    }
}
