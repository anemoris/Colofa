////
//  WorkspaceStateConflictTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation
import Testing
@testable import Colofa

/// Store-level behaviour of resolving a Conflict and ending the operation it belongs to.
@Suite(.serialized)
final class WorkspaceStateConflictTests {
    private let defaults: UserDefaults
    private let repositoryURL = mergeRepositoryURL
    private let conflict = RepositoryChange(path: "conflict.txt", kind: .conflict)

    init() throws {
        let suiteName = "com.anemoris.Colofa.WorkspaceStateConflictTests"
        defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    @MainActor
    private func workspace(
        _ stub: RepositoryServiceStub,
        fileSystem: FileSystemActionsRecorder? = nil
    ) async -> WorkspaceState {
        let state = WorkspaceState(
            repositoryService: stub.service,
            fileSystem: fileSystem?.actions ?? FileSystemActionsRecorder().actions,
            userDefaults: defaults,
            launchArguments: ["--ui-testing"]
        )
        await state.handleRepositorySelection(.success(repositoryURL))
        return state
    }

    private func stub(
        _ snapshots: [RepositorySnapshot],
        mutationError: RepositoryOpenError? = nil
    ) -> RepositoryServiceStub {
        RepositoryServiceStub(
            snapshots: [repositoryURL: snapshots],
            mutationError: mutationError
        )
    }

    // MARK: - Naming the two versions

    /// Never "ours" and "theirs": the current side is the Branch the working tree is on, and the
    /// incoming side is whatever Git's own `MERGE_HEAD` points at.
    @Test
    @MainActor
    func bothVersionsAreOfferedUnderRealRefNames() async throws {
        let state = await workspace(stub([conflictedMergeRepository()]))

        #expect(state.conflictVersionLabel(.current) == "main")
        #expect(state.conflictVersionLabel(.incoming) == "feature")
    }

    /// A Commit no Branch points at is still a real label; it is the Commit itself.
    @Test
    @MainActor
    func anIncomingCommitNoBranchNamesIsLabelledByItsObjectID() async throws {
        let state = await workspace(
            stub(
                [
                    conflictedMergeRepository(
                        mergeHead: MergeHead(branch: nil, objectID: "abc1234")
                    ),
                ]
            )
        )

        #expect(state.conflictVersionLabel(.incoming) == "abc1234")
    }

    @Test
    @MainActor
    func aDetachedHeadNamesTheCurrentVersionByItsCommit() async throws {
        let state = await workspace(
            stub([conflictedMergeRepository(head: .detached("0123456789abcdef0123"))])
        )

        #expect(state.conflictVersionLabel(.current) == "0123456789ab")
    }

    /// Without a `MERGE_HEAD` there is nothing truthful to call the incoming side, so it is not
    /// offered at all rather than offered under an invented name.
    @Test
    @MainActor
    func anUnnameableVersionIsNotOffered() async throws {
        let state = await workspace(
            stub([conflictedMergeRepository(mergeHead: nil)])
        )

        #expect(state.conflictVersionLabel(.incoming) == nil)
        #expect(!state.canChooseConflictVersion(.incoming, for: conflict))
        #expect(state.canChooseConflictVersion(.current, for: conflict))
    }

    // MARK: - Resolving one path

    @Test
    @MainActor
    func choosingAVersionWritesTheWorkingTreeAndLeavesThePathUnmerged() async throws {
        let recorder = stub([conflictedMergeRepository(), conflictedMergeRepository()])
        let state = await workspace(recorder)

        await state.chooseConflictVersion(.incoming, for: conflict)

        #expect(
            await recorder.recordedArguments() == [
                ["--literal-pathspecs", "checkout", "--theirs", "--", "conflict.txt"],
            ]
        )
        #expect(state.hasUnresolvedConflicts)
    }

    /// Mark as Resolved records whatever the file holds. It merges nothing and checks nothing,
    /// which is exactly what its name says.
    @Test
    @MainActor
    func markAsResolvedStagesThePathsCurrentContent() async throws {
        let recorder = stub([conflictedMergeRepository(), mergeRepository(operation: .merge)])
        let state = await workspace(recorder)

        await state.markResolved(conflict)

        #expect(
            await recorder.recordedArguments() == [
                ["--literal-pathspecs", "add", "--", "conflict.txt"],
            ]
        )
        #expect(!state.hasUnresolvedConflicts)
    }

    @Test
    @MainActor
    func aPathThatIsNotConflictedIsNeverResolvedThisWay() async throws {
        let ordinary = RepositoryChange(path: "a.txt", kind: .modified)
        let state = await workspace(
            stub([conflictedMergeRepository(unstagedChanges: [conflict, ordinary])])
        )

        #expect(!state.canMarkResolved(ordinary))
        #expect(!state.canChooseConflictVersion(.current, for: ordinary))
    }

    // MARK: - Opening the file

    @Test
    @MainActor
    func openInDefaultEditorHandsTheFileToTheSystem() async throws {
        let fileSystem = FileSystemActionsRecorder()
        let state = await workspace(
            stub([conflictedMergeRepository()]),
            fileSystem: fileSystem
        )

        await state.openInDefaultEditor(conflict)

        #expect(
            fileSystem.opened.map(\.normalizedFilePath)
                == [repositoryURL.appending(path: "conflict.txt").normalizedFilePath]
        )
        #expect(state.repositoryFailure == nil)
    }

    /// A delete/modify Conflict can leave nothing on disk, and a click that did nothing would be
    /// worse than one that says why.
    @Test
    @MainActor
    func aFileNothingOpensIsReported() async throws {
        let fileSystem = FileSystemActionsRecorder()
        fileSystem.missingPaths = [
            repositoryURL.appending(path: "conflict.txt").normalizedFilePath,
        ]
        let state = await workspace(
            stub([conflictedMergeRepository(), conflictedMergeRepository()]),
            fileSystem: fileSystem
        )

        await state.openInDefaultEditor(conflict)

        #expect(state.repositoryFailureTitle.map(englishText) == "File Could Not Be Opened")
    }

    // MARK: - Finishing the operation

    /// Continue must not launch the user's configured editor, and it skips no Hook.
    @Test
    @MainActor
    func continueCompletesTheMergeWithThePreparedMessage() async throws {
        let recorder = stub([mergeRepository(operation: .merge), mergeRepository()])
        let state = await workspace(recorder)

        #expect(state.canContinueMerge)
        await state.continueMerge()

        #expect(await recorder.recordedArguments() == [MergeCommand.completing])
        #expect(await recorder.recordedArguments().allSatisfy { !$0.contains("--no-verify") })
    }

    /// An operation must not be finished over a Conflict nobody decided.
    @Test
    @MainActor
    func continueIsUnavailableWhileAnyPathIsStillUnmerged() async throws {
        let recorder = stub([conflictedMergeRepository()])
        let state = await workspace(recorder)

        #expect(!state.canContinueMerge)
        await state.continueMerge()

        #expect(await recorder.recordedArguments().isEmpty)
    }

    @Test
    @MainActor
    func abortUsesGitsOwnMergeRollback() async throws {
        let recorder = stub([conflictedMergeRepository(), mergeRepository()])
        let state = await workspace(recorder)

        #expect(state.canAbortMerge)
        await state.abortMerge()

        #expect(await recorder.recordedArguments() == [MergeCommand.abort])
        #expect(!state.hasUnresolvedConflicts)
    }

    /// Rebase, Revert, cherry-pick, and `am` have their own recovery commands, so a merge
    /// rollback is deliberately not offered for any of them.
    @Test(arguments: [RepositoryOperation.rebase, .revert, .cherryPick, .am])
    @MainActor
    func anotherOperationIsNotEndedByAMergeCommand(operation: RepositoryOperation) async throws {
        let state = await workspace(stub([mergeRepository(operation: operation)]))

        #expect(!state.canAbortMerge)
        #expect(!state.canContinueMerge)
    }

    /// A Conflict is Repository state, so a reload finds it exactly where it was and keeps the
    /// labels its version choices carry.
    @Test
    @MainActor
    func theConflictAndItsLabelsSurviveARefresh() async throws {
        let state = await workspace(
            stub([conflictedMergeRepository(), conflictedMergeRepository()])
        )

        await state.refresh()

        #expect(state.conflictedChanges.map(\.path) == ["conflict.txt"])
        #expect(state.conflictVersionLabel(.incoming) == "feature")
        #expect(state.isMergeUnfinished)
    }
}
