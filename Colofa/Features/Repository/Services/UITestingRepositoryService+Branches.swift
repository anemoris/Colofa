////
//  UITestingRepositoryService+Branches.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

#if DEBUG
import Foundation

/// What the stubbed backend does with the branch commands Colofa runs, so UI tests can assert the
/// Repository state each one leaves behind.
extension UITestingRepositoryService {
    /// The Repository state a branch command leaves behind, or `nil` when the command is not one.
    func branchMutation(
        _ command: [String],
        in snapshot: RepositorySnapshot
    ) -> RepositorySnapshot? {
        switch command.first {
        case "branch":
            replacing(
                in: snapshot,
                localBranches: adding(createdBranch(in: command), to: snapshot)
            )
        case "switch":
            switched(command, in: snapshot)
        default:
            nil
        }
    }

    /// Git refuses a Checkout that would overwrite local work, and refuses it whole: nothing is
    /// created and HEAD does not move.
    func throwRequestedCheckoutRefusal(of command: [String]) throws {
        guard arguments.contains(UITestingArgument.checkoutBlocked),
              command.first == "switch" else {
            return
        }
        throw RepositoryOpenError.commandFailed(
            GitFailureDetails(
                command: "git switch",
                output: "error: Your local changes would be overwritten by checkout",
                exitStatus: 1
            )
        )
    }

    /// The branch `git branch -- <name> <start-point>` names, which is the argument after `--`.
    private func createdBranch(in command: [String]) -> String? {
        command.drop { $0 != "--" }.dropFirst().first
    }

    /// What `git switch` leaves behind: a new branch and HEAD on it, HEAD on an existing branch,
    /// or a Detached HEAD at the Commit a tag names.
    private func switched(
        _ command: [String],
        in snapshot: RepositorySnapshot
    ) -> RepositorySnapshot {
        if let detachIndex = command.firstIndex(of: "--detach"),
           command.index(after: detachIndex) < command.endIndex {
            return replacing(
                in: snapshot,
                head: .detached(
                    UITestingCommitID.objectID(prefix: UITestingCommitID.tagPrefix, index: 0)
                )
            )
        }
        if let createIndex = command.firstIndex(of: "--create"),
           command.index(after: createIndex) < command.endIndex {
            let name = command[command.index(after: createIndex)]
            return replacing(
                in: snapshot,
                head: .branch(name),
                localBranches: adding(name, to: snapshot)
            )
        }
        guard let name = command.drop(while: { $0 != "--" }).dropFirst().first else {
            return snapshot
        }
        return replacing(in: snapshot, head: .branch(name))
    }

    private func adding(_ branch: String?, to snapshot: RepositorySnapshot) -> [String] {
        guard let branch, !snapshot.localBranches.contains(branch) else {
            return snapshot.localBranches
        }
        return (snapshot.localBranches + [branch]).sorted()
    }
}
#endif
