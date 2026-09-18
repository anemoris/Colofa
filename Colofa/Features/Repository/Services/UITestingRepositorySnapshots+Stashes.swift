////
//  UITestingRepositorySnapshots+Stashes.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

#if DEBUG
import Foundation

/// The Repository a Stash UI test starts from.
///
/// Grouped apart from the other fixtures because a Stash needs a working tree that is neither
/// clean nor conflicted, and needs each kind of eligible work separable: what Keep Staged Changes
/// and Include Untracked Files do is only visible when the index and the untracked file are
/// distinct from the tracked change beside them.
///
/// Declared `nonisolated` for the same reason the rest of the fixture is: the project defaults to
/// Main Actor isolation while `UITestingRepositoryService` builds these from an actor.
nonisolated extension UITestingRepositorySnapshots {
    static func stashState(at url: URL, arguments: [String]) -> RepositorySnapshot {
        RepositorySnapshot(
            name: url.lastPathComponent,
            rootURL: url,
            gitDirectoryURL: url.appending(path: ".git"),
            head: .branch("main"),
            headCommit: RepositoryHeadCommit(
                objectID: "ui-fixture-head",
                summary: "Fixture commit"
            ),
            remotes: [RepositoryRemote(name: "origin", url: "ssh://example.invalid/Colofa.git")],
            localBranches: ["main"],
            stagedChanges: stagedStashChanges(arguments: arguments),
            unstagedChanges: unstagedStashChanges(arguments: arguments),
            totalCommitCount: 12,
            gitObjectSize: 4_096,
            configuration: configuration(at: url)
        )
    }

    /// The index the fixture starts with: empty whenever the test wants a tree the default
    /// options would save nothing from, and one Staged Change otherwise.
    private static func stagedStashChanges(arguments: [String]) -> [RepositoryChange] {
        guard hasTrackedStashChanges(arguments: arguments) else {
            return []
        }
        return [RepositoryChange(path: "staged.swift", kind: .added)]
    }

    private static func unstagedStashChanges(arguments: [String]) -> [RepositoryChange] {
        guard !arguments.contains(UITestingArgument.stashCleanState) else {
            return []
        }
        var changes = [
            RepositoryChange(path: UITestingStashes.untrackedPath, kind: .untracked),
        ]
        if hasTrackedStashChanges(arguments: arguments) {
            changes.insert(
                RepositoryChange(path: UITestingStashes.trackedPath, kind: .modified),
                at: 0
            )
        }
        return changes
    }

    private static func hasTrackedStashChanges(arguments: [String]) -> Bool {
        !arguments.contains(UITestingArgument.stashCleanState)
            && !arguments.contains(UITestingArgument.stashUntrackedOnly)
    }
}
#endif
