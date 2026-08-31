////
//  WorkspaceStateHistoryTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

@MainActor
struct WorkspaceStateHistoryTests {
    /// Selecting a Ref is inspection. It puts History on screen and asks Git to walk from that
    /// Ref, and it runs no command that could move HEAD or touch the working tree.
    @Test
    func selectingABranchShowsItsHistoryWithoutCheckingItOut() async {
        let stub = historyStub()
        let state = await historyWorkspace(stub)

        state.sidebarSelection = .reference(.localBranch("feature"))
        await state.loadHistory()

        #expect(state.selectedSection == .history)
        #expect(state.historyReference == .localBranch("feature"))
        #expect(state.history?.timeline?.commits.first?.summary == "Feature 0")
        #expect(await stub.recordedMutations().isEmpty)
    }

    @Test
    func selectingARemoteBranchShowsItsHistoryWithoutCreatingALocalBranch() async {
        let stub = historyStub()
        let state = await historyWorkspace(stub)

        state.sidebarSelection = .reference(.remoteBranch("origin/main"))
        await state.loadHistory()

        #expect(state.history?.timeline?.commits.first?.summary == "Remote 0")
        #expect(await stub.recordedHistoryRequests().last?.reference == .remoteBranch("origin/main"))
        #expect(await stub.recordedMutations().isEmpty)
    }

    /// A tag names one Commit, so selecting the tag selects it: the walk starts there.
    @Test
    func selectingATagSelectsTheCommitItNames() async {
        let stub = historyStub()
        let state = await historyWorkspace(stub)

        state.sidebarSelection = .reference(.tag("v1.0"))
        await state.loadHistory()

        #expect(state.selectedCommitID == historyObjectID(0, prefix: "t"))
        #expect(state.selectedCommit?.summary == "Tag 0")
    }

    @Test
    func theFirstPageIsTwoHundredTopologicallyOrderedCommits() async {
        let stub = historyStub()
        let state = await historyWorkspace(stub)

        await state.loadHistory()

        let request = await stub.recordedHistoryRequests().last
        #expect(request?.pageSize == 200)
        #expect(request?.offset == 0)
        #expect(state.history?.timeline?.commits.count == 200)
        #expect(state.history?.timeline?.hasMore == true)
        #expect(state.canLoadMoreHistory)
    }

    @Test
    func loadMoreAppendsTheNextPageWithoutDuplicatesOrGaps() async {
        let stub = historyStub()
        let state = await historyWorkspace(stub)
        await state.loadHistory()
        state.selectedCommitID = historyObjectID(5, prefix: "m")

        await state.loadMoreHistory()

        let commits = state.history?.timeline?.commits ?? []
        #expect(commits.count == 250)
        #expect(commits.map(\.objectID) == (0..<250).map { historyObjectID($0, prefix: "m") })
        #expect(Set(commits.map(\.objectID)).count == 250)
        #expect(await stub.recordedHistoryRequests().last?.offset == 200)
        #expect(state.history?.timeline?.hasMore == false)
        #expect(!state.canLoadMoreHistory)
        // The page that arrived must not take the selection with it.
        #expect(state.selectedCommitID == historyObjectID(5, prefix: "m"))
    }

    /// The Ref is read once, on the first page. Asking for the next one by Ref again would let a
    /// Fetch, a Commit, or a reset landing in between decide what `--skip=200` skips.
    @Test
    func loadMoreAsksForTheNextPageFromTheCommitTheFirstOneStartedAt() async {
        let stub = historyStub()
        let state = await historyWorkspace(stub)
        await state.loadHistory()

        #expect(await stub.recordedHistoryRequests().last?.tipObjectID == nil)

        await state.loadMoreHistory()

        let request = await stub.recordedHistoryRequests().last
        #expect(request?.tipObjectID == historyObjectID(0, prefix: "m"))
        #expect(request?.revision == historyObjectID(0, prefix: "m"))
        #expect(request?.offset == 200)
    }

    /// The pages already read stay on screen: a page that failed to arrive is a reason to offer
    /// the read again, not a reason to take back the History that did arrive.
    @Test
    func aFailedLoadMoreKeepsTheHistoryAlreadyOnScreen() async {
        let stub = historyStub(historyFailingOffsets: [200])
        let state = await historyWorkspace(stub)
        await state.loadHistory()

        await state.loadMoreHistory()

        #expect(state.history?.timeline?.commits.count == 200)
        #expect(state.history?.timeline?.isLoadingMore == false)
        #expect(state.historyPageFailure != nil)
    }

    /// Nothing is reachable from an Unborn Branch, and asking Git to walk from one is an error
    /// rather than an answer, so it is never asked.
    @Test
    func anUnbornBranchShowsAnEmptyHistoryWithoutAskingGit() async {
        let stub = historyStub(head: .unbornBranch("main"))
        let state = await historyWorkspace(stub)

        await state.loadHistory()

        #expect(state.history == .unborn)
        #expect(await stub.recordedHistoryRequests().isEmpty)
    }

    @Test
    func aFailedFirstPageIsReportedRatherThanLeftEmpty() async {
        let stub = historyStub(historyFailingOffsets: [0])
        let state = await historyWorkspace(stub)

        await state.loadHistory()

        guard case .failed = state.history else {
            return #expect(Bool(false), "The History pane did not report the failure")
        }
        #expect(state.selectedCommitID == nil)
    }
}
