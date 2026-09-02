////
//  WorkspaceStateDiscardTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

@Suite(.serialized)
final class WorkspaceStateDiscardTests {
    private let defaults: UserDefaults

    init() throws {
        let suiteName = "com.anemoris.Colofa.WorkspaceStateDiscardTests"
        defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test
    @MainActor
    func discardRestoresOnlyTheWorkingTreeAndReloads() async {
        let repositoryURL = URL(filePath: "/tmp/Colofa Discard")
        let after = repository(
            at: repositoryURL,
            stagedChanges: [FileActionFixture.staged],
            unstagedChanges: [FileActionFixture.conflicted, FileActionFixture.untracked]
        )
        let workspace = await fileActionsWorkspace(
            at: repositoryURL,
            defaults: defaults,
            followedBy: [after]
        )

        workspace.state.beginDiscardingChanges(FileActionFixture.modified)
        await workspace.confirmPendingFileAction()

        // `--worktree` is what makes the promise the confirmation gives: the index is never a
        // source or a target of this command.
        #expect(await workspace.stub.recordedArguments() == [
            ["--literal-pathspecs", "restore", "--worktree", "--", "tracked.txt"],
        ])
        #expect(workspace.state.repository?.stagedChanges == [FileActionFixture.staged])
        #expect(workspace.state.repository == after)
        #expect(workspace.state.repositoryFailure == nil)
    }

    /// Regression: SwiftUI clears a dialog's presentation binding while dismissing it, before the
    /// confirming button's action runs — the ordering `WorkspaceState+Commit.swift` already
    /// records. A confirm that read the action back out of the pending slot found it empty by
    /// then and ran nothing at all, which is what the dialog's own `presenting:` payload fixes.
    @Test
    @MainActor
    func confirmingStillRunsAfterDismissalHasClearedThePendingAction() async throws {
        let repositoryURL = URL(filePath: "/tmp/Colofa Discard Dismissal")
        let workspace = await fileActionsWorkspace(at: repositoryURL, defaults: defaults)

        workspace.state.beginDiscardingChanges(FileActionFixture.modified)
        let confirmed = try #require(workspace.state.pendingFileAction)
        // What SwiftUI does while dismissing, before the confirming button's action runs.
        workspace.state.isConfirmingFileAction = false
        #expect(workspace.state.pendingFileAction == nil)

        await workspace.state.confirmFileAction(confirmed)

        #expect(await workspace.stub.recordedArguments() == [
            ["--literal-pathspecs", "restore", "--worktree", "--", "tracked.txt"],
        ])
    }

    @Test
    @MainActor
    func aRefusedDiscardIsReportedThroughTheSharedCommandAlertAndReloads() async {
        let repositoryURL = URL(filePath: "/tmp/Colofa Discard Failure")
        let workspace = await fileActionsWorkspace(
            at: repositoryURL,
            defaults: defaults,
            mutationError: .commandFailed(
                GitFailureDetails(command: "git restore", output: "error: pathspec did not match")
            )
        )

        workspace.state.beginDiscardingChanges(FileActionFixture.modified)
        await workspace.confirmPendingFileAction()

        #expect(workspace.state.isShowingRepositoryMutationError)
        #expect(
            workspace.state.repositoryFailureTitle.map(englishText)
                == "Changes Could Not Be Discarded"
        )
        #expect(workspace.state.canShowRepositoryFailureDetails)
        // Failure reloads too: only Git can say what the refused command left behind.
        #expect(
            workspace.state.repository == FileActionFixture.everyKind(at: repositoryURL)
        )
    }
}
