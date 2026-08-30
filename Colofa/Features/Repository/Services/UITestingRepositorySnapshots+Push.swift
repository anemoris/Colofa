////
//  UITestingRepositorySnapshots+Push.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

#if DEBUG
import Foundation

/// The Repository a UI test drives a Publish or a Push in.
///
/// Declared `nonisolated` for the same reason the rest of the fixture is: the project defaults to
/// Main Actor isolation while `UITestingRepositoryService` builds these from an actor.
nonisolated extension UITestingRepositorySnapshots {

    /// A Repository whose current Branch is ahead of its upstream, or — with
    /// `pushNoUpstream` — has never been pushed anywhere at all.
    static func pushState(at url: URL, arguments: [String]) -> RepositorySnapshot {
        let isUnpublished = UITestingPush.isUnpublished(arguments: arguments)
        return RepositorySnapshot(
            name: url.lastPathComponent,
            rootURL: url,
            gitDirectoryURL: url.appending(path: ".git"),
            head: arguments.contains(UITestingArgument.detachedHead)
                ? .detached("0123456789abcdef")
                : .branch(UITestingPush.branch),
            headCommit: RepositoryHeadCommit(
                objectID: "ui-push-head",
                summary: "Fixture commit"
            ),
            upstream: isUnpublished
                ? nil
                : RepositoryUpstream(
                    name: UITestingPush.upstream,
                    ahead: UITestingPush.aheadCount,
                    behind: 0
                ),
            remotes: UITestingPush.remotes(arguments: arguments),
            localBranches: [UITestingPush.branch],
            remoteBranches: isUnpublished ? [] : [UITestingPush.upstream],
            totalCommitCount: 12,
            gitObjectSize: 4_096,
            configuration: configuration(at: url)
        )
    }
}
#endif
