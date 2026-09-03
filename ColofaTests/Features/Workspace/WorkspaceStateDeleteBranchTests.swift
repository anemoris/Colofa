////
//  WorkspaceStateDeleteBranchTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation
import Testing
@testable import Colofa

/// Store-level behaviour of Delete Branch: which Refs it offers itself for, what it asks Git
/// before opening a confirmation, what it runs, and what it refuses to run under assumptions that
/// stopped being true.
@Suite(.serialized)
final class WorkspaceStateDeleteBranchTests {
    private let defaults: UserDefaults
    private let repositoryURL = branchRepositoryURL

    init() throws {
        let suiteName = "com.anemoris.Colofa.WorkspaceStateDeleteBranchTests"
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
        mutationError: RepositoryOpenError? = nil,
        surveyError: RepositoryOpenError? = nil
    ) -> RepositoryServiceStub {
        RepositoryServiceStub(
            snapshots: [
                repositoryURL: snapshots
                    ?? [branchRepository(localBranches: ["feature", "main"])],
            ],
            mutationError: mutationError,
            branchDeletionSurveys: surveys,
            branchDeletionSurveyError: surveyError
        )
    }

    @MainActor
    private func workspace(_ stub: RepositoryServiceStub) async -> WorkspaceState {
        await openedWorkspace(stub, at: repositoryURL, defaults: defaults)
    }

    // MARK: - Availability

    /// The current Branch is refused before anything runs, and the refusal says why.
    @Test
    @MainActor
    func refusesToDeleteTheCurrentBranchAndSaysWhy() async throws {
        let state = await workspace(stub())

        #expect(!state.canDeleteBranch(.localBranch("main")))
        #expect(state.branchDeletionUnavailabilityReason(for: .localBranch("main"))
            == .currentBranch)
        // HEAD resolves to the branch it is on, so the sidebar's current-Branch row carries the
        // same refusal rather than hiding the action.
        #expect(state.deletableBranchName(of: .head) == "main")
        #expect(state.branchDeletionUnavailabilityReason(for: .head) == .currentBranch)
    }

    /// Delete Branch removes a local branch and nothing else, so it offers itself for nothing
    /// else either.
    @Test
    @MainActor
    func offersNoDeletionForAremoteBranchOrAtag() async throws {
        let state = await workspace(stub())

        #expect(state.deletableBranchName(of: .remoteBranch("origin/feature")) == nil)
        #expect(state.deletableBranchName(of: .tag("v1.0")) == nil)
        #expect(state.branchDeletionUnavailabilityReason(for: .tag("v1.0")) == .notLocalBranch)
    }

    /// Opening the confirmation on nothing selected, or on a Ref that is not a local branch,
    /// leaves the dialog closed rather than opening one that names nothing.
    @Test
    @MainActor
    func opensNoConfirmationForArefItCannotDelete() async throws {
        let stub = stub()
        let state = await workspace(stub)

        await state.beginDeletingBranch(.tag("v1.0"))

        #expect(state.branchDeletion == nil)
        #expect(await stub.recordedBranchDeletionRequests().isEmpty)
    }

    // MARK: - Confirming

    /// A Branch every other Ref already holds says so, needs no force, and deletes through Git's
    /// own safe mode.
    @Test
    @MainActor
    func deletesAmergedBranchThroughGitsSafeMode() async throws {
        let stub = stub()
        let state = await workspace(stub)

        await state.beginDeletingBranch(.localBranch("feature"))

        let deletion = try #require(state.branchDeletion)
        #expect(deletion.branch == "feature")
        #expect(deletion.survey.uniqueCommitCount == 0)
        #expect(!deletion.isForceRequired)

        await state.confirmBranchDeletion()

        #expect(await stub.recordedArguments() == [["branch", "--delete", "--", "feature"]])
        #expect(state.branchDeletion == nil)
        #expect(state.repositoryFailure == nil)
    }

    /// An unmerged Branch shows the exact count of Commits only it holds, and Delete does nothing
    /// until Force Delete has been ticked.
    @Test
    @MainActor
    func showsTheExactUniqueCommitCountAndRequiresForce() async throws {
        let stub = stub(surveys: ["feature": [Self.survey(uniqueCommitCount: 7)]])
        let state = await workspace(stub)

        await state.beginDeletingBranch(.localBranch("feature"))

        #expect(state.branchDeletion?.survey.uniqueCommitCount == 7)
        #expect(state.branchDeletion?.isForceRequired == true)
        #expect(!state.canConfirmBranchDeletion)

        await state.confirmBranchDeletion()
        #expect(await stub.recordedArguments().isEmpty)

        state.branchDeletion?.forcesDeletion = true
        #expect(state.canConfirmBranchDeletion)

        await state.confirmBranchDeletion()

        #expect(
            await stub.recordedArguments() == [["branch", "--delete", "--force", "--", "feature"]]
        )
    }

    /// Git's own refusal is narrower than the count, so a Branch holding nothing unique that Git
    /// still will not delete escalates to the same explicit force rather than to an alert.
    @Test
    @MainActor
    func escalatesTheRefusalGitGivesAbranchHoldingNothingUnique() async throws {
        let stub = stub(
            mutationError: .commandFailed(
                GitFailureDetails(
                    command: "git branch",
                    output: "error: the branch 'feature' is not fully merged",
                    exitStatus: 1
                )
            )
        )
        let state = await workspace(stub)
        await state.beginDeletingBranch(.localBranch("feature"))

        await state.confirmBranchDeletion()

        let deletion = try #require(state.branchDeletion)
        #expect(deletion.isForceRequired)
        #expect(deletion.failure == .refused(
            GitFailureDetails(
                command: "git branch",
                output: "error: the branch 'feature' is not fully merged",
                exitStatus: 1
            )
        ))
        // The refusal stays inside the dialog, which is where the decision is.
        #expect(state.repositoryFailure == nil)
    }

    /// Cancelling runs nothing, at either stage.
    @Test
    @MainActor
    func cancellingEitherConfirmationLeavesTheBranchUntouched() async throws {
        let stub = stub(surveys: ["feature": [Self.survey(uniqueCommitCount: 2)]])
        let state = await workspace(stub)

        await state.beginDeletingBranch(.localBranch("feature"))
        state.cancelBranchDeletion()
        #expect(state.branchDeletion == nil)

        await state.beginDeletingBranch(.localBranch("feature"))
        state.branchDeletion?.forcesDeletion = true
        state.isDeletingBranch = false

        #expect(state.branchDeletion == nil)
        #expect(await stub.recordedArguments().isEmpty)
    }
}
