////
//  UITestingRepositorySnapshots+Merge.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

#if DEBUG
import Foundation

/// The Repository a Merge UI test starts from.
///
/// Grouped apart from the branch fixture because a Merge needs the opposite starting tree: the
/// branch fixture carries a tracked local change so a refused Checkout has work to protect, and
/// that same change would block every Merge before a command ever ran.
///
/// Declared `nonisolated` for the same reason the rest of the fixture is: the project defaults to
/// Main Actor isolation while `UITestingRepositoryService` builds these from an actor.
nonisolated extension UITestingRepositorySnapshots {
    /// A Repository with a Branch worth merging into the current one, and a working tree that
    /// only holds whatever the test asked for.
    static func mergeState(at url: URL, arguments: [String]) -> RepositorySnapshot {
        RepositorySnapshot(
            name: url.lastPathComponent,
            rootURL: url,
            gitDirectoryURL: url.appending(path: ".git"),
            head: .branch(UITestingMerge.targetBranch),
            headCommit: RepositoryHeadCommit(
                objectID: "ui-merge-target-head",
                summary: "Fixture commit"
            ),
            remotes: [RepositoryRemote(name: "origin", url: "ssh://example.invalid/Colofa.git")],
            localBranches: [UITestingMerge.sourceBranch, UITestingMerge.targetBranch],
            remoteBranches: ["origin/main"],
            tags: ["v1.0-测试"],
            unstagedChanges: mergeChanges(arguments: arguments),
            totalCommitCount: 12,
            gitObjectSize: 4_096,
            configuration: configuration(at: url)
        )
    }

    /// What the merge fixture's working tree holds: nothing, an untracked file a Merge may run
    /// over, or a tracked change that stops one.
    private static func mergeChanges(arguments: [String]) -> [RepositoryChange] {
        var changes: [RepositoryChange] = []
        if arguments.contains(UITestingArgument.mergeUntrackedOnly)
            || arguments.contains(UITestingArgument.mergeCollision) {
            changes.append(
                RepositoryChange(path: UITestingMerge.untrackedPath, kind: .untracked)
            )
        }
        if arguments.contains(UITestingArgument.mergeLocalChanges) {
            changes.append(
                RepositoryChange(path: UITestingMerge.modifiedPath, kind: .modified)
            )
        }
        return changes
    }
}
#endif
