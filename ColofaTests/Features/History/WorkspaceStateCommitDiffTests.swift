////
//  WorkspaceStateCommitDiffTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// What the Diff pane reads while History owns the selection.
///
/// A Commit is browsed one file at a time, the same way a working-tree Change is: the
/// presentation is the same read-only one Changes uses, and only the comparison Git is asked for
/// differs.
@MainActor
struct WorkspaceStateCommitDiffTests {
    @Test
    func selectingACommitOpensItsFirstFileComparedAgainstTheParent() async throws {
        let stub = Self.commitStub()
        let state = try await commitWorkspace(stub)

        await state.loadDiff()

        #expect(state.selectedCommitFile?.newPath == "notes.txt")
        let request = try #require(await stub.recordedDiffRequests().last)
        #expect(
            request.source == .commit(
                objectID: historyObjectID(0),
                parentObjectID: historyObjectID(1),
                paths: ["notes.txt"]
            )
        )
        #expect(state.diff == .loaded(replacementDiff(path: "notes.txt")))
    }

    /// The whole Commit's patch is never read, so a Commit that touches a hundred files costs one
    /// of them and a size limit is reached by a file rather than by a Commit.
    @Test
    func selectingAnotherFileReadsOnlyThatPath() async throws {
        let stub = Self.commitStub()
        let state = try await commitWorkspace(stub)
        await state.loadDiff()

        state.selectedCommitFileID = try #require(
            state.commitDetail?.detail?.changedFiles.last?.id
        )
        await state.loadDiff()

        let request = try #require(await stub.recordedDiffRequests().last)
        // A rename needs both paths in the pathspec or Git will not pair them.
        #expect(
            request.source == .commit(
                objectID: historyObjectID(0),
                parentObjectID: historyObjectID(1),
                paths: ["renamed.txt", "old.txt"]
            )
        )
        #expect(state.diff == .loaded(replacementDiff(path: "renamed.txt")))
        #expect(await stub.recordedDiffRequests().count == 2)
    }

    /// A Commit with no parent is compared against an empty tree, which is what Git does for a
    /// root Commit and for the boundary of a shallow clone.
    @Test
    func aCommitWithNoParentIsComparedAgainstNothing() async throws {
        let stub = Self.commitStub()
        let state = try await commitWorkspace(stub, selecting: historyObjectID(2))

        await state.loadDiff()

        let request = try #require(await stub.recordedDiffRequests().last)
        #expect(
            request.source == .commit(
                objectID: historyObjectID(2),
                parentObjectID: nil,
                paths: ["notes.txt"]
            )
        )
    }

    @Test
    func theDetailReadsTheFullMessageAndChangedFilesOfTheSelectedCommit() async throws {
        let state = try await commitWorkspace(Self.commitStub())

        let detail = try #require(state.commitDetail?.detail)
        #expect(detail.summary == "Full summary")
        #expect(detail.body == "Full body")
        #expect(detail.changedFiles.map(\.newPath) == ["notes.txt", "renamed.txt"])
    }

    @Test
    func aDetailThatCannotBeReadIsReportedRatherThanLeftBlank() async throws {
        let state = try await commitWorkspace(Self.commitStub(), selecting: historyObjectID(1))

        guard case .failed = state.commitDetail else {
            return #expect(Bool(false), "The Commit detail did not report the failure")
        }
        #expect(state.selectedCommitFileID == nil)

        await state.loadDiff()
        #expect(state.diff == nil)
    }

    /// Changes and History never show each other's patch: leaving one clears what it was reading.
    @Test
    func leavingHistoryClearsThePatchItWasShowing() async throws {
        let state = try await commitWorkspace(Self.commitStub())
        await state.loadDiff()

        state.sidebarSelection = .section(.changes)
        await state.loadDiff()

        #expect(state.diff == nil)
        #expect(state.diffIdentity == nil)
    }

    private func commitWorkspace(
        _ stub: RepositoryServiceStub,
        selecting objectID: String = historyObjectID(0)
    ) async throws -> WorkspaceState {
        let state = await historyWorkspace(stub)
        state.sidebarSelection = .reference(.head)
        await state.loadHistory()
        state.selectedCommitID = objectID
        // The file list is what a Commit's Diff is chosen from, so it is read first.
        await state.loadCommitDetail()
        return state
    }

    private static func commitStub() -> RepositoryServiceStub {
        RepositoryServiceStub(
            snapshots: [historyRepositoryURL: [historyRepositorySnapshot()]],
            diffResults: [
                "notes.txt": .diff(replacementDiff(path: "notes.txt")),
                "renamed.txt": .diff(replacementDiff(path: "renamed.txt")),
            ],
            historyCommits: [
                .head: [
                    historyCommit(0),
                    historyCommit(1),
                    historyCommit(2, parents: []),
                ],
            ],
            commitDetails: [
                historyObjectID(0): detail(historyObjectID(0)),
                historyObjectID(2): detail(historyObjectID(2)),
            ]
        )
    }

    private static func detail(_ objectID: String) -> HistoryCommitDetail {
        HistoryCommitDetail(
            objectID: objectID,
            message: "Full summary\n\nFull body\n",
            changedFiles: [
                DiffFileSummary(
                    oldPath: nil,
                    newPath: "notes.txt",
                    stats: DiffStats(additions: 1, deletions: 1)
                ),
                DiffFileSummary(
                    oldPath: "old.txt",
                    newPath: "renamed.txt",
                    stats: DiffStats(additions: 1, deletions: 1)
                ),
            ]
        )
    }
}
