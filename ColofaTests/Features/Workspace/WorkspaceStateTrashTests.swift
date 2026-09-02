////
//  WorkspaceStateTrashTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

@Suite(.serialized)
final class WorkspaceStateTrashTests {
    private let defaults: UserDefaults
    private let untracked = FileActionFixture.untracked

    init() throws {
        let suiteName = "com.anemoris.Colofa.WorkspaceStateTrashTests"
        defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test
    @MainActor
    func anUntrackedPathLeavesThroughTheFileSystemWithoutGitBeingAsked() async {
        let repositoryURL = URL(filePath: "/tmp/Colofa Trash")
        let after = repository(
            at: repositoryURL,
            stagedChanges: [FileActionFixture.staged],
            unstagedChanges: [FileActionFixture.conflicted, FileActionFixture.modified]
        )
        let workspace = await fileActionsWorkspace(
            at: repositoryURL,
            defaults: defaults,
            followedBy: [after]
        )

        workspace.state.beginMovingToTrash(untracked)
        await workspace.confirmPendingFileAction()

        #expect(workspace.files.trashed == [repositoryURL.appending(path: "new.txt")])
        // Git has no copy of an untracked file, so it is asked for nothing.
        #expect(await workspace.stub.recordedArguments().isEmpty)
        #expect(workspace.state.repository == after)
        #expect(workspace.state.repositoryFailure == nil)
    }

    @Test
    @MainActor
    func aCancelledTrashOperationKeepsThePathAndSaysSo() async throws {
        let workspace = await self.workspace()
        workspace.files.trashError = CocoaError(.userCancelled)
        let before = try #require(workspace.state.repository)

        workspace.state.beginMovingToTrash(untracked)
        await workspace.confirmPendingFileAction()

        let state = workspace.state
        #expect(state.isShowingRepositoryMutationError)
        #expect(state.repositoryFailureTitle.map(englishText) == "File Was Not Moved to the Trash")
        #expect(
            state.repositoryFailureMessage.map(englishText)
                == "The operation was cancelled, so “new.txt” is still where it was."
        )
        // Nothing to expand: no Git command ran, so there is no Git output behind it.
        #expect(!state.canShowRepositoryFailureDetails)
        #expect(state.repository == before)
    }

    @Test
    @MainActor
    func aRefusedTrashOperationReportsWhatTheFileSystemSaidAndKeepsThePath() async throws {
        let workspace = await self.workspace()
        workspace.files.trashError = CocoaError(.fileWriteNoPermission)

        workspace.state.beginMovingToTrash(untracked)
        await workspace.confirmPendingFileAction()

        let state = workspace.state
        #expect(state.isShowingRepositoryMutationError)
        #expect(
            state.repositoryFailureTitle.map(englishText) == "File Could Not Be Moved to the Trash"
        )
        let message = try #require(state.repositoryFailureMessage.map(englishText))
        #expect(message.hasPrefix("“new.txt” is still where it was."))
        #expect(state.repository?.unstagedChanges.contains(untracked) == true)
    }

    @MainActor
    private func workspace() async -> FileActionsWorkspace {
        await fileActionsWorkspace(
            at: URL(filePath: "/tmp/Colofa Trash Failure"),
            defaults: defaults
        )
    }
}
