////
//  PushConfirmationTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// The confirmation a Push opens, and the one option in it that can replace somebody else's work.
struct PushConfirmationTests {

    /// A normal Push is what pressing Push means, so the dangerous option starts off and the
    /// command carries no lease at all.
    @Test
    func anewConfirmationPushesNormally() {
        let confirmation = pushConfirmation(
            branch: "main",
            target: pushTarget(),
            localObjectID: pushLocalObjectID
        )

        #expect(!confirmation.forcesWithLease)
        #expect(confirmation.lease == nil)
        #expect(confirmation.work == .pushing)
        #expect(!confirmation.arguments.contains { $0.hasPrefix("--force-with-lease=") })
    }

    /// Ticked, it supplies exactly the object the remote was holding when the dialog opened.
    @Test
    func tickingTheBoxSuppliesTheExactExpectedObject() {
        var confirmation = pushConfirmation(
            branch: "main",
            target: pushTarget(),
            localObjectID: pushLocalObjectID
        )
        confirmation.forcesWithLease = true

        #expect(confirmation.lease == pushExpectedObjectID)
        #expect(confirmation.work == .forcing)
        #expect(
            confirmation.arguments
                .contains("--force-with-lease=refs/heads/main:\(pushExpectedObjectID)")
        )
    }

    /// An upstream nobody has ever fetched leaves nothing to lease against, and a force with no
    /// expected object is the naked force this dialog exists to make impossible.
    @Test
    func anupstreamNobodyHasSeenOffersNoLeaseAndSoNoForce() {
        var confirmation = pushConfirmation(
            branch: "main",
            target: pushTarget(expectedObjectID: nil),
            localObjectID: pushLocalObjectID
        )
        #expect(!confirmation.canForceWithLease)

        confirmation.forcesWithLease = true

        #expect(confirmation.lease == nil)
        #expect(!confirmation.arguments.contains { $0.hasPrefix("--force-with-lease") })
        #expect(!confirmation.arguments.contains("--force"))
    }

    // MARK: - Still describing the Repository

    /// A reload that changed nothing must leave the dialog alone: the window becoming active is
    /// enough to cause one, and a confirmation that closed every time would be unusable.
    @Test
    func areloadThatChangedNothingLeavesTheConfirmationStanding() {
        let confirmation = pushConfirmation(
            branch: "main",
            target: pushTarget(),
            localObjectID: pushLocalObjectID
        )

        #expect(confirmation.describes(pushRepository()))
        #expect(confirmation.describes(pushRepository(ahead: 0)))
    }

    /// The Branch and the upstream are what the dialog shows, so a Repository that no longer
    /// matches either of them is no longer the Repository the user agreed to push.
    @Test
    func abranchOrUpstreamThatMovedOnStopsDescribingTheRepository() {
        let confirmation = pushConfirmation(
            branch: "main",
            target: pushTarget(),
            localObjectID: pushLocalObjectID
        )

        #expect(!confirmation.describes(pushRepository(head: .branch("other"))))
        #expect(!confirmation.describes(pushRepository(upstream: "mirror/main")))
        #expect(!confirmation.describes(pushRepository(upstream: nil)))
        #expect(!confirmation.describes(pushRepository(head: .detached("cafebabe"))))
    }

    /// An ordinary Push is not sensitive to the Branch moving: a remote refuses anything that is
    /// no longer a fast-forward, so Colofa has nothing to protect here and does not interfere.
    @Test
    func anordinaryPushSurvivesTheBranchMovingUnderIt() {
        let confirmation = pushConfirmation(
            branch: "main",
            target: pushTarget(),
            localObjectID: "an older commit"
        )

        #expect(confirmation.describes(pushRepository()))
    }

    /// A force has no such refusal on the local side, so the history it installs must still be
    /// the history the box was ticked against.
    @Test
    func aforceStopsDescribingTheRepositoryOnceTheBranchMoves() {
        var confirmation = pushConfirmation(
            branch: "main",
            target: pushTarget(),
            localObjectID: "an older commit"
        )
        confirmation.forcesWithLease = true

        #expect(!confirmation.describes(pushRepository()))
    }
}
