////
//  UITestingRepositoryService+Pull.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

#if DEBUG
import Foundation

/// What the stubbed backend does with the fast-forward half of a Pull, and with the read that
/// explains a fast-forward it refused.
///
/// Grouped apart from the Fetch half because they behave differently: this one cannot be stopped,
/// and it is the half that moves the Branch.
extension UITestingRepositoryService {
    /// Advances the Branch to the upstream the Fetch half brought in, or refuses the way Git
    /// refuses a divergence or local work standing in the way.
    func fastForward(in snapshot: RepositorySnapshot) throws {
        if let refusal = UITestingPull.refusal(arguments: arguments) {
            throw refusal
        }
        publish(
            replacing(
                in: snapshot,
                headCommit: RepositoryHeadCommit(
                    objectID: "ui-pull-upstream-head",
                    summary: "Upstream commit"
                ),
                upstream: UITestingPull.mergedUpstream,
                totalCommitCount: snapshot.totalCommitCount + UITestingPull.behindCount
            )
        )
    }

    /// Answers the question the request actually asks. The revision names which command is being
    /// explained: a Pull compares the working tree against the upstream it just fetched, and a
    /// Checkout against the Ref it was asked to move to.
    func loadCheckoutComparison(_ request: CheckoutComparisonRequest) -> CheckoutComparison {
        request.revision == PullCommand.upstreamRevision
            ? UITestingPull.comparison(arguments: arguments)
            : UITestingBranches.comparison(arguments: arguments)
    }
}
#endif
