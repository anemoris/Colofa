////
//  UITestingRepositorySnapshots+Pull.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

#if DEBUG
import Foundation

/// The Repository a UI test drives a Pull in.
///
/// Declared `nonisolated` for the same reason the rest of the fixture is: the project defaults to
/// Main Actor isolation while `UITestingRepositoryService` builds these from an actor.
nonisolated extension UITestingRepositorySnapshots {
    /// A Repository whose current Branch is behind its upstream, which is what a Pull is for.
    ///
    /// The counts it starts with are the ones the last Fetch left, exactly as a real snapshot's
    /// are: what the upstream actually holds is not known until this Pull's own Fetch answers.
    static func pullState(at url: URL, arguments: [String]) -> RepositorySnapshot {
        RepositorySnapshot(
            name: url.lastPathComponent,
            rootURL: url,
            gitDirectoryURL: url.appending(path: ".git"),
            head: .branch("main"),
            headCommit: RepositoryHeadCommit(
                objectID: "ui-pull-head",
                summary: "Fixture commit"
            ),
            upstream: arguments.contains(UITestingArgument.pullNoUpstream)
                ? nil
                : RepositoryUpstream(
                    name: UITestingPull.upstream,
                    ahead: 0,
                    behind: UITestingPull.behindCount
                ),
            remotes: [RepositoryRemote(name: "origin", url: "ssh://example.invalid/Colofa.git")],
            localBranches: ["main"],
            remoteBranches: ["origin/main"],
            unstagedChanges: arguments.contains(UITestingArgument.pullBlocked)
                ? [RepositoryChange(path: UITestingPull.blockedPath, kind: .modified)]
                : [],
            totalCommitCount: 12,
            gitObjectSize: 4_096,
            configuration: configuration(at: url)
        )
    }
}
#endif
