////
//  UITestingPull.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

#if DEBUG
import Foundation

/// What the stubbed backend answers about Pull, so a UI test can drive a Pull that fast-forwards,
/// one the remote and the Branch have diverged under, one local work stands in the way of, and one
/// slow enough to be cancelled.
///
/// Declared `nonisolated` because the project defaults to Main Actor isolation while
/// `UITestingRepositoryService` reads these from an actor.
nonisolated enum UITestingPull {
    static let upstream = "origin/main"

    /// How far behind the fixture's Branch starts, which is what one Pull is meant to close.
    static let behindCount = 2

    /// The local Commit the diverging fixture has and its upstream does not.
    static let aheadCount = 1

    /// The tracked path the refused Pull protects, which the alert has to name.
    static let blockedPath = "本地更改.txt"

    /// Whether this is the Fetch half of a Pull rather than a Fetch of a named remote.
    static func isFetch(_ command: [String]) -> Bool {
        command == PullCommand.fetch
    }

    /// Whether this is the fast-forward half of a Pull.
    static func isFastForward(_ command: [String]) -> Bool {
        command == PullCommand.fastForward
    }

    /// What the upstream turns out to hold once the Fetch half has answered.
    static func fetchedUpstream(arguments: [String]) -> RepositoryUpstream {
        RepositoryUpstream(
            name: upstream,
            ahead: arguments.contains(UITestingArgument.pullDiverged) ? aheadCount : 0,
            behind: behindCount
        )
    }

    /// The upstream a completed fast-forward leaves behind, which is one nothing separates.
    static let mergedUpstream = RepositoryUpstream(name: upstream, ahead: 0, behind: 0)

    /// The paths the upstream changes, which is what turns a refused fast-forward into a refusal
    /// that can name the local work it protected.
    static func comparison(arguments: [String]) -> CheckoutComparison {
        guard arguments.contains(UITestingArgument.pullBlocked) else {
            return .empty
        }
        return CheckoutComparison(changedPaths: [blockedPath], addedPaths: [])
    }

    /// Whether the fixture refuses the fast-forward, and what Git wrote while refusing.
    ///
    /// Divergence and local work in the way are the two refusals Colofa explains itself, and
    /// each is reported the way Git reports it: divergence is fatal before the working tree is
    /// touched, and protected local work exits with 1 having changed nothing.
    static func refusal(arguments: [String]) -> RepositoryOpenError? {
        if arguments.contains(UITestingArgument.pullDiverged) {
            return .commandFailed(
                GitFailureDetails(
                    command: "git merge",
                    output: "fatal: Not possible to fast-forward, aborting.",
                    exitStatus: 128
                )
            )
        }
        guard arguments.contains(UITestingArgument.pullBlocked) else {
            return nil
        }
        return .commandFailed(
            GitFailureDetails(
                command: "git merge",
                output: """
                    error: Your local changes to the following files would be overwritten by \
                    merge:\n\t\(blockedPath)
                    """,
                exitStatus: 1
            )
        )
    }
}
#endif
