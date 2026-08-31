////
//  WorkspaceStateHistoryReloadTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// What survives a re-read: changing which walk History uses, and reloading the Repository.
@MainActor
struct WorkspaceStateHistoryReloadTests {
    @Test
    func historyReadsEveryReachableCommitUntilTheWalkIsChanged() async {
        let stub = historyStub()
        let state = await historyWorkspace(stub)

        await state.loadHistory()

        #expect(state.historyScope == .reachable)
        #expect(await stub.recordedHistoryRequests().last?.scope == .reachable)
    }

    /// The same History read another way, so the Commit the user was reading keeps its selection
    /// and the paging starts over: an offset counted in one walk means nothing in the other.
    @Test
    func changingTheWalkRereadsAndKeepsAStillReachableSelection() async {
        let stub = historyStub()
        let state = await historyWorkspace(stub)
        await state.loadHistory()
        await state.loadMoreHistory()
        state.selectedCommitID = historyObjectID(5, prefix: "m")

        state.historyScope = .firstParent
        await state.loadHistory()

        let request = await stub.recordedHistoryRequests().last
        #expect(request?.scope == .firstParent)
        #expect(request?.offset == 0)
        #expect(request?.pageSize == 200)
        #expect(state.selectedCommitID == historyObjectID(5, prefix: "m"))
        #expect(state.history?.timeline?.commits.count == 200)
    }

    @Test
    func changingTheWalkDropsASelectionItNoLongerReaches() async {
        let stub = historyStub()
        let state = await historyWorkspace(stub)
        await state.loadHistory()
        state.selectedCommitID = historyObjectID(1, prefix: "m")

        state.historyScope = .firstParent
        await state.loadHistory()

        #expect(state.selectedCommitID == nil)
    }

    @Test
    func refreshKeepsTheRefThePageDepthAndTheSelectedCommit() async {
        let stub = historyStub()
        let state = await historyWorkspace(stub)
        state.sidebarSelection = .reference(.localBranch("main"))
        await state.loadHistory()
        await state.loadMoreHistory()
        state.selectedCommitID = historyObjectID(210, prefix: "m")

        await state.refresh()
        await state.loadHistory()

        #expect(state.historyReference == .localBranch("main"))
        // Every page that was loaded is asked for again at once, so a Refresh gives back the
        // History the user had scrolled to rather than its first page.
        #expect(await stub.recordedHistoryRequests().last?.pageSize == 400)
        #expect(state.history?.timeline?.commits.count == 250)
        #expect(state.selectedCommitID == historyObjectID(210, prefix: "m"))
    }

    /// Pinning the walk's start is what keeps one round of paging consistent, not what freezes
    /// History. A Refresh reads the Ref again and pins whatever it now points at, which is how a
    /// Ref that moved reaches the screen.
    @Test
    func refreshResolvesTheRefAgainRatherThanReusingThePinnedStart() async {
        let stub = historyStub()
        let state = await historyWorkspace(stub)
        await state.loadHistory()
        await state.loadMoreHistory()

        #expect(await stub.recordedHistoryRequests().last?.tipObjectID != nil)

        await state.refresh()
        await state.loadHistory()

        let request = await stub.recordedHistoryRequests().last
        #expect(request?.tipObjectID == nil)
        #expect(request?.revision == GitReference.head.revision)
    }

    @Test
    func refreshDropsASelectedCommitTheRefNoLongerReaches() async {
        let stub = historyStub()
        let state = await historyWorkspace(stub)
        await state.loadHistory()
        state.selectedCommitID = "a commit that is gone"

        await state.refresh()
        await state.loadHistory()

        #expect(state.selectedCommitID == nil)
        #expect(state.history?.timeline?.commits.count == 200)
    }

    /// A Ref that is gone can no longer be inspected, so History falls back to HEAD, which every
    /// Repository has, and the sidebar row moves with it.
    @Test
    func refreshFallsBackToHeadWhenTheSelectedRefDisappears() async {
        let stub = historyStub(
            snapshots: [
                historyRepositorySnapshot(),
                RepositorySnapshot(
                    name: "colofa-history-tests",
                    rootURL: historyRepositoryURL,
                    gitDirectoryURL: historyRepositoryURL.appending(path: ".git"),
                    head: .branch("main"),
                    localBranches: ["main"],
                    remoteBranches: ["origin/main"],
                    tags: ["v1.0"]
                ),
            ]
        )
        let state = await historyWorkspace(stub)
        state.sidebarSelection = .reference(.localBranch("feature"))
        await state.loadHistory()

        await state.refresh()

        #expect(state.historyReference == .head)
        #expect(state.sidebarSelection == .reference(.head))
        #expect(state.selectedSection == .history)
    }

    @Test
    func openingAnotherRepositoryStartsFromHeadAgain() async {
        let otherURL = URL(filePath: "/tmp/colofa-history-tests-other")
        let stub = historyStub(urls: [historyRepositoryURL, otherURL])
        let state = await historyWorkspace(stub)
        state.sidebarSelection = .reference(.tag("v1.0"))
        await state.loadHistory()

        await state.handleRepositorySelection(.success(otherURL))

        #expect(state.historyReference == .head)
        #expect(state.sidebarSelection == .reference(.head))
    }
}
