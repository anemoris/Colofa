////
//  WorkspaceStateFileActionsTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// Which destructive action each kind of path is offered, and that neither ever runs without its
/// confirmation. What each one then does is `WorkspaceStateDiscardTests` and
/// `WorkspaceStateTrashTests`.
@Suite(.serialized)
final class WorkspaceStateFileActionsTests {
    private let defaults: UserDefaults
    private let modified = FileActionFixture.modified
    private let untracked = FileActionFixture.untracked
    private let conflicted = FileActionFixture.conflicted
    private let staged = FileActionFixture.staged

    init() throws {
        let suiteName = "com.anemoris.Colofa.WorkspaceStateFileActionsTests"
        defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test
    @MainActor
    func onlyATrackedUnstagedPathOffersDiscardChanges() async {
        let state = await workspace().state

        #expect(state.canDiscardChanges(modified, isStaged: false))
        #expect(!state.canDiscardChanges(untracked, isStaged: false))
        #expect(!state.canDiscardChanges(conflicted, isStaged: false))
        #expect(!state.canDiscardChanges(staged, isStaged: true))
        // The same path read from the Staged section is unstaged rather than discarded.
        #expect(!state.canDiscardChanges(modified, isStaged: true))
        #expect(
            !state.canDiscardChanges(
                RepositoryChange(path: "absent.txt", kind: .modified),
                isStaged: false
            )
        )
    }

    @Test
    @MainActor
    func onlyAnUntrackedUnstagedPathOffersMoveToTrash() async {
        let state = await workspace().state

        #expect(state.canMoveToTrash(untracked, isStaged: false))
        #expect(!state.canMoveToTrash(modified, isStaged: false))
        #expect(!state.canMoveToTrash(conflicted, isStaged: false))
        #expect(!state.canMoveToTrash(untracked, isStaged: true))
    }

    @Test
    @MainActor
    func neitherIsOfferedWhileAnotherCommandHoldsTheRepository() async {
        let state = await workspace(mutationDelay: .milliseconds(100)).state

        let mutation = Task { await state.stage(modified) }
        await waitUntil { state.isPerformingMutation }
        #expect(!state.canDiscardChanges(modified, isStaged: false))
        #expect(!state.canMoveToTrash(untracked, isStaged: false))
        await mutation.value
    }

    @Test
    @MainActor
    func aDiscardIsOnlyEverRunAfterItsConfirmation() async {
        let workspace = await workspace()

        workspace.state.beginDiscardingChanges(modified)

        #expect(workspace.state.pendingFileAction == .discardChanges(modified))
        #expect(workspace.state.isConfirmingFileAction)
        #expect(await workspace.stub.recordedArguments().isEmpty)
        #expect(workspace.files.trashed.isEmpty)
    }

    @Test
    @MainActor
    func cancellingADiscardLeavesTheRepositoryAndTheFileSystemAlone() async throws {
        let workspace = await workspace()
        let before = try #require(workspace.state.repository)

        workspace.state.beginDiscardingChanges(modified)
        workspace.state.cancelFileAction()

        // Nothing is confirmed: Cancel dismisses the dialog without reaching the button that
        // would have handed the action back.
        #expect(workspace.state.pendingFileAction == nil)
        #expect(!workspace.state.isConfirmingFileAction)
        #expect(await workspace.stub.recordedArguments().isEmpty)
        #expect(workspace.files.trashed.isEmpty)
        #expect(workspace.state.repository == before)
    }

    /// Dismissing the dialog by any other route — Escape, or clicking away — is the same as
    /// cancelling it, because both arrive as the binding going false.
    @Test
    @MainActor
    func dismissingAMoveToTrashLeavesTheRepositoryAndTheFileSystemAlone() async throws {
        let workspace = await workspace()
        let before = try #require(workspace.state.repository)

        workspace.state.beginMovingToTrash(untracked)
        #expect(workspace.state.pendingFileAction == .moveToTrash(untracked))
        workspace.state.isConfirmingFileAction = false

        #expect(workspace.state.pendingFileAction == nil)
        #expect(await workspace.stub.recordedArguments().isEmpty)
        #expect(workspace.files.trashed.isEmpty)
        #expect(workspace.state.repository == before)
    }

    @Test
    @MainActor
    func aConflictAndAStagedPathNeverReachAConfirmation() async {
        let state = await workspace().state

        state.beginDiscardingChanges(conflicted)
        #expect(state.pendingFileAction == nil)

        state.beginMovingToTrash(conflicted)
        #expect(state.pendingFileAction == nil)

        state.beginDiscardingChanges(staged)
        #expect(state.pendingFileAction == nil)
    }

    /// A confirmation that outlived the Change it names has nothing left to act on, and must not
    /// act on whatever took its place.
    @Test
    @MainActor
    func aReloadThatDropsTheChangeClosesItsConfirmation() async {
        let repositoryURL = URL(filePath: "/tmp/Colofa Stale File Action")
        let state = await fileActionsWorkspace(
            at: repositoryURL,
            defaults: defaults,
            followedBy: [repository(at: repositoryURL, unstagedChanges: [modified])]
        ).state

        state.beginMovingToTrash(untracked)
        await state.refresh()

        #expect(state.pendingFileAction == nil)
    }

    @MainActor
    private func workspace(mutationDelay: Duration? = nil) async -> FileActionsWorkspace {
        await fileActionsWorkspace(
            at: URL(filePath: "/tmp/Colofa File Actions"),
            defaults: defaults,
            mutationDelay: mutationDelay
        )
    }

    @MainActor
    private func waitUntil(_ condition: () -> Bool) async {
        var attempts = 0
        while !condition() && attempts < 100 {
            attempts += 1
            await Task.yield()
        }
    }
}
