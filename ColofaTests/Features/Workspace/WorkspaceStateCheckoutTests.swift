////
//  WorkspaceStateCheckoutTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation
import Testing
@testable import Colofa

/// Store-level behaviour of Checkout: the command each Ref produces, and how a Checkout Git
/// refused is explained.
@Suite(.serialized)
final class WorkspaceStateCheckoutTests {
    private let defaults: UserDefaults
    private let repositoryURL = branchRepositoryURL

    init() throws {
        let suiteName = "com.anemoris.Colofa.WorkspaceStateCheckoutTests"
        defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    @MainActor
    private func workspace(_ stub: RepositoryServiceStub) async -> WorkspaceState {
        await openedWorkspace(stub, at: repositoryURL, defaults: defaults)
    }

    @Test
    @MainActor
    func checksOutALocalBranchWithoutForcingAnything() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [branchRepository(localBranches: ["feature", "main"])]]
        )
        let state = await workspace(stub)

        await state.checkout(.localBranch("feature"))

        #expect(await stub.recordedArguments() == [["switch", "--no-guess", "--", "feature"]])
        #expect(state.repositoryFailure == nil)
    }

    /// A remote branch becomes a same-name local tracking branch, so later Pull and Push have an
    /// upstream.
    @Test
    @MainActor
    func checksOutARemoteBranchAsALocalTrackingBranch() async throws {
        let stub = RepositoryServiceStub(snapshots: [repositoryURL: [branchRepository()]])
        let state = await workspace(stub)

        await state.checkout(.remoteBranch("origin/feature"))

        #expect(
            await stub.recordedArguments() == [
                ["switch", "--track", "--create", "feature", "refs/remotes/origin/feature"],
            ]
        )
    }

    /// Recreating a local branch that already exists would drop whatever it holds that the
    /// remote does not, so Checkout switches to the branch that is already here.
    @Test
    @MainActor
    func switchesToAnExistingLocalBranchRatherThanRecreatingItFromTheRemote() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [branchRepository(localBranches: ["feature", "main"])]]
        )
        let state = await workspace(stub)

        await state.checkout(.remoteBranch("origin/feature"))

        #expect(await stub.recordedArguments() == [["switch", "--no-guess", "--", "feature"]])
    }

    @Test
    @MainActor
    func checksOutATagAsAnExplicitDetachedHead() async throws {
        let stub = RepositoryServiceStub(snapshots: [repositoryURL: [branchRepository()]])
        let state = await workspace(stub)

        await state.checkout(.tag("v1.0"))

        #expect(await stub.recordedArguments() == [["switch", "--detach", "refs/tags/v1.0"]])
    }

    /// HEAD is already checked out, so nothing offers to check it out again.
    @Test
    @MainActor
    func offersNoCheckoutOfWhatIsAlreadyCheckedOut() async throws {
        let stub = RepositoryServiceStub(snapshots: [repositoryURL: [branchRepository()]])
        let state = await workspace(stub)

        #expect(!state.canCheckout(.head))
        await state.checkout(.head)

        #expect(await stub.recordedArguments().isEmpty)
    }

    /// The refusal names the work Git protected and says what to do with it, and Git's own words
    /// stay one click away.
    @Test
    @MainActor
    func refusesACheckoutThatWouldOverwriteLocalWork() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [
                repositoryURL: [
                    branchRepository(
                        localBranches: ["feature", "main"],
                        unstagedChanges: [
                            RepositoryChange(path: "notes.txt", kind: .untracked),
                            RepositoryChange(path: "shared.swift", kind: .modified),
                        ]
                    ),
                ],
            ],
            mutationError: .commandFailed(
                GitFailureDetails(
                    command: "git switch",
                    output: "error: Your local changes would be overwritten",
                    exitStatus: 1
                )
            ),
            checkoutComparison: CheckoutComparison(
                changedPaths: ["notes.txt", "shared.swift"],
                addedPaths: ["notes.txt"]
            )
        )
        let state = await workspace(stub)

        await state.checkout(.localBranch("feature"))

        let failure = try #require(state.repositoryFailure)
        guard case .checkoutRefusedAlert(let obstruction, let reference, _) = failure else {
            Issue.record("Expected the Checkout refusal, got \(failure)")
            return
        }
        #expect(obstruction.modifiedPaths == ["shared.swift"])
        #expect(obstruction.untrackedPaths == ["notes.txt"])
        #expect(reference == "feature")
        #expect(state.canShowRepositoryFailureDetails)
        #expect(state.isShowingRepositoryMutationError)
        let message = try #require(state.repositoryFailureMessage)
        #expect(String(localized: message).contains("shared.swift"))
        // Nothing was offered that would overwrite the work Git protected.
        #expect(state.repository?.head == .branch("main"))
    }

    /// A failure that overwrites nothing is an ordinary command failure, and is reported as one
    /// rather than as a refusal Colofa cannot substantiate.
    @Test
    @MainActor
    func reportsAnOrdinaryFailureWhenNoLocalWorkWasInTheWay() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [branchRepository(localBranches: ["feature", "main"])]],
            mutationError: .commandFailed(
                GitFailureDetails(command: "git switch", output: "fatal", exitStatus: 128)
            )
        )
        let state = await workspace(stub)

        await state.checkout(.localBranch("feature"))

        guard case .mutationAlert? = state.repositoryFailure else {
            let failure = String(describing: state.repositoryFailure)
            Issue.record("Expected the shared command alert, got \(failure)")
            return
        }
    }

    /// Every command any of these paths can run, checked in one place: none of them may carry a
    /// way to overwrite local work.
    @Test
    @MainActor
    func neverRunsAcommandThatOverwritesLocalWork() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [branchRepository(localBranches: ["feature", "main"])]]
        )
        let state = await workspace(stub)
        await state.checkout(.localBranch("feature"))
        await state.checkout(.remoteBranch("origin/feature"))
        await state.checkout(.tag("v1.0"))
        state.beginCreatingBranch()
        state.branchCreation?.name = "created"
        await state.validateBranchName()
        await state.createBranch()

        for arguments in await stub.recordedArguments() {
            #expect(!arguments.contains(where: refusedCheckoutOptions.contains))
        }
    }
}
