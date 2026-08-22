////
//  UITestingFetch.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

#if DEBUG
import Foundation

/// What the stubbed backend answers about Fetch, so a UI test can drive a Fetch that succeeds,
/// one that fails on its second remote, one slow enough to be cancelled, and a Fetch Tags Git
/// refuses.
///
/// Declared `nonisolated` because the project defaults to Main Actor isolation while
/// `UITestingRepositoryService` reads these from an actor.
nonisolated enum UITestingFetch {
    static let primaryRemote = "origin"
    static let secondaryRemote = "mirror"

    /// The remote branch a successful Fetch brings in, so the sidebar visibly gains something.
    static let fetchedRemoteBranch = "origin/新分支"

    /// The tag a successful Fetch Tags brings in.
    static let fetchedTag = "v2.0-新"

    /// The tag both sides hold at different objects, which Git refuses to replace.
    static let conflictingTag = "v1.0-测试"

    /// How long a slow Fetch blocks, which is long enough for a UI test to press Cancel and
    /// short enough that a test that never presses it still ends.
    static let slowFetchDuration = Duration.seconds(30)

    static func remotes(arguments: [String]) -> [RepositoryRemote] {
        let origin = RepositoryRemote(
            name: primaryRemote,
            url: "ssh://example.invalid/Colofa.git"
        )
        guard !arguments.contains(UITestingArgument.singleRemote) else {
            return [origin]
        }
        return [
            origin,
            RepositoryRemote(name: secondaryRemote, url: "ssh://example.invalid/Mirror.git"),
        ]
    }

    static func skippedRemotes(arguments: [String]) -> Set<String> {
        arguments.contains(UITestingArgument.skipFetchAll) ? [secondaryRemote] : []
    }

    static func tagConflicts(arguments: [String]) -> TagFetchConflict {
        arguments.contains(UITestingArgument.tagConflict)
            ? TagFetchConflict(tags: [conflictingTag])
            : .empty
    }

    /// Whether this command is the one the fixture refuses.
    static func failure(of command: [String], arguments: [String]) -> RepositoryOpenError? {
        if arguments.contains(UITestingArgument.tagConflict), FetchCommand.isTagFetch(command) {
            return .commandFailed(
                GitFailureDetails(
                    command: "git fetch",
                    output: "! [rejected] \(conflictingTag) (would clobber existing tag)",
                    exitStatus: 1
                )
            )
        }
        guard arguments.contains(UITestingArgument.fetchFailure),
              FetchCommand.remote(of: command) == secondaryRemote else {
            return nil
        }
        return .commandFailed(
            GitFailureDetails(
                command: "git fetch",
                output: "fatal: could not read from remote repository",
                exitStatus: 128
            )
        )
    }
}
#endif
