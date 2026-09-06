////
//  UITestingRepositoryService+Merge.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

#if DEBUG
import Foundation

/// What the stubbed backend does with a Merge and with the commands that end one, so UI tests can
/// assert the Repository state each leaves behind.
///
/// The Conflict it produces is real state rather than a flag: the unmerged path, the operation,
/// and the `MERGE_HEAD` label all travel in the published snapshot, which is what lets a refresh
/// find the Conflict exactly where it was.
extension UITestingRepositoryService {
    /// The Repository state a Merge or one of its exits leaves behind, or `nil` when the command
    /// is not one of them.
    ///
    /// - Throws: The way Git refuses a Merge, including the non-zero status a Merge that stopped
    ///   at a Conflict ends with.
    func mergeMutation(
        _ command: [String],
        in snapshot: RepositorySnapshot
    ) throws -> RepositorySnapshot? {
        if UITestingMerge.isMerge(command) {
            return try merged(command, in: snapshot)
        }
        if UITestingMerge.isAbort(command) {
            return finished(snapshot, totalCommitCount: snapshot.totalCommitCount)
        }
        if UITestingMerge.isContinue(command) {
            return finished(snapshot, totalCommitCount: snapshot.totalCommitCount + 1)
        }
        if UITestingMerge.isVersionChoice(command) {
            // Git writes the working tree and leaves the path unmerged, so the fixture reports
            // exactly the Repository it did before: the Conflict is over only once it is staged.
            return snapshot
        }
        return nil
    }

    /// Answers what a read explaining a refused Merge asks: which paths the source Branch adds.
    func mergeComparison(_ request: CheckoutComparisonRequest) -> CheckoutComparison? {
        guard request.revision.hasPrefix("refs/heads/")
            || request.revision.hasPrefix("refs/remotes/"),
              arguments.contains(UITestingArgument.mergeCollision) else {
            return nil
        }
        return UITestingMerge.comparison(arguments: arguments)
    }

    private func merged(
        _ command: [String],
        in snapshot: RepositorySnapshot
    ) throws -> RepositorySnapshot {
        if let refusal = UITestingMerge.refusal(command, arguments: arguments) {
            throw refusal
        }
        guard arguments.contains(UITestingArgument.mergeConflict) else {
            return replacing(
                in: snapshot,
                headCommit: RepositoryHeadCommit(
                    objectID: "ui-merge-head",
                    summary: "Merge branch '\(UITestingMerge.sourceBranch)'"
                ),
                totalCommitCount: snapshot.totalCommitCount + 1
            )
        }

        // Git stops at the Conflict and exits non-zero, so the fixture publishes the unfinished
        // Merge first and then reports the same status Git does: what tells a Conflict apart from
        // a failure is the Repository, not the exit code.
        publish(
            replacing(
                in: snapshot,
                unstaged: [
                    RepositoryChange(path: UITestingMerge.conflictedPath, kind: .conflict),
                ] + snapshot.unstagedChanges,
                operation: .merge,
                mergeHead: UITestingMerge.mergeHead
            )
        )
        throw RepositoryOpenError.commandFailed(
            GitFailureDetails(
                command: "git merge",
                output: "Automatic merge failed; fix conflicts and then commit the result.",
                exitStatus: 1
            )
        )
    }

    /// The Repository an unfinished Merge leaves once it is completed or rolled back: no
    /// operation, no `MERGE_HEAD`, and nothing left over from the Conflict either way.
    private func finished(
        _ snapshot: RepositorySnapshot,
        totalCommitCount: Int
    ) -> RepositorySnapshot {
        replacing(
            in: snapshot,
            staged: [],
            unstaged: snapshot.unstagedChanges.filter { !$0.isConflict },
            totalCommitCount: totalCommitCount,
            operation: RepositoryOperation?.none,
            mergeHead: MergeHead?.none
        )
    }
}
#endif
