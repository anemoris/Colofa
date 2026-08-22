////
//  BranchActionUnavailabilityReasonTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

struct BranchActionUnavailabilityReasonTests {
    private static let repositoryURL = URL(filePath: "/tmp/colofa-branch-tests")

    private static func snapshot(
        head: RepositoryHead = .branch("main"),
        operation: RepositoryOperation? = nil,
        unstagedChanges: [RepositoryChange] = []
    ) -> RepositorySnapshot {
        repository(
            at: repositoryURL,
            head: head,
            operation: operation,
            localBranches: ["feature", "main"],
            unstagedChanges: unstagedChanges
        )
    }

    @Test
    func allowsCreationOnAnOrdinaryRepository() {
        #expect(
            BranchActionUnavailabilityReason.evaluateCreation(
                repository: Self.snapshot(),
                isMutating: false
            ) == nil
        )
    }

    @Test
    func refusesCreationWithoutARepository() {
        #expect(
            BranchActionUnavailabilityReason.evaluateCreation(
                repository: nil,
                isMutating: false
            ) == .noRepository
        )
    }

    /// An Unborn Branch names no Commit, so a new branch has nothing to start at.
    @Test
    func refusesCreationOnAnUnbornBranch() {
        #expect(
            BranchActionUnavailabilityReason.evaluateCreation(
                repository: Self.snapshot(head: .unbornBranch("main")),
                isMutating: false
            ) == .unbornBranch
        )
    }

    /// A branch may be created during a Merge or a Rebase: `git branch` writes one ref and
    /// touches nothing the operation owns.
    @Test
    func allowsCreationDuringAnOperation() {
        #expect(
            BranchActionUnavailabilityReason.evaluateCreation(
                repository: Self.snapshot(operation: .rebase),
                isMutating: false
            ) == nil
        )
    }

    @Test
    func refusesCreationWhileAnotherCommandRuns() {
        #expect(
            BranchActionUnavailabilityReason.evaluateCreation(
                repository: Self.snapshot(),
                isMutating: true
            ) == .mutationInProgress
        )
    }

    @Test
    func allowsCheckoutOfAnotherBranch() {
        #expect(
            BranchActionUnavailabilityReason.evaluateCheckout(
                target: CheckoutTarget.resolve(.localBranch("feature"), in: Self.snapshot()),
                repository: Self.snapshot(),
                isMutating: false
            ) == nil
        )
    }

    /// HEAD offers no Checkout, and neither does the branch HEAD is already on.
    @Test
    func refusesCheckoutOfWhatIsAlreadyCheckedOut() {
        #expect(
            BranchActionUnavailabilityReason.evaluateCheckout(
                target: nil,
                repository: Self.snapshot(),
                isMutating: false
            ) == .alreadyCheckedOut
        )
        #expect(
            BranchActionUnavailabilityReason.evaluateCheckout(
                target: CheckoutTarget.resolve(.localBranch("main"), in: Self.snapshot()),
                repository: Self.snapshot(),
                isMutating: false
            ) == .alreadyCheckedOut
        )
    }

    /// Git refuses to switch during a Merge, Rebase, or Revert, so the control says so first.
    @Test
    func refusesCheckoutDuringAnOperation() {
        let snapshot = Self.snapshot(operation: .rebase)

        #expect(
            BranchActionUnavailabilityReason.evaluateCheckout(
                target: CheckoutTarget.resolve(.localBranch("feature"), in: snapshot),
                repository: snapshot,
                isMutating: false
            ) == .operationInProgress
        )
    }

    @Test
    func refusesCheckoutWhileAPathIsUnmerged() {
        let snapshot = Self.snapshot(
            unstagedChanges: [RepositoryChange(path: "conflict.txt", kind: .conflict)]
        )

        #expect(
            BranchActionUnavailabilityReason.evaluateCheckout(
                target: CheckoutTarget.resolve(.localBranch("feature"), in: snapshot),
                repository: snapshot,
                isMutating: false
            ) == .conflict
        )
    }

    /// Every reason has to be able to say itself, or a disabled control explains nothing.
    @Test(
        arguments: [
            BranchActionUnavailabilityReason.noRepository,
            .unbornBranch,
            .alreadyCheckedOut,
            .operationInProgress,
            .conflict,
            .mutationInProgress,
        ]
    )
    func statesEveryReason(_ reason: BranchActionUnavailabilityReason) {
        #expect(!String(localized: reason.message).isEmpty)
    }
}
