////
//  WorkspaceStateNewBranchTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation
import Testing
@testable import Colofa

/// Store-level behaviour of New Branch: where the dialog starts, what it validates, which
/// command each option produces, and what a refusal leaves on screen.
@Suite(.serialized)
final class WorkspaceStateNewBranchTests {
    private let defaults: UserDefaults
    private let repositoryURL = branchRepositoryURL

    init() throws {
        let suiteName = "com.anemoris.Colofa.WorkspaceStateNewBranchTests"
        defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    @MainActor
    private func workspace(_ stub: RepositoryServiceStub) async -> WorkspaceState {
        await openedWorkspace(stub, at: repositoryURL, defaults: defaults)
    }

    /// One dialog, two entry points: the toolbar starts at HEAD and History starts at the Commit
    /// the user selected, and each shows exactly that.
    @Test
    @MainActor
    func opensOneDialogOnWhicheverStartPointTheEntryPointNames() async throws {
        let stub = RepositoryServiceStub(snapshots: [repositoryURL: [branchRepository()]])
        let state = await workspace(stub)

        state.beginCreatingBranch()
        #expect(state.isCreatingBranch)
        #expect(state.branchCreation?.startPoint.origin == .head)
        #expect(state.branchCreation?.startPoint.revision == "HEAD")
        #expect(state.branchCreation?.startPoint.label == "main")
        // Checkout New Branch is enabled by default, and it is only a default.
        #expect(state.branchCreation?.checksOutNewBranch == true)

        let commit = historyCommit(4)
        state.beginCreatingBranch(at: commit)
        #expect(state.branchCreation?.startPoint.origin == .commit)
        #expect(state.branchCreation?.startPoint.revision == commit.objectID)
    }

    /// An Unborn Branch names no Commit, so New Branch cannot open at all.
    @Test
    @MainActor
    func refusesToOpenTheDialogOnAnUnbornBranch() async {
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [branchRepository(head: .unbornBranch("main"))]]
        )
        let state = await workspace(stub)

        #expect(!state.canBeginCreatingBranch)
        #expect(state.branchCreationUnavailabilityReason == .unbornBranch)
        state.beginCreatingBranch()
        #expect(!state.isCreatingBranch)
    }

    /// Creating without Checkout writes one ref: HEAD and the working tree are left alone.
    @Test
    @MainActor
    func createsWithoutCheckoutWhenTheOptionIsTurnedOff() async throws {
        let stub = RepositoryServiceStub(snapshots: [repositoryURL: [branchRepository()]])
        let state = await workspace(stub)
        state.beginCreatingBranch()
        state.branchCreation?.name = "feature"
        state.branchCreation?.checksOutNewBranch = false
        await state.validateBranchName()

        #expect(state.canCreateBranch)
        await state.createBranch()

        #expect(await stub.recordedArguments() == [["branch", "--", "feature", "HEAD"]])
        #expect(state.repository?.head == .branch("main"))
        #expect(state.repository?.unstagedChanges.isEmpty == true)
        #expect(!state.isCreatingBranch)
    }

    @Test
    @MainActor
    func createsAndChecksOutInOneCommand() async throws {
        let stub = RepositoryServiceStub(snapshots: [repositoryURL: [branchRepository()]])
        let state = await workspace(stub)
        state.beginCreatingBranch(at: historyCommit(4))
        state.branchCreation?.name = "recovery"
        await state.validateBranchName()

        await state.createBranch()

        #expect(
            await stub.recordedArguments() == [
                ["switch", "--create", "recovery", historyObjectID(4)],
            ]
        )
        #expect(!state.isCreatingBranch)
    }

    /// Real Git answers about the name, and Colofa asks about the name that is actually typed.
    @Test
    @MainActor
    func asksGitAboutTheNameAndReportsWhatItSays() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [branchRepository()]],
            invalidBranchNames: ["bad name"]
        )
        let state = await workspace(stub)
        state.beginCreatingBranch()

        state.branchCreation?.name = " feature/work "
        // The field shows what Git will be asked about and what will be created, not the paste.
        #expect(state.branchCreation?.name == "feature/work")
        #expect(state.branchNameValidation == .checking)
        await state.validateBranchName()
        #expect(state.branchNameValidation == .valid)

        state.branchCreation?.name = "bad name"
        await state.validateBranchName()
        #expect(state.branchNameValidation == .invalidFormat)
        #expect(!state.canCreateBranch)

        #expect(
            await stub.recordedBranchNameRequests().map(\.name) == ["feature/work", "bad name"]
        )
    }

    /// A Git that could not be asked is not an answer about the name.
    ///
    /// Reporting it as an unacceptable name would leave Create disabled with the user editing a
    /// name that was never the problem, so the dialog reports the failure itself.
    @Test
    @MainActor
    func reportsAfailedNameCheckAsItselfRatherThanAnInvalidName() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [branchRepository()]],
            branchNameValidationError: .gitUnavailable
        )
        let state = await workspace(stub)
        state.beginCreatingBranch()
        state.branchCreation?.name = "feature"

        await state.validateBranchName()

        #expect(state.branchCreation?.failure == .nameCheckFailed(
            GitFailureDetails(
                command: "git",
                output: String(localized: RepositoryOpenError.gitUnavailable.message)
            )
        ))
        // Nothing was learned about the name, so Create stays shut rather than claiming a verdict.
        #expect(state.branchNameValidation == .checking)
        #expect(!state.canCreateBranch)
        #expect(state.isCreatingBranch)

        // Editing the name retires a refusal that was never about it.
        state.branchCreation?.name = "feature/work"
        #expect(state.branchCreation?.failure == nil)
    }

    /// A name the Repository already reports is answered without a round trip, and never created.
    @Test
    @MainActor
    func refusesAnameTheRepositoryAlreadyReports() async throws {
        let stub = RepositoryServiceStub(snapshots: [repositoryURL: [branchRepository()]])
        let state = await workspace(stub)
        state.beginCreatingBranch()
        state.branchCreation?.name = "main"

        #expect(state.branchNameValidation == .alreadyExists)
        #expect(!state.canCreateBranch)
        await state.createBranch()

        #expect(await stub.recordedArguments().isEmpty)
        #expect(await stub.recordedBranchNameRequests().isEmpty)
        #expect(state.isCreatingBranch)
    }

    /// The name is what the user has to change, so a refusal appears beside it rather than
    /// replacing the dialog with an alert.
    @Test
    @MainActor
    func keepsTheDialogOpenWithGitsOwnRefusal() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [branchRepository()]],
            mutationError: .commandFailed(
                GitFailureDetails(
                    command: "git branch",
                    output: "fatal: cannot lock ref",
                    exitStatus: 128
                )
            )
        )
        let state = await workspace(stub)
        state.beginCreatingBranch()
        state.branchCreation?.name = "feature"
        state.branchCreation?.checksOutNewBranch = false
        await state.validateBranchName()

        await state.createBranch()

        #expect(state.isCreatingBranch)
        #expect(state.branchCreation?.failure?.details?.output == "fatal: cannot lock ref")
        #expect(state.repositoryFailure == nil)
    }

    /// `git switch --create` does both or neither, so a Checkout it refuses is reported as one —
    /// with the paths it protected — inside the dialog that is still open.
    @Test
    @MainActor
    func reportsABlockedCheckoutInsideTheDialog() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [
                repositoryURL: [
                    branchRepository(
                        unstagedChanges: [
                            RepositoryChange(path: "shared.swift", kind: .modified),
                        ]
                    ),
                ],
            ],
            mutationError: .commandFailed(
                GitFailureDetails(command: "git switch", output: "error", exitStatus: 1)
            ),
            checkoutComparison: CheckoutComparison(
                changedPaths: ["shared.swift"],
                addedPaths: []
            )
        )
        let state = await workspace(stub)
        state.beginCreatingBranch(at: historyCommit(4))
        state.branchCreation?.name = "recovery"
        await state.validateBranchName()

        await state.createBranch()

        #expect(state.isCreatingBranch)
        #expect(
            state.branchCreation?.failure
                == .checkoutBlocked(
                    CheckoutObstruction(modifiedPaths: ["shared.swift"], untrackedPaths: [])
                )
        )
        #expect(
            await stub.recordedCheckoutComparisonRequests().map(\.revision)
                == [historyObjectID(4)]
        )
    }
}
