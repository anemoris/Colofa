////
//  WorkspaceStateDeleteBranchStalenessTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation
import Testing
@testable import Colofa

/// What Delete Branch does when the Repository stops matching the confirmation on screen.
///
/// Kept apart from the ordinary Delete because these are about the window between the question
/// and the command: a Ref that moved, a Branch somebody else removed, and a read that could not
/// be taken at all.
@Suite(.serialized)
final class WorkspaceStateDeleteBranchStalenessTests {
    private let defaults: UserDefaults
    private let repositoryURL = branchRepositoryURL

    init() throws {
        let suiteName = "com.anemoris.Colofa.WorkspaceStateDeleteBranchStalenessTests"
        defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    private static func survey(
        objectID: String = "topic-tip",
        uniqueCommitCount: Int = 0
    ) -> BranchDeletionSurvey {
        BranchDeletionSurvey(objectID: objectID, uniqueCommitCount: uniqueCommitCount)
    }

    private func stub(
        surveys: [String: [BranchDeletionSurvey?]] = ["feature": [survey()]],
        snapshots: [RepositorySnapshot]? = nil,
        surveyError: RepositoryOpenError? = nil
    ) -> RepositoryServiceStub {
        RepositoryServiceStub(
            snapshots: [
                repositoryURL: snapshots
                    ?? [branchRepository(localBranches: ["feature", "main"])],
            ],
            branchDeletionSurveys: surveys,
            branchDeletionSurveyError: surveyError
        )
    }

    @MainActor
    private func workspace(_ stub: RepositoryServiceStub) async -> WorkspaceState {
        await openedWorkspace(stub, at: repositoryURL, defaults: defaults)
    }

    /// A Branch that moved between the confirmation and the command is refused, not deleted.
    @Test
    @MainActor
    func refusesAdeletionWhoseRefMovedAfterTheConfirmation() async throws {
        let stub = stub(
            surveys: [
                "feature": [
                    Self.survey(objectID: "before"),
                    Self.survey(objectID: "after"),
                ],
            ]
        )
        let state = await workspace(stub)
        await state.beginDeletingBranch(.localBranch("feature"))

        await state.confirmBranchDeletion()

        #expect(await stub.recordedArguments().isEmpty)
        #expect(state.branchDeletion == nil)
        #expect(state.isShowingStaleBranchDeletionAlert)
    }

    /// The count is part of what was agreed to: a Branch that started holding History nothing
    /// else holds is no longer the Branch the confirmation described.
    @Test
    @MainActor
    func refusesAdeletionWhoseUniqueCommitCountChanged() async throws {
        let stub = stub(
            surveys: [
                "feature": [
                    Self.survey(uniqueCommitCount: 0),
                    Self.survey(uniqueCommitCount: 3),
                ],
            ]
        )
        let state = await workspace(stub)
        await state.beginDeletingBranch(.localBranch("feature"))

        await state.confirmBranchDeletion()

        #expect(await stub.recordedArguments().isEmpty)
        #expect(state.isShowingStaleBranchDeletionAlert)
    }

    /// A Branch Git no longer has cannot be deleted under the assumption that it is there.
    @Test
    @MainActor
    func refusesAdeletionWhoseBranchDisappeared() async throws {
        let stub = stub(surveys: ["feature": [Self.survey(), nil]])
        let state = await workspace(stub)
        await state.beginDeletingBranch(.localBranch("feature"))

        await state.confirmBranchDeletion()

        #expect(await stub.recordedArguments().isEmpty)
        #expect(state.isShowingStaleBranchDeletionAlert)
    }

    /// A reload that no longer reports the Branch closes the confirmation rather than leaving it
    /// standing over nothing.
    @Test
    @MainActor
    func closesTheConfirmationWhenTheBranchStopsBeingReported() async throws {
        let stub = stub(
            snapshots: [
                branchRepository(localBranches: ["feature", "main"]),
                branchRepository(localBranches: ["main"]),
            ]
        )
        let state = await workspace(stub)
        await state.beginDeletingBranch(.localBranch("feature"))

        await state.refresh()

        #expect(state.branchDeletion == nil)
        #expect(state.isShowingStaleBranchDeletionAlert)
    }

    /// Colofa's own successful Delete is the reason the Branch is gone, so the reload it triggers
    /// must not report it as somebody else's surprise.
    @Test
    @MainActor
    func reportsNoStalenessForItsOwnSuccessfulDeletion() async throws {
        let stub = stub(
            snapshots: [
                branchRepository(localBranches: ["feature", "main"]),
                branchRepository(localBranches: ["main"]),
            ]
        )
        let state = await workspace(stub)
        await state.beginDeletingBranch(.localBranch("feature"))

        await state.confirmBranchDeletion()

        #expect(state.branchDeletion == nil)
        #expect(!state.isShowingStaleBranchDeletionAlert)
        #expect(state.repository?.localBranches == ["main"])
    }

    // MARK: - Reading Git

    /// A read that itself failed is reported as itself. Nothing was deleted, and blaming the
    /// Branch for a Git that could not be run would be a lie.
    @Test
    @MainActor
    func reportsAsurveyThatCouldNotBeRead() async throws {
        let stub = stub(
            surveyError: .commandFailed(
                GitFailureDetails(command: "git rev-list", output: "boom", exitStatus: 128)
            )
        )
        let state = await workspace(stub)

        await state.beginDeletingBranch(.localBranch("feature"))

        #expect(state.branchDeletion == nil)
        #expect(state.repositoryFailure?.isMutationAlert == true)
    }

    /// A read that failed once the confirmation was already open is not a Branch needing Force
    /// Delete: nothing was refused, so nothing here asks for consent to a destructive command.
    @Test
    @MainActor
    func doesNotRequireForceWhenTheSecondReadCouldNotBeTaken() async throws {
        let stub = stub(
            surveyError: .commandFailed(
                GitFailureDetails(command: "git rev-list", output: "boom", exitStatus: 128)
            )
        )
        let state = await workspace(stub)
        // Opened by hand, because the read this drives is the one the confirmation reopens with.
        state.branchDeletion = BranchDeletion(branch: "feature", survey: Self.survey())

        await state.confirmBranchDeletion()

        let deletion = try #require(state.branchDeletion)
        #expect(!deletion.isForceRequired)
        #expect(deletion.failure == .surveyFailed(
            GitFailureDetails(command: "git rev-list", output: "boom", exitStatus: 128)
        ))
        #expect(await stub.recordedArguments().isEmpty)
    }

    /// Deleting a local Branch names nothing outside `refs/heads/`, so nothing it runs can reach
    /// a Remote-tracking Branch or a remote.
    @Test
    @MainActor
    func neverTouchesTheRemoteOrItsTrackingBranch() async throws {
        let stub = stub()
        let state = await workspace(stub)
        await state.beginDeletingBranch(.localBranch("feature"))

        await state.confirmBranchDeletion()

        let arguments = try #require(await stub.recordedArguments().first)
        #expect(!arguments.contains("--remotes"))
        #expect(!arguments.contains("-r"))
        #expect(!arguments.contains("push"))
        #expect(await stub.networkMutations.isEmpty)
        #expect(state.repository?.remoteBranches == ["origin/feature"])
    }
}
