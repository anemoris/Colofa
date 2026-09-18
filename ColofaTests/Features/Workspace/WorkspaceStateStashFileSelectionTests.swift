////
//  WorkspaceStateStashFileSelectionTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation
import Testing
@testable import Colofa

/// Which saved path a selection in the Stash pane names when one path was saved on both sides.
@Suite(.serialized)
final class WorkspaceStateStashFileSelectionTests {
    private let defaults: UserDefaults

    init() throws {
        let suiteName = "com.anemoris.Colofa.WorkspaceStateStashFileSelectionTests"
        defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    /// `git rm --cached` on a file that is then edited saves the path as a tracked change and as
    /// an untracked file. Selecting the untracked row reads the untracked Commit rather than the
    /// first row that happens to share its path.
    @Test(arguments: [false, true])
    @MainActor
    func thePathOnBothSidesIsReadFromTheSideThatWasSelected(untracked: Bool) async throws {
        let entry = stashEntry(untrackedObjectID: "untracked")
        let backend = RepositoryServiceStub(
            snapshots: [stashRepositoryURL: [stashRepository()]],
            stashLists: [[entry]],
            stashDetails: [
                entry.objectID: stashDetail(
                    objectID: entry.objectID,
                    tracked: ["a.txt"],
                    untracked: ["a.txt"]
                ),
            ]
        )
        let state = await openedWorkspace(backend, at: stashRepositoryURL, defaults: defaults)
        state.selectedSection = .stashes
        await state.loadStashes()
        state.selectedStashID = entry.id
        await state.loadStashDetail()

        state.selectedStashFileID = stashFile("a.txt", isUntracked: untracked).id

        #expect(state.selectedStashFile?.isUntracked == untracked)
        let identity = try #require(state.diffIdentity)
        #expect(
            identity.key.source == .commit(
                objectID: untracked ? "untracked" : "stash-newest",
                parentObjectID: untracked ? nil : "base",
                paths: ["a.txt"]
            )
        )
    }
}
