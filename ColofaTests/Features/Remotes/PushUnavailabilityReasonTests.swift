////
//  PushUnavailabilityReasonTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// Why a disabled Publish or Push explains itself instead of letting Git refuse the command
/// afterwards.
struct PushUnavailabilityReasonTests {
    private let repositoryURL = URL(filePath: "/tmp/Push Reasons")

    private func evaluate(
        _ snapshot: RepositorySnapshot?,
        isMutating: Bool = false,
        isPushing: Bool = false
    ) -> PushUnavailabilityReason? {
        PushUnavailabilityReason.evaluate(
            repository: snapshot,
            isMutating: isMutating,
            isPushing: isPushing
        )
    }

    @Test
    func noRepositoryIsTheFirstThingThereIsNothingToDoAbout() {
        #expect(evaluate(nil) == .noRepository)
    }

    /// Detached HEAD is on no Branch, so there is nothing to publish and no upstream to push to.
    @Test
    func detachedHeadCanNeitherPublishNorPush() {
        #expect(evaluate(pushRepository(head: .detached("0123456"))) == .detachedHead)
    }

    /// It stays the answer even where a remote and an upstream are configured, because what is
    /// missing is the Branch itself.
    @Test
    func detachedHeadOutranksEverythingElseThatCouldBeMissing() {
        let snapshot = pushRepository(head: .detached("0123456"), remotes: [])

        #expect(evaluate(snapshot, isMutating: true, isPushing: true) == .detachedHead)
    }

    @Test
    func anunbornBranchHasNoCommitAremoteCouldReceive() {
        #expect(evaluate(pushRepository(head: .unbornBranch("main"))) == .unbornBranch)
    }

    @Test
    func arepositoryWithNoRemoteHasNowhereToPublishTo() {
        #expect(evaluate(pushRepository(remotes: [])) == .noRemote)
    }

    @Test
    func arunningPushHoldsTheNextOne() {
        #expect(evaluate(pushRepository(), isPushing: true) == .pushInProgress)
    }

    /// Last of the reasons, so a transient in-flight command never replaces a standing
    /// explanation with a flicker.
    @Test
    func acommandAlreadyHoldingTheRepositoryIsTheLastReasonGiven() {
        #expect(evaluate(pushRepository(), isMutating: true) == .mutationInProgress)
        #expect(
            evaluate(pushRepository(remotes: []), isMutating: true) == .noRemote,
            "A transient command hid a state the user has to fix"
        )
    }

    /// Git pushes Commits that already exist whatever the working tree looks like, so neither an
    /// unresolved Conflict nor an active operation is a rule Colofa invents.
    @Test
    func neitherAconflictNorAnactiveOperationStandsInTheWayOfApush() {
        let conflicted = pushRepository(
            operation: .rebase,
            unstagedChanges: [RepositoryChange(path: "conflict.txt", kind: .conflict)]
        )

        #expect(evaluate(conflicted) == nil)
    }

    /// A Branch nobody has pushed yet is exactly what Publish is for, so having no upstream is
    /// never a reason to refuse.
    @Test
    func abranchWithNoUpstreamIsPublishableRatherThanRefused() {
        #expect(evaluate(pushRepository(upstream: nil)) == nil)
    }
}
