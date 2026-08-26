////
//  PullUnavailabilityReasonTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// Why a disabled Pull is disabled, said before the command rather than after it.
struct PullUnavailabilityReasonTests {
    private func evaluate(
        _ repository: RepositorySnapshot?,
        isMutating: Bool = false,
        isPulling: Bool = false
    ) -> PullUnavailabilityReason? {
        PullUnavailabilityReason.evaluate(
            repository: repository,
            isMutating: isMutating,
            isPulling: isPulling
        )
    }

    @Test
    func allowsAPullOfABranchWithAnUpstream() {
        #expect(evaluate(pullRepository()) == nil)
    }

    @Test
    func refusesWithoutARepository() {
        #expect(evaluate(nil) == .noRepository)
    }

    @Test
    func refusesOnDetachedHead() {
        #expect(evaluate(pullRepository(head: .detached("0123456789"))) == .detachedHead)
    }

    @Test
    func refusesWithoutAnUpstream() {
        #expect(evaluate(pullRepository(upstream: nil)) == .noUpstream)
    }

    /// An Unborn Branch with an upstream is exactly what a first Pull resolves, and Git
    /// fast-forwards it like any other Branch.
    @Test
    func allowsAPullIntoAnUnbornBranch() {
        #expect(evaluate(pullRepository(head: .unbornBranch("main"))) == nil)
    }

    /// A Branch that has not moved apart from its upstream yet still has a Pull worth running:
    /// the counts a snapshot carries were true as of the last Fetch, not now.
    @Test
    func allowsAPullThatMayTurnOutToHaveNothingToDo() {
        #expect(evaluate(pullRepository(ahead: 0, behind: 0)) == nil)
    }

    /// Divergence is the remote's answer, not a snapshot's, so it never disables the button. It
    /// is reported as a refusal once the Fetch has actually asked.
    @Test
    func allowsAPullOfABranchTheLastFetchLeftDiverged() {
        #expect(evaluate(pullRepository(ahead: 2, behind: 3)) == nil)
    }

    @Test
    func refusesDuringAnotherGitOperation() {
        #expect(evaluate(pullRepository(operation: .rebase)) == .operationInProgress)
    }

    @Test
    func refusesWhileAPathIsStillUnmerged() {
        #expect(
            evaluate(
                pullRepository(
                    unstagedChanges: [RepositoryChange(path: "conflict.txt", kind: .conflict)]
                )
            ) == .conflict
        )
    }

    @Test
    func refusesWhileAnotherCommandHoldsTheRepository() {
        #expect(evaluate(pullRepository(), isMutating: true) == .mutationInProgress)
    }

    /// A Pull already running is its own reason, so the toolbar offers to stop that one rather
    /// than blaming an unrelated command.
    @Test
    func reportsARunningPullRatherThanAGenericMutation() {
        #expect(
            evaluate(pullRepository(), isMutating: true, isPulling: true) == .pullInProgress
        )
    }
}
