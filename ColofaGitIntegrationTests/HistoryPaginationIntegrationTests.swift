////
//  HistoryPaginationIntegrationTests.swift
//  ColofaGitIntegrationTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// The page boundary against real Git, which needs more Commits than a page holds.
@Suite(.serialized)
struct HistoryPaginationIntegrationTests {
    @Test
    @MainActor
    func loadsTwoHundredCommitsThenAppendsTheRestWithoutDuplicatesOrGaps() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try createPagedHistory(in: repositoryURL, fixture: fixture)

        let state = await openedWorkspace(fixture, at: repositoryURL)
        await state.loadHistory()

        #expect(state.history?.timeline?.commits.count == 200)
        #expect(state.canLoadMoreHistory)

        await state.loadMoreHistory()

        let commits = try #require(state.history?.timeline?.commits)
        #expect(commits.count == 205)
        #expect(Set(commits.map(\.objectID)).count == 205)
        #expect(!state.canLoadMoreHistory)
        // The whole walk, in Git's own order, with nothing stepped over at the page boundary.
        let expected = try fixture.git(
            ["log", "--topo-order", "--format=%H", "HEAD"],
            in: repositoryURL
        ).split(separator: "\n").map(String.init)
        #expect(commits.map(\.objectID) == expected)
    }

    /// A Refresh gives back the History the user had, not its first page, and keeps the Commit
    /// they were reading selected.
    @Test
    @MainActor
    func refreshKeepsTheRefThePageDepthAndTheSelectedCommit() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try createPagedHistory(in: repositoryURL, fixture: fixture)

        let state = await openedWorkspace(fixture, at: repositoryURL)
        await state.loadHistory()
        await state.loadMoreHistory()
        let selected = try #require(state.history?.timeline?.commits.last?.objectID)
        state.selectedCommitID = selected

        await state.refresh()
        await state.loadHistory()

        #expect(state.history?.timeline?.commits.count == 205)
        #expect(state.selectedCommitID == selected)
    }
}
