////
//  WorkspaceStateFileLocationTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// Reveal in Finder and Copy Path: the two actions that only locate the file.
@Suite(.serialized)
final class WorkspaceStateFileLocationTests {
    private let defaults: UserDefaults

    init() throws {
        let suiteName = "com.anemoris.Colofa.WorkspaceStateFileLocationTests"
        defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test
    @MainActor
    func revealInFinderSelectsTheSelectedPathsRealLocation() async {
        let repositoryURL = URL(filePath: "/tmp/Colofa Reveal")
        let workspace = await fileActionsWorkspace(at: repositoryURL, defaults: defaults)

        await workspace.state.revealInFinder(FileActionFixture.modified)

        #expect(workspace.files.revealed == [repositoryURL.appending(path: "tracked.txt")])
        #expect(workspace.state.repositoryFailure == nil)
    }

    @Test
    @MainActor
    func revealInFinderExplainsAPathThatDisappearedAndReloads() async {
        let repositoryURL = URL(filePath: "/tmp/Colofa Missing Reveal")
        let after = repository(
            at: repositoryURL,
            unstagedChanges: [FileActionFixture.untracked]
        )
        let workspace = await fileActionsWorkspace(
            at: repositoryURL,
            defaults: defaults,
            followedBy: [after]
        )
        workspace.files.missingPaths = ["/tmp/Colofa Missing Reveal/tracked.txt"]

        await workspace.state.revealInFinder(FileActionFixture.modified)

        let state = workspace.state
        #expect(state.repository == after)
        #expect(state.repositoryFailureTitle.map(englishText) == "File Could Not Be Revealed")
        #expect(
            state.repositoryFailureMessage.map(englishText)
                == "“tracked.txt” is no longer on disk. Colofa reloaded the Repository."
        )
    }

    /// A path is text, not content: a deleted or trashed file still has the location the user
    /// asked for, which is what makes Copy Path the one of the two that never refuses.
    @Test
    @MainActor
    func copyPathCopiesTheAbsolutePathEvenForAFileThatIsGone() async {
        let repositoryURL = URL(filePath: "/tmp/Colofa Copy Path")
        let deleted = RepositoryChange(path: "gone/away.txt", kind: .deleted)
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [repository(at: repositoryURL, unstagedChanges: [deleted])]]
        )
        let pasteboard = PasteboardRecorder()
        let state = WorkspaceState(
            repositoryService: stub.service,
            pasteboard: pasteboard.writer,
            fileSystem: FileSystemActionsRecorder().actions,
            userDefaults: defaults,
            launchArguments: ["--ui-testing"]
        )
        await state.handleRepositorySelection(.success(repositoryURL))

        state.copyPath(deleted)

        #expect(pasteboard.written == ["/tmp/Colofa Copy Path/gone/away.txt"])
        #expect(state.repositoryFailure == nil)
    }
}
