////
//  UITestingPush.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

#if DEBUG
import Foundation

/// What the stubbed backend answers about Publish and Push, so a UI test can drive a Branch that
/// publishes, one whose remote has to be chosen, one whose Push the remote refuses, and a Force
/// Push with Lease the remote moved out from under.
///
/// Declared `nonisolated` because the project defaults to Main Actor isolation while
/// `UITestingRepositoryService` reads these from an actor.
nonisolated enum UITestingPush {
    static let branch = "main"
    static let primaryRemote = "origin"
    static let secondaryRemote = "mirror"

    /// How far ahead the fixture's Branch starts, which is what one Push is meant to close.
    static let aheadCount = 2

    /// What the fixture's remote-tracking Ref points at, which is the object a Force Push with
    /// Lease requires the remote to still hold.
    static let expectedObjectID = "0123456789abcdef0123456789abcdef01234567"

    /// The upstream the fixture's Branch has, when it has one.
    static let upstream = "\(primaryRemote)/\(branch)"

    /// The address a remote resolves to, which the fixture answers the same way wherever it is
    /// asked: a remote whose listed URL and whose push destination disagreed would be a fixture
    /// describing a Repository Git could not produce.
    static func url(of remote: String) -> String {
        remote == secondaryRemote
            ? "ssh://example.invalid/Mirror.git"
            : "ssh://example.invalid/Colofa.git"
    }

    static func remotes(arguments: [String]) -> [RepositoryRemote] {
        let origin = RepositoryRemote(name: primaryRemote, url: url(of: primaryRemote))
        guard arguments.contains(UITestingArgument.pushManyRemotes) else {
            return [origin]
        }
        return [
            origin,
            RepositoryRemote(name: secondaryRemote, url: url(of: secondaryRemote)),
        ]
    }

    /// Whether the fixture's Branch has been pushed anywhere yet.
    static func isUnpublished(arguments: [String]) -> Bool {
        arguments.contains(UITestingArgument.pushNoUpstream)
    }

    /// What Git's own configuration answers about where this Branch is published.
    static func publishRemote(arguments: [String]) -> String? {
        arguments.contains(UITestingArgument.pushConfiguredRemote) ? secondaryRemote : nil
    }

    /// Where a Push goes, or `nil` for the Branch nobody has pushed yet.
    ///
    /// The expected object is absent when the fixture is asked for a Branch whose upstream has
    /// never been fetched, which is the state that leaves no lease to take.
    static func target(arguments: [String]) -> PushTarget? {
        guard !isUnpublished(arguments: arguments) else {
            return nil
        }
        return PushTarget(
            remote: primaryRemote,
            remoteRef: "refs/heads/\(branch)",
            upstream: upstream,
            trackingRef: "refs/remotes/\(upstream)",
            expectedObjectID: arguments.contains(UITestingArgument.pushWithoutLease)
                ? nil
                : expectedObjectID
        )
    }

    /// The one address a Push to `remote` would write to, or the refusal a configuration Colofa
    /// cannot confirm produces.
    static func destination(of remote: String, arguments: [String]) throws -> PushDestination {
        if arguments.contains(UITestingArgument.pushLocalDestination) {
            throw PushDestinationRefusal.localRepository(remote: remote)
        }
        if arguments.contains(UITestingArgument.pushSeveralDestinations) {
            throw PushDestinationRefusal.severalDestinations(
                remote: remote,
                [
                    PushDestination(url(of: primaryRemote)),
                    PushDestination(url(of: secondaryRemote)),
                ]
            )
        }
        return PushDestination(url(of: remote))
    }

    /// The upstream one accepted Publish or Push leaves behind, which is one nothing separates.
    static func settledUpstream(_ command: [String]) -> RepositoryUpstream {
        RepositoryUpstream(name: publishedUpstream(command), ahead: 0, behind: 0)
    }

    /// The remote-tracking Ref an accepted Publish creates.
    ///
    /// Read out of the command rather than back out of the launch arguments, so the fixture
    /// reports where the Push actually went rather than where it was expected to go.
    static func publishedUpstream(_ command: [String]) -> String {
        guard isPublish(command) else {
            return upstream
        }
        return "\(remoteName(of: command) ?? primaryRemote)/\(branch)"
    }

    static func isPush(_ command: [String]) -> Bool {
        command.first == "push"
    }

    static func isPublish(_ command: [String]) -> Bool {
        command.contains("--set-upstream")
    }

    static func isForced(_ command: [String]) -> Bool {
        command.contains { $0.hasPrefix("--force-with-lease=") }
    }

    /// The remote these arguments contact, which is the first thing after the `--` that keeps a
    /// remote name out of Git's option parser.
    static func remoteName(of command: [String]) -> String? {
        guard let separator = command.firstIndex(of: "--") else {
            return nil
        }
        let name = command.index(after: separator)
        return name < command.endIndex ? command[name] : nil
    }

    /// Whether the fixture's remote refuses this command, reported the way `git push --porcelain`
    /// reports a refusal.
    static func failure(of command: [String], arguments: [String]) -> RepositoryOpenError? {
        if arguments.contains(UITestingArgument.pushStaleLease), isForced(command) {
            return refusal("(stale info)")
        }
        guard arguments.contains(UITestingArgument.pushRejected), !isForced(command) else {
            return nil
        }
        return refusal("(fetch first)")
    }

    private static func refusal(_ reason: String) -> RepositoryOpenError {
        .commandFailed(
            GitFailureDetails(
                command: "git push",
                output: """
                    error: failed to push some refs to 'ssh://example.invalid/Colofa.git'
                    To ssh://example.invalid/Colofa.git
                    !\trefs/heads/\(branch):refs/heads/\(branch)\t[rejected] \(reason)
                    Done
                    """,
                exitStatus: 1
            )
        )
    }
}
#endif
