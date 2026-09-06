////
//  UITestingMerge.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

#if DEBUG
import Foundation

/// What the stubbed backend answers about Merge, so a UI test can drive a Merge that succeeds,
/// one Git refuses because untracked files stand in the way, one that cannot fast-forward, and
/// one that leaves a Conflict to resolve.
///
/// Declared `nonisolated` because the project defaults to Main Actor isolation while
/// `UITestingRepositoryService` reads these from an actor.
nonisolated enum UITestingMerge {
    /// The Branch the fixture merges in, which is the one both the confirmation and the Conflict
    /// version choices have to name.
    static let sourceBranch = "feature/真实"

    /// The Branch the fixture merges into, which is the other name the confirmation shows.
    static let targetBranch = "main"

    /// The path a conflicted Merge leaves unmerged.
    static let conflictedPath = "conflict.txt"

    /// The untracked path the fixture carries, which is both the work a Merge is allowed to
    /// proceed over and the work a collision names.
    static let untrackedPath = "notes.txt"

    /// The tracked path that blocks a Merge before any command runs.
    static let modifiedPath = "partial 文件.txt"

    /// What `MERGE_HEAD` reports once the fixture's Merge has stopped at a Conflict.
    static let mergeHead = MergeHead(branch: sourceBranch, objectID: "ui-merge")

    /// Whether this is a Merge Colofa started, rather than the fast-forward half of a Pull or any
    /// other command that happens to begin with `merge`.
    static func isMerge(_ command: [String]) -> Bool {
        command.first == "merge" && !command.contains("--abort")
    }

    static func isAbort(_ command: [String]) -> Bool {
        command == MergeCommand.abort
    }

    /// Whether this is the Commit that completes an unfinished Merge.
    static func isContinue(_ command: [String]) -> Bool {
        command == MergeCommand.completing
    }

    /// Whether this restores one side of a Conflict, which writes the working tree and leaves the
    /// path unmerged.
    static func isVersionChoice(_ command: [String]) -> Bool {
        command.contains("checkout") && (command.contains("--ours") || command.contains("--theirs"))
    }

    /// How Git refuses the Merge this fixture was told to refuse, or `nil` when it accepts one.
    static func refusal(_ command: [String], arguments: [String]) -> RepositoryOpenError? {
        if arguments.contains(UITestingArgument.mergeCollision) {
            return .commandFailed(
                GitFailureDetails(
                    command: "git merge",
                    output: """
                    error: The following untracked working tree files would be overwritten by \
                    merge:
                    \t\(untrackedPath)
                    """,
                    exitStatus: 2
                )
            )
        }
        guard arguments.contains(UITestingArgument.mergeNotFastForward),
              command.contains("--ff-only") else {
            return nil
        }
        return .commandFailed(
            GitFailureDetails(
                command: "git merge",
                output: "fatal: Not possible to fast-forward, aborting.",
                exitStatus: 128
            )
        )
    }

    /// The paths the source Branch adds, which is what turns a refused Merge into one that can
    /// name the untracked files it protected.
    static func comparison(arguments: [String]) -> CheckoutComparison {
        guard arguments.contains(UITestingArgument.mergeCollision) else {
            return .empty
        }
        return CheckoutComparison(changedPaths: [untrackedPath], addedPaths: [untrackedPath])
    }
}
#endif
