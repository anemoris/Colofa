////
//  FileActionsIntegrationTests.swift
//  ColofaGitIntegrationTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// Discard Changes against real Git, and Move to Trash and Reveal in Finder against the real
/// platform boundary. What a stub cannot prove is exactly what these cover: that `git restore`
/// leaves the index alone, and that the Trash Colofa uses is the macOS one.
@Suite(.serialized)
struct FileActionsIntegrationTests {
    @Test
    @MainActor
    func discardRestoresUnstagedContentAndLeavesStagedChangesIntact() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        let fileURL = repositoryURL.appending(path: "partial.txt")
        try Data("base\n".utf8).write(to: fileURL)
        _ = try fixture.git(["add", "--all"], in: repositoryURL)
        _ = try fixture.git(["commit", "-m", "Base"], in: repositoryURL)

        try Data("base\nstaged\n".utf8).write(to: fileURL)
        _ = try fixture.git(["add", "--", "partial.txt"], in: repositoryURL)
        try Data("base\nstaged\nunstaged\n".utf8).write(to: fileURL)

        let state = await workspace(at: repositoryURL)
        let unstaged = try #require(state.repository?.unstagedChanges.first)
        state.beginDiscardingChanges(unstaged)
        await confirmPendingFileAction(of: state)

        // The working tree is back at the staged version, not at HEAD.
        #expect(try String(contentsOf: fileURL, encoding: .utf8) == "base\nstaged\n")
        #expect(state.repository?.unstagedChanges.isEmpty == true)
        #expect(state.repository?.stagedChanges == [
            RepositoryChange(path: "partial.txt", kind: .modified),
        ])
        #expect(state.repositoryFailure == nil)
    }

    @Test
    @MainActor
    func discardRestoresADeletedTrackedFileAndATypeChange() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        let deletedURL = repositoryURL.appending(path: "deleted.txt")
        let linkURL = repositoryURL.appending(path: "link.txt")
        try Data("keep\n".utf8).write(to: deletedURL)
        try Data("regular\n".utf8).write(to: linkURL)
        _ = try fixture.git(["add", "--all"], in: repositoryURL)
        _ = try fixture.git(["commit", "-m", "Base"], in: repositoryURL)

        try FileManager.default.removeItem(at: deletedURL)
        try FileManager.default.removeItem(at: linkURL)
        try FileManager.default.createSymbolicLink(
            at: linkURL,
            withDestinationURL: deletedURL
        )

        let state = await workspace(at: repositoryURL)
        for change in try #require(state.repository?.unstagedChanges) {
            state.beginDiscardingChanges(change)
            await confirmPendingFileAction(of: state)
        }

        #expect(try String(contentsOf: deletedURL, encoding: .utf8) == "keep\n")
        #expect(try String(contentsOf: linkURL, encoding: .utf8) == "regular\n")
        #expect(state.repository?.unstagedChanges.isEmpty == true)
        #expect(state.repository?.stagedChanges.isEmpty == true)
    }

    @Test
    @MainActor
    func aConflictedPathOffersNeitherDestructiveAction() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        let conflictURL = repositoryURL.appending(path: "conflict.txt")
        try Data("base\n".utf8).write(to: conflictURL)
        _ = try fixture.git(["add", "--all"], in: repositoryURL)
        _ = try fixture.git(["commit", "-m", "Base"], in: repositoryURL)
        _ = try fixture.git(["checkout", "-b", "topic"], in: repositoryURL)
        try Data("topic\n".utf8).write(to: conflictURL)
        _ = try fixture.git(["commit", "-am", "Topic"], in: repositoryURL)
        _ = try fixture.git(["checkout", "main"], in: repositoryURL)
        try Data("main\n".utf8).write(to: conflictURL)
        _ = try fixture.git(["commit", "-am", "Main"], in: repositoryURL)
        do {
            _ = try fixture.git(["merge", "topic"], in: repositoryURL)
            Issue.record("Expected a merge conflict")
        } catch {
            // The unresolved Conflict is the fixture this test needs.
        }

        let state = await workspace(at: repositoryURL)
        let conflict = try #require(state.repository?.unstagedChanges.first)
        #expect(conflict.kind == .conflict)
        #expect(!state.canDiscardChanges(conflict, isStaged: false))
        #expect(!state.canMoveToTrash(conflict, isStaged: false))

        // Neither reaches a confirmation, so there is never an action for one to hand back.
        state.beginDiscardingChanges(conflict)
        #expect(state.pendingFileAction == nil)
        state.beginMovingToTrash(conflict)
        #expect(state.pendingFileAction == nil)

        // Both sides are still in the file: nothing chose one for the user.
        let contents = try String(contentsOf: conflictURL, encoding: .utf8)
        #expect(contents.contains("main"))
        #expect(contents.contains("topic"))
        #expect(state.repository?.unstagedChanges == [conflict])
    }

    /// The Trash itself is deliberately not exercised here. Moving a real file to the macOS
    /// Trash cannot be undone by a test: reading or emptying `~/.Trash` needs Full Disk Access,
    /// which a test host does not have, so every run would leave litter in the Trash of whichever
    /// machine ran the suite. What real Git is needed for is the rest of it — that Colofa removes
    /// an untracked path through the file system at its real location and never asks Git to, and
    /// that the Repository stops reporting the path once it is gone. `FileSystemActions.live()`
    /// reaching the real Trash is covered by the missing-path test below and by the manual
    /// verification recorded with this change.
    @Test
    @MainActor
    func anUntrackedPathLeavesTheWorkingTreeWithoutGitBeingAsked() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try Data("base\n".utf8).write(to: repositoryURL.appending(path: "tracked.txt"))
        _ = try fixture.git(["add", "--all"], in: repositoryURL)
        _ = try fixture.git(["commit", "-m", "Base"], in: repositoryURL)

        let fileURL = repositoryURL.appending(path: "untracked 未跟踪.txt")
        try Data("untracked\n".utf8).write(to: fileURL)

        let removals = RemovedPaths()
        let state = await workspace(at: repositoryURL, fileSystem: .removing(into: removals))
        let untracked = try #require(state.repository?.unstagedChanges.first)
        #expect(untracked.kind == .untracked)
        #expect(!state.canDiscardChanges(untracked, isStaged: false))
        #expect(state.canMoveToTrash(untracked, isStaged: false))

        state.beginMovingToTrash(untracked)
        await confirmPendingFileAction(of: state)

        #expect(await removals.urls == [fileURL])
        #expect(!FileManager.default.fileExists(atPath: fileURL.normalizedFilePath))
        #expect(state.repository?.unstagedChanges.isEmpty == true)
        #expect(state.repository?.stagedChanges.isEmpty == true)
        #expect(state.repositoryFailure == nil)
        // Git was never asked to remove anything, so the committed file is untouched.
        #expect(
            try String(
                contentsOf: repositoryURL.appending(path: "tracked.txt"),
                encoding: .utf8
            ) == "base\n"
        )
    }

    /// The one boundary branch a Store-level fixture cannot prove: what the real file system and
    /// Finder answer for a path that is not there. The answering branch of Reveal in Finder is
    /// deliberately not driven here — it would take Finder to the foreground of whichever machine
    /// runs the suite — and is covered against a recorded boundary in `ColofaTests`.
    @Test
    func theLivePlatformBoundaryRefusesAPathThatIsNoLongerThere() async throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appending(path: "ColofaTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let missingURL = directoryURL.appending(path: "gone.txt")

        let actions = FileSystemActions.live()

        #expect(await actions.reveal(missingURL) == false)
        await #expect(throws: (any Error).self) {
            try await actions.moveToTrash(missingURL)
        }
    }

    // MARK: - Fixtures

    /// Answers the open confirmation the way the dialog does: the presentation binding is cleared
    /// first, because SwiftUI clears it while dismissing and before the confirming button's action
    /// runs, and what is confirmed is the payload the dialog captured when it opened.
    @MainActor
    private func confirmPendingFileAction(of state: WorkspaceState) async {
        guard let action = state.pendingFileAction else {
            Issue.record("No destructive file action was waiting for a confirmation")
            return
        }
        state.isConfirmingFileAction = false
        await state.confirmFileAction(action)
    }

    @MainActor
    private func workspace(
        at repositoryURL: URL,
        fileSystem: FileSystemActions = .unused
    ) async -> WorkspaceState {
        let state = WorkspaceState(
            repositoryService: service(),
            fileSystem: fileSystem,
            launchArguments: ["--ui-testing"]
        )
        await state.handleRepositorySelection(.success(repositoryURL))
        return state
    }

    private func service() -> RepositoryService {
        let backend = GitRepositoryService(candidateURLs: [URL(filePath: "/usr/bin/git")])
        return RepositoryService(
            availability: { await backend.availability() },
            load: { try await backend.loadRepository(at: $0) },
            runMutation: { try await backend.runMutation($0, standardInput: $1, in: $2) },
            loadDiff: { try await backend.loadDiff($0) },
            loadHistory: { try await backend.loadHistory($0) },
            loadCommitDetail: { try await backend.loadCommitDetail($0) },
            validateBranchName: { try await backend.validateBranchName($0) },
            loadCheckoutComparison: { try await backend.loadCheckoutComparison($0) },
            loadSkippedRemotes: { try await backend.loadSkippedRemotes(in: $0) },
            loadTagConflicts: { try await backend.loadTagConflicts($0) },
            loadPublishRemote: { try await backend.loadPublishRemote($0) },
            loadPushTarget: { try await backend.loadPushTarget($0) },
            loadPushDestination: { try await backend.loadPushDestination($0) },
            runNetworkMutation: { try await backend.runNetworkMutation($0, in: $1, responder: $2) }
        )
    }
}

/// The paths a fixture was asked to remove, in the order it was asked.
private actor RemovedPaths {
    private(set) var urls: [URL] = []

    func record(_ url: URL) {
        urls.append(url)
    }
}

private extension FileSystemActions {
    /// For a case that must never reach the file system at all: reaching it fails the test rather
    /// than quietly removing something.
    static var unused: Self {
        Self(
            moveToTrash: { url in
                Issue.record("Unexpected Move to Trash of \(url.normalizedFilePath)")
            },
            reveal: { url in
                Issue.record("Unexpected Reveal in Finder of \(url.normalizedFilePath)")
                return true
            }
        )
    }

    /// Stands in for the Trash by removing the file outright, so real Git can be observed
    /// noticing that the path left the working tree. It records the URL it was handed, which is
    /// what proves Colofa resolved the Change to its real location.
    static func removing(into removals: RemovedPaths) -> Self {
        Self(
            moveToTrash: { url in
                await removals.record(url)
                try FileManager.default.removeItem(at: url)
            },
            reveal: { url in
                Issue.record("Unexpected Reveal in Finder of \(url.normalizedFilePath)")
                return true
            }
        )
    }
}
