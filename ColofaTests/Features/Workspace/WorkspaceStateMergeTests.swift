////
//  WorkspaceStateMergeTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation
import Testing
@testable import Colofa

/// Store-level behaviour of Merge: what the confirmation says, what each strategy runs, and how a
/// Merge that ended in Conflict is told apart from one that failed.
@Suite(.serialized)
final class WorkspaceStateMergeTests {
    private let defaults: UserDefaults
    private let repositoryURL = mergeRepositoryURL

    init() throws {
        let suiteName = "com.anemoris.Colofa.WorkspaceStateMergeTests"
        defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    @MainActor
    private func workspace(_ stub: RepositoryServiceStub) async -> WorkspaceState {
        await openedWorkspace(stub, at: repositoryURL, defaults: defaults)
    }

    private func stub(
        _ snapshots: [RepositorySnapshot],
        mutationError: RepositoryOpenError? = nil,
        comparison: CheckoutComparison = .empty
    ) -> RepositoryServiceStub {
        RepositoryServiceStub(
            snapshots: [repositoryURL: snapshots],
            mutationError: mutationError,
            checkoutComparison: comparison
        )
    }

    private var refusal: RepositoryOpenError {
        .commandFailed(
            GitFailureDetails(command: "git merge", output: "merge refused", exitStatus: 1)
        )
    }

    // MARK: - The confirmation

    /// Direction is the thing about a Merge most easily got backwards, so both ends are named.
    @Test
    @MainActor
    func theConfirmationNamesTheSourceAndTheCurrentBranch() async throws {
        let state = await workspace(stub([mergeRepository()]))

        state.beginMerging(.localBranch("feature"))

        let draft = try #require(state.mergeDraft)
        #expect(draft.source.name == "feature")
        #expect(draft.target == "main")
        #expect(draft.strategy == .automatic)
        #expect(state.isMerging)
    }

    /// A Detached HEAD is a valid target and is named by the Commit it sits at.
    @Test
    @MainActor
    func aDetachedHeadIsNamedByItsCommit() async throws {
        let state = await workspace(
            stub([mergeRepository(head: .detached("0123456789abcdef0123"))])
        )

        state.beginMerging(.localBranch("feature"))

        #expect(state.mergeDraft?.target == "0123456789ab")
    }

    @Test
    @MainActor
    func aRefThatCannotBeMergedOpensNothing() async throws {
        let state = await workspace(stub([mergeRepository()]))

        state.beginMerging(.tag("v1.0"))

        #expect(state.mergeDraft == nil)
    }

    @Test
    @MainActor
    func cancellingRunsNothingAtAll() async throws {
        let recorder = stub([mergeRepository()])
        let state = await workspace(recorder)

        state.beginMerging(.localBranch("feature"))
        state.cancelMerge()

        #expect(state.mergeDraft == nil)
        #expect(await recorder.recordedArguments().isEmpty)
    }

    // MARK: - Running one Merge

    @Test
    @MainActor
    func theChosenStrategyIsWhatRuns() async throws {
        let recorder = stub([mergeRepository(), mergeRepository()])
        let state = await workspace(recorder)

        state.beginMerging(.localBranch("feature"))
        state.mergeDraft?.strategy = .alwaysCreateMergeCommit
        await state.confirmMerge()

        #expect(
            await recorder.recordedArguments() == [
                [
                    "merge", "--no-ff", "--no-edit", "--no-autostash",
                    "-m", "Merge branch 'feature'", "--", "refs/heads/feature",
                ],
            ]
        )
        #expect(state.mergeDraft == nil)
        #expect(state.repositoryFailure == nil)
    }

    @Test
    @MainActor
    func aRemoteBranchIsMergedFromItsRemoteTrackingRef() async throws {
        let recorder = stub([mergeRepository(), mergeRepository()])
        let state = await workspace(recorder)

        state.beginMerging(.remoteBranch("origin/main"))
        await state.confirmMerge()

        #expect(
            await recorder.recordedArguments().first?.last == "refs/remotes/origin/main"
        )
    }

    /// Git ends a conflicted merge with a non-zero status, but nothing went wrong: the
    /// Repository is now the state the user works in, and an alert would cover the list they
    /// have to act on.
    @Test
    @MainActor
    func aMergeThatStoppedAtAConflictReportsNoFailure() async throws {
        let recorder = stub(
            [mergeRepository(), conflictedMergeRepository()],
            mutationError: refusal
        )
        let state = await workspace(recorder)

        state.beginMerging(.localBranch("feature"))
        await state.confirmMerge()

        #expect(state.mergeDraft == nil)
        #expect(state.repositoryFailure == nil)
        #expect(state.hasUnresolvedConflicts)
    }

    /// A Merge Git refused left no unfinished merge behind, so it is a failure and says so.
    @Test
    @MainActor
    func aRefusedMergeIsReportedAsOne() async throws {
        let recorder = stub([mergeRepository(), mergeRepository()], mutationError: refusal)
        let state = await workspace(recorder)

        state.beginMerging(.localBranch("feature"))
        await state.confirmMerge()

        #expect(state.mergeDraft == nil)
        #expect(state.repositoryFailureTitle.map(englishText) == "Merge Failed")
    }

    /// The paths come from Git's own name-status walk against the Branch that was coming in,
    /// rather than from text scraped out of Git's message.
    @Test
    @MainActor
    func aCollisionNamesTheUntrackedFilesItProtected() async throws {
        let untracked = RepositoryChange(path: "notes.txt", kind: .untracked)
        let recorder = stub(
            [
                mergeRepository(unstagedChanges: [untracked]),
                mergeRepository(unstagedChanges: [untracked]),
            ],
            mutationError: refusal,
            comparison: CheckoutComparison(changedPaths: [], addedPaths: ["notes.txt"])
        )
        let state = await workspace(recorder)

        state.beginMerging(.localBranch("feature"))
        await state.confirmMerge()

        #expect(state.repositoryFailureTitle.map(englishText) == "Cannot Merge")
        #expect(state.repositoryFailureMessage.map(englishText)?.contains("notes.txt") == true)
        #expect(
            await recorder.recordedCheckoutComparisonRequests().map(\.revision)
                == ["refs/heads/feature"]
        )
    }

    /// The walk that explains a refusal is asked only after Git has already refused, so it
    /// explains a refusal rather than deciding one.
    @Test
    @MainActor
    func nothingIsAskedAboutCollisionsBeforeTheMergeRuns() async throws {
        let recorder = stub([mergeRepository(), mergeRepository()])
        let state = await workspace(recorder)

        state.beginMerging(.localBranch("feature"))
        await state.confirmMerge()

        #expect(await recorder.recordedCheckoutComparisonRequests().isEmpty)
    }

    // MARK: - Availability

    @Test
    @MainActor
    func trackedWorkRefusesTheMergeBeforeAnythingRuns() async throws {
        let recorder = stub(
            [mergeRepository(stagedChanges: [RepositoryChange(path: "a.txt", kind: .modified)])]
        )
        let state = await workspace(recorder)

        #expect(!state.canMerge(.localBranch("feature")))
        state.beginMerging(.localBranch("feature"))

        #expect(state.mergeDraft == nil)
        #expect(await recorder.recordedArguments().isEmpty)
    }

    @Test
    @MainActor
    func untrackedWorkAloneStillPermitsTheMerge() async throws {
        let state = await workspace(
            stub(
                [
                    mergeRepository(
                        unstagedChanges: [RepositoryChange(path: "notes.txt", kind: .untracked)]
                    ),
                ]
            )
        )

        #expect(state.canMerge(.localBranch("feature")))
    }

    /// The sidebar gives the current Branch no row of its own — it is the HEAD row — so Merge has
    /// to be offered there and refused by name, rather than disappearing from the one Branch a
    /// user is most likely to try it on.
    @Test
    @MainActor
    func theHeadRowOffersMergeAndRefusesItAsTheCurrentBranch() async throws {
        let state = await workspace(stub([mergeRepository()]))

        #expect(state.mergeSource(of: .head)?.name == "main")
        #expect(state.mergeUnavailabilityReason(for: .head) == .currentBranch)
        state.beginMerging(.head)

        #expect(state.mergeDraft == nil)
    }

    /// A Detached HEAD and an Unborn Branch name no Branch, so there is nothing to offer at all.
    @Test(arguments: [RepositoryHead.detached("0123456789abcdef0123"), .unbornBranch("main")])
    @MainActor
    func aHeadOnNoBranchOffersNoMergeSource(head: RepositoryHead) async throws {
        let state = await workspace(stub([mergeRepository(head: head)]))

        #expect(state.mergeSource(of: .head) == nil)
    }

    /// The Branch menu acts on the sidebar's selected Ref, the same one Checkout does.
    @Test
    @MainActor
    func theMenuMergesTheSelectedRef() async throws {
        let recorder = stub([mergeRepository(), mergeRepository()])
        let state = await workspace(recorder)
        state.select(.reference(.localBranch("feature")))

        #expect(state.canMergeSelectedReference)
        state.beginMergingSelectedReference()
        await state.confirmMerge()

        #expect(await recorder.recordedArguments().first?.last == "refs/heads/feature")
    }
}
