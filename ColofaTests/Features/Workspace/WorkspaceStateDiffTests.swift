////
//  WorkspaceStateDiffTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

@Suite(.serialized)
struct WorkspaceStateDiffTests {
    @Test
    @MainActor
    func selectingAnUnstagedChangeReadsItsWorkingTreeDiff() async throws {
        let state = await diffWorkspace(diffRepositoryStub())

        state.selectedChange = RepositoryChangeSelection(path: "notes.txt", isStaged: false)
        await state.loadDiff()

        guard case .loaded(let diff) = state.diff else {
            Issue.record("Expected a rendered Diff, got \(String(describing: state.diff))")
            return
        }
        #expect(diff.files.first?.newPath == "notes.txt")
        #expect(diff.stats == DiffStats(additions: 1, deletions: 1))
    }

    @Test
    @MainActor
    func stagedAndUnstagedSelectionsAskForDifferentComparisons() async throws {
        let stub = diffRepositoryStub()
        let state = await diffWorkspace(stub)

        state.selectedChange = RepositoryChangeSelection(path: "notes.txt", isStaged: false)
        await state.loadDiff()
        state.selectedChange = RepositoryChangeSelection(path: "notes.txt", isStaged: true)
        await state.loadDiff()

        #expect(await stub.recordedDiffRequests().map(\.source) == [
            .workingTree(paths: ["notes.txt"]),
            .index(paths: ["notes.txt"]),
        ])
    }

    @Test
    @MainActor
    func aConflictedPathReportsThatItsDiffIsUnavailable() async throws {
        let state = await diffWorkspace(diffRepositoryStub())

        state.selectedChange = RepositoryChangeSelection(path: "conflict.txt", isStaged: false)
        await state.loadDiff()

        #expect(state.diff == .conflicted)
    }

    @Test
    @MainActor
    func aPathThatDisappearsLeavesNoDiffBehind() async throws {
        let state = await diffWorkspace(diffRepositoryStub())
        state.selectedChange = RepositoryChangeSelection(path: "notes.txt", isStaged: false)
        await state.loadDiff()
        #expect(state.diff != nil)

        state.selectedChange = nil
        await state.loadDiff()

        #expect(state.diff == nil)
        #expect(state.diffFileURL == nil)
    }

    @Test
    @MainActor
    func aFailedReadReplacesTheDiffRatherThanKeepingTheLastOne() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [diffRepositoryURL: [diffRepositorySnapshot(at: diffRepositoryURL)]],
            diffError: .commandFailed(
                GitFailureDetails(command: "git diff", output: "bad object")
            )
        )
        let state = WorkspaceState(repositoryService: stub.service, launchArguments: ["--ui-testing"])
        await state.handleRepositorySelection(.success(diffRepositoryURL))

        state.selectedChange = RepositoryChangeSelection(path: "notes.txt", isStaged: false)
        await state.loadDiff()

        #expect(
            state.diff
                == .failed(
                    .commandFailed(GitFailureDetails(command: "git diff", output: "bad object"))
                )
        )
    }

    @Test
    @MainActor
    func aPatchAboveAnAutomaticLimitIsOfferedRatherThanRendered() async throws {
        let state = await diffWorkspace(diffRepositoryStub())

        state.selectedChange = RepositoryChangeSelection(path: "large.txt", isStaged: false)
        await state.loadDiff()

        guard case .confirmationRequired(let summary) = state.diff else {
            Issue.record("Expected an offer, got \(String(describing: state.diff))")
            return
        }
        #expect(summary.measurement.isComplete)
        #expect(summary.stats == DiffStats(additions: 40_000, deletions: 2))
    }

    @Test
    @MainActor
    func loadAnywayReReadsTheSamePatchWithTheHigherBound() async throws {
        let stub = diffRepositoryStub()
        let state = await diffWorkspace(stub)
        state.selectedChange = RepositoryChangeSelection(path: "large.txt", isStaged: false)
        await state.loadDiff()

        await state.loadDiffAnyway()

        #expect(await stub.recordedDiffRequests().map(\.isConfirmed) == [false, true])
        guard case .loaded = state.diff else {
            Issue.record("Expected a rendered Diff, got \(String(describing: state.diff))")
            return
        }
    }

    @Test
    @MainActor
    func loadAnywaySurvivesAReloadOfTheSameSelection() async throws {
        let stub = diffRepositoryStub()
        let state = await diffWorkspace(stub)
        state.selectedChange = RepositoryChangeSelection(path: "large.txt", isStaged: false)
        await state.loadDiff()
        await state.loadDiffAnyway()

        await state.loadDiff()

        #expect(await stub.recordedDiffRequests().map(\.isConfirmed) == [false, true, true])
    }

    @Test
    @MainActor
    func choosingAnotherPathWithdrawsTheEarlierConfirmation() async throws {
        let stub = diffRepositoryStub()
        let state = await diffWorkspace(stub)
        state.selectedChange = RepositoryChangeSelection(path: "large.txt", isStaged: false)
        await state.loadDiff()
        await state.loadDiffAnyway()

        state.selectedChange = RepositoryChangeSelection(path: "notes.txt", isStaged: false)
        await state.loadDiff()
        state.selectedChange = RepositoryChangeSelection(path: "large.txt", isStaged: false)
        await state.loadDiff()

        #expect(await stub.recordedDiffRequests().map(\.isConfirmed) == [false, true, false, false])
    }

    /// The window between a selection changing and its own read running: the offer made for the
    /// previous Change is still on screen, and a click on it must not be answered with that
    /// Change's patch under the newly selected path.
    @Test
    @MainActor
    func loadAnywayIsIgnoredOnceTheSelectionMovedToAnotherChange() async throws {
        let stub = diffRepositoryStub()
        let state = await diffWorkspace(stub)
        state.selectedChange = RepositoryChangeSelection(path: "large.txt", isStaged: false)
        await state.loadDiff()

        state.selectedChange = RepositoryChangeSelection(path: "notes.txt", isStaged: false)
        await state.loadDiffAnyway()

        #expect(
            await stub.recordedDiffRequests().map(\.source) == [.workingTree(paths: ["large.txt"])]
        )
        #expect(state.confirmedDiffKey == nil)
    }

    /// The same path on the other side of the index is another comparison, and the offer was not
    /// made for it.
    @Test
    @MainActor
    func loadAnywayIsIgnoredOnceTheSelectionMovedToTheOtherSideOfTheIndex() async throws {
        let stub = diffRepositoryStub()
        let state = await diffWorkspace(stub)
        state.selectedChange = RepositoryChangeSelection(path: "notes.txt", isStaged: false)
        await state.loadDiff()
        // The offer the pane holds is for the unstaged read; only the selection then moves.
        state.diff = .confirmationRequired(
            diffSummary(
                path: "notes.txt",
                stats: nil,
                byteCount: 3_000_000,
                lineCount: 40_010,
                isComplete: true
            )
        )

        state.selectedChange = RepositoryChangeSelection(path: "notes.txt", isStaged: true)
        await state.loadDiffAnyway()

        #expect(
            await stub.recordedDiffRequests().map(\.source) == [.workingTree(paths: ["notes.txt"])]
        )
    }

    @Test
    @MainActor
    func thePaneReportsThatItIsLoadingUntilThePatchArrives() async throws {
        let state = await diffWorkspace(diffRepositoryStub(diffDelay: .milliseconds(200)))

        state.selectedChange = RepositoryChangeSelection(path: "notes.txt", isStaged: false)
        let load = Task { await state.loadDiff() }
        try await waitForDiffLoadingState(of: state)
        await load.value

        guard case .loaded = state.diff else {
            Issue.record("Expected a rendered Diff, got \(String(describing: state.diff))")
            return
        }
    }

    /// The product decision the loading state is bounded by: re-reading the same Change after an
    /// ordinary reload keeps the last true content of that path on screen instead of flashing.
    @Test
    @MainActor
    func reReadingTheSameChangeKeepsItsPatchOnScreen() async throws {
        let stub = diffRepositoryStub(diffDelay: .milliseconds(200))
        let state = await diffWorkspace(stub)
        state.selectedChange = RepositoryChangeSelection(path: "notes.txt", isStaged: false)
        await state.loadDiff()

        let reload = Task { await state.loadDiff() }
        while await stub.recordedDiffRequests().count < 2 {
            await Task.yield()
        }

        #expect(state.diff != .loading)
        await reload.value
    }

    @Test
    @MainActor
    func loadAnywayDoesNothingWhenNothingIsBeingOffered() async throws {
        let stub = diffRepositoryStub()
        let state = await diffWorkspace(stub)
        state.selectedChange = RepositoryChangeSelection(path: "notes.txt", isStaged: false)
        await state.loadDiff()

        await state.loadDiffAnyway()

        #expect(await stub.recordedDiffRequests().count == 1)
    }

    @Test
    @MainActor
    func aPatchBeyondAHardLimitReportsCountsItNeverFinishedMeasuring() async throws {
        let state = await diffWorkspace(diffRepositoryStub())

        state.selectedChange = RepositoryChangeSelection(path: "huge.bin", isStaged: false)
        await state.loadDiff()

        guard case .beyondHardLimit(let summary) = state.diff else {
            Issue.record("Expected a refusal, got \(String(describing: state.diff))")
            return
        }
        #expect(!summary.measurement.isComplete)
        #expect(summary.files.first?.isBinary == true)
    }

    @Test
    @MainActor
    func theDiffIdentityChangesWithEveryReasonToReRead() async throws {
        let state = await diffWorkspace(diffRepositoryStub())
        state.selectedChange = RepositoryChangeSelection(path: "notes.txt", isStaged: false)
        let initial = try #require(state.diffIdentity)

        await state.refresh()

        #expect(state.diffIdentity != initial)
        #expect(state.diffIdentity?.key == initial.key)
    }

    @Test
    @MainActor
    func theDiffLayoutStartsUnifiedAndSwitches() async throws {
        let state = await diffWorkspace(diffRepositoryStub())

        #expect(state.diffLayout == .unified)
        state.diffLayout = .split
        #expect(state.diffLayout == .split)
    }
}
