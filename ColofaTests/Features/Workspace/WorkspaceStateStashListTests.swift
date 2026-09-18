////
//  WorkspaceStateStashListTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation
import Testing
@testable import Colofa

/// Store-level behaviour of reading Stashes: what the list reports, what its selection survives,
/// and which comparison each saved path is read as.
@Suite(.serialized)
final class WorkspaceStateStashListTests {
    private let defaults: UserDefaults
    private let repositoryURL = stashRepositoryURL

    init() throws {
        let suiteName = "com.anemoris.Colofa.WorkspaceStateStashListTests"
        defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    @MainActor
    private func workspace(_ stub: RepositoryServiceStub) async -> WorkspaceState {
        await openedWorkspace(stub, at: repositoryURL, defaults: defaults)
    }

    private func stub(
        _ snapshots: [RepositorySnapshot] = [stashRepository()],
        stashLists: [[Stash]] = [[]],
        stashesError: RepositoryOpenError? = nil,
        stashDetails: [String: StashDetail] = [:],
        stashDetailError: RepositoryOpenError? = nil
    ) -> RepositoryServiceStub {
        RepositoryServiceStub(
            snapshots: [repositoryURL: snapshots],
            stashLists: stashLists,
            stashesError: stashesError,
            stashDetails: stashDetails,
            stashDetailError: stashDetailError
        )
    }

    // MARK: - Reading the list

    @Test
    @MainActor
    func theListReportsWhatGitHolds() async throws {
        let state = await workspace(
            stub(stashLists: [[stashEntry(), stashEntry(selector: "stash@{1}", objectID: "old")]])
        )

        await state.loadStashes()

        #expect(state.stashes?.stashes?.map(\.selector) == ["stash@{0}", "stash@{1}"])
    }

    @Test
    @MainActor
    func aFailedReadIsReportedRatherThanShownAsAnEmptyList() async throws {
        let state = await workspace(
            stub(stashesError: .commandFailed(GitFailureDetails(command: "git", output: "no")))
        )

        await state.loadStashes()

        #expect(state.stashes?.stashes == nil)
        guard case .failed = state.stashes else {
            Issue.record("Expected the read to be reported as failed")
            return
        }
    }

    /// Reload Stashes replaces the whole of what the pane is showing, so it says it is reading
    /// rather than leaving the failure up until the answer arrives.
    @Test
    @MainActor
    func retryingAfterAfailureSaysItIsReading() async throws {
        let backend = RepositoryServiceStub(
            snapshots: [repositoryURL: [stashRepository()]],
            stashLists: [[stashEntry()]],
            stashDelay: .milliseconds(200)
        )
        let state = await workspace(backend)
        state.stashPresentation.loadedRepositoryURL = repositoryURL
        state.stashPresentation.state = .failed(
            .commandFailed(GitFailureDetails(command: "git", output: "no"))
        )

        let read = Task { await state.loadStashes() }
        while state.stashes != .loading {
            await Task.yield()
        }
        #expect(state.stashes == .loading)
        await read.value

        #expect(state.stashes?.stashes?.count == 1)
    }

    /// Creating or dropping a Stash renumbers the list, so a selection that followed its address
    /// would routinely land on a different entry.
    @Test
    @MainActor
    func theSelectionFollowsTheEntryRatherThanItsAddress() async throws {
        let state = await workspace(
            stub(
                stashLists: [
                    [stashEntry(selector: "stash@{0}", objectID: "kept")],
                    [
                        stashEntry(selector: "stash@{0}", objectID: "new"),
                        stashEntry(selector: "stash@{1}", objectID: "kept"),
                    ],
                ]
            )
        )

        await state.loadStashes()
        state.selectedStashID = "stash@{0}"

        await state.loadStashes()

        #expect(state.selectedStashID == "stash@{1}")
        #expect(state.selectedStash?.objectID == "kept")
    }

    @Test
    @MainActor
    func aSelectionGitNoLongerReportsIsDropped() async throws {
        let state = await workspace(
            stub(stashLists: [[stashEntry(objectID: "gone")], []])
        )

        await state.loadStashes()
        state.selectedStashID = "stash@{0}"

        await state.loadStashes()

        #expect(state.selectedStashID == nil)
        #expect(state.selectedStash == nil)
    }

    /// The same work saved twice produces the same Commit, so an object ID that now appears more
    /// than once names no single entry: the selection is dropped rather than guessed at.
    @Test
    @MainActor
    func anAmbiguousSelectionIsDroppedRatherThanGuessedAt() async throws {
        let state = await workspace(
            stub(
                stashLists: [
                    [stashEntry(objectID: "same")],
                    [
                        stashEntry(selector: "stash@{0}", objectID: "same"),
                        stashEntry(selector: "stash@{1}", objectID: "same"),
                    ],
                ]
            )
        )

        await state.loadStashes()
        state.selectedStashID = "stash@{0}"

        await state.loadStashes()

        #expect(state.selectedStashID == nil)
    }

    // MARK: - Reading one entry

    @Test
    @MainActor
    func selectingAnEntryReadsThePathsItSaved() async throws {
        let entry = stashEntry(untrackedObjectID: "untracked")
        let state = await workspace(
            stub(
                stashLists: [[entry]],
                stashDetails: [
                    entry.objectID: stashDetail(
                        objectID: entry.objectID,
                        tracked: ["diff.txt"],
                        untracked: ["notes.txt"]
                    ),
                ]
            )
        )

        await state.loadStashes()
        state.selectedStashID = entry.id
        await state.loadStashDetail()

        #expect(state.stashDetail?.detail?.files.map(\.summary.newPath) == ["diff.txt", "notes.txt"])
        // The pane opens on a file rather than on nothing.
        #expect(state.selectedStashFileID == stashFile("diff.txt", isUntracked: false).id)
    }

    @Test
    @MainActor
    func aFailedDetailReadIsReportedRatherThanLeftBlank() async throws {
        let entry = stashEntry()
        let state = await workspace(
            stub(
                stashLists: [[entry]],
                stashDetailError: .commandFailed(GitFailureDetails(command: "git", output: "no"))
            )
        )

        await state.loadStashes()
        state.selectedStashID = entry.id
        await state.loadStashDetail()

        guard case .failed = state.stashDetail else {
            Issue.record("Expected the detail read to be reported as failed")
            return
        }
    }

    // MARK: - The Diff

    /// A tracked path is compared against the Commit the Stash was saved on.
    @Test
    @MainActor
    func aTrackedPathAsksForTheStashesOwnComparison() async throws {
        let state = await selectedFileWorkspace(untracked: false)

        let identity = try #require(state.diffIdentity)
        #expect(
            identity.key.source == .commit(
                objectID: "stash-newest",
                parentObjectID: "base",
                paths: ["diff.txt"]
            )
        )
    }

    /// An untracked file lives in a Commit with no parent, so it is read the way a root Commit is.
    @Test
    @MainActor
    func anUntrackedPathAsksForTheCommitHoldingIt() async throws {
        let state = await selectedFileWorkspace(untracked: true)

        let identity = try #require(state.diffIdentity)
        #expect(
            identity.key.source == .commit(
                objectID: "untracked",
                parentObjectID: nil,
                paths: ["notes.txt"]
            )
        )
    }

    /// A Stash holds content that is not at that path on disk, so nothing offers to open a file
    /// beside the patch.
    @Test
    @MainActor
    func aRefusedStashPatchOffersNoFileOnDisk() async throws {
        let state = await selectedFileWorkspace(untracked: false)

        await state.loadDiff()

        #expect(state.diffFileURL == nil)
    }

    @MainActor
    private func selectedFileWorkspace(untracked: Bool) async -> WorkspaceState {
        let entry = stashEntry(untrackedObjectID: "untracked")
        let state = await workspace(
            stub(
                stashLists: [[entry]],
                stashDetails: [
                    entry.objectID: stashDetail(
                        objectID: entry.objectID,
                        tracked: ["diff.txt"],
                        untracked: ["notes.txt"]
                    ),
                ]
            )
        )
        state.selectedSection = .stashes
        await state.loadStashes()
        state.selectedStashID = entry.id
        await state.loadStashDetail()
        state.selectedStashFileID = stashFile(
            untracked ? "notes.txt" : "diff.txt",
            isUntracked: untracked
        ).id
        return state
    }

    // MARK: - Moving to another Repository

    /// A sheet whose options describe the work in one Repository must not follow the user into
    /// another, and neither may the entries that Repository held.
    @Test
    @MainActor
    func anotherRepositoryTakesNeitherTheSheetNorTheList() async throws {
        let otherURL = URL(filePath: "/tmp/Other Stash Store")
        let backend = RepositoryServiceStub(
            snapshots: [
                repositoryURL: [stashRepository()],
                otherURL: [stashRepository(at: otherURL)],
            ],
            stashLists: [[stashEntry()]]
        )
        let state = await workspace(backend)

        await state.loadStashes()
        state.selectedStashID = "stash@{0}"
        state.beginCreatingStash()

        await state.handleRepositorySelection(.success(otherURL))

        #expect(state.stashCreation == nil)
        #expect(state.stashes == nil)
        #expect(state.selectedStashID == nil)
    }
}
