////
//  PushCommandTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// What Colofa actually asks Git when a Branch is published or pushed.
///
/// These read the command rather than the Store, because the argument list is the whole safety
/// boundary: what it does not contain is as much of the answer as what it does.
struct PushCommandTests {
    private let target = PushTarget(
        remote: "origin",
        remoteRef: "refs/heads/main",
        upstream: "origin/main",
        trackingRef: "refs/remotes/origin/main",
        expectedObjectID: "cafebabe"
    )

    // MARK: - Where a remote points

    /// The address question asks what a Push asks: the push URL, not the fetch URL, and every one
    /// of them rather than the first.
    @Test
    func thedestinationQueryAsksForEveryPushAddress() {
        #expect(
            PushCommand.destinationQuery(for: "origin")
                == ["remote", "get-url", "--push", "--all", "--", "origin"]
        )
    }

    /// A remote name is a name, and `--` is what keeps one that begins with a dash out of Git's
    /// option parser.
    @Test
    func aremoteNamedLikeAnoptionIsStillAname() {
        #expect(PushCommand.destinationQuery(for: "--upload-pack").last == "--upload-pack")
    }

    // MARK: - Publish

    /// A first Publish creates the Branch on the remote and records it as the upstream, naming
    /// both ends of the refspec so `push.default` cannot decide either for itself.
    @Test
    func publishNamesTheBranchOnBothSidesAndRecordsTheUpstream() {
        let command = PushCommand.publish("feature/真实", to: "origin")

        #expect(
            command == [
                "push", "--porcelain", "--no-follow-tags", "--recurse-submodules=no",
                "--set-upstream", "--", "origin",
                "refs/heads/feature/真实:refs/heads/feature/真实",
            ]
        )
    }

    // MARK: - Push

    /// A Push goes exactly where the confirmation said, which is the Ref Git itself reported
    /// rather than one assembled from a remote name and a Branch name.
    @Test
    func pushSendsTheBranchToTheExactUpstreamRef() {
        let command = PushCommand.push("main", to: target, lease: nil)

        #expect(
            command == [
                "push", "--porcelain", "--no-follow-tags", "--recurse-submodules=no",
                "--", "origin", "refs/heads/main:refs/heads/main",
            ]
        )
    }

    /// A remote whose Ref is named differently from the local Branch is still pushed to its own
    /// Ref, because that is the upstream the user confirmed.
    @Test
    func pushHonoursAnUpstreamNamedDifferentlyFromTheBranch() {
        let renamed = PushTarget(
            remote: "upstream",
            remoteRef: "refs/heads/release",
            upstream: "upstream/release",
            trackingRef: "refs/remotes/upstream/release"
        )

        let command = PushCommand.push("main", to: renamed, lease: nil)

        #expect(command.last == "refs/heads/main:refs/heads/release")
        #expect(command.contains("upstream"))
    }

    // MARK: - Force

    /// The lease names the Ref on the remote and the exact object it must still hold.
    @Test
    func forcePushCarriesTheLeaseAgainstTheExactExpectedObject() {
        let command = PushCommand.push("main", to: target, lease: "cafebabe")

        #expect(command.contains("--force-with-lease=refs/heads/main:cafebabe"))
        #expect(command.first == "push")
    }

    /// Every command this file can produce, checked against every spelling of a naked force there
    /// is: the bare options, and the `+` a refspec uses to mean the same thing.
    @Test(
        arguments: [
            PushCommand.publish("main", to: "origin"),
            PushCommand.push(
                "main",
                to: PushTarget(
                    remote: "origin",
                    remoteRef: "refs/heads/main",
                    upstream: "origin/main",
                    trackingRef: "refs/remotes/origin/main",
                    expectedObjectID: "cafebabe"
                ),
                lease: nil
            ),
            PushCommand.push(
                "main",
                to: PushTarget(
                    remote: "origin",
                    remoteRef: "refs/heads/main",
                    upstream: "origin/main",
                    trackingRef: "refs/remotes/origin/main",
                    expectedObjectID: "cafebabe"
                ),
                lease: "cafebabe"
            ),
        ]
    )
    func noCommandCanEverSpellAnakedForce(_ command: [String]) {
        #expect(!command.contains("--force"))
        #expect(!command.contains("-f"))
        #expect(!command.contains("--force-with-lease"), "A lease with no value is a naked force")
        #expect(!command.contains("--force-if-includes"))
        #expect(command.last?.hasPrefix("+") == false, "The refspec asked for a force of its own")
    }

    /// Colofa never creates or pushes a tag, so a Repository configured to send them with every
    /// Push is overruled rather than inherited.
    @Test(
        arguments: [
            PushCommand.publish("main", to: "origin"),
            PushCommand.push(
                "main",
                to: PushTarget(
                    remote: "origin",
                    remoteRef: "refs/heads/main",
                    upstream: "origin/main",
                    trackingRef: "refs/remotes/origin/main"
                ),
                lease: nil
            ),
        ]
    )
    func noPushEverCarriesAtag(_ command: [String]) {
        #expect(command.contains("--no-follow-tags"))
        #expect(!command.contains { $0.contains("refs/tags/") })
    }

    /// A Push writes to the one remote the confirmation showed. A Repository configured to send
    /// its submodules along would make that two remotes, so the configuration is overruled rather
    /// than inherited — the same rule that keeps a tag from travelling, one level down.
    @Test(
        arguments: [
            PushCommand.publish("main", to: "origin"),
            PushCommand.push(
                "main",
                to: PushTarget(
                    remote: "origin",
                    remoteRef: "refs/heads/main",
                    upstream: "origin/main",
                    trackingRef: "refs/remotes/origin/main"
                ),
                lease: nil
            ),
        ]
    )
    func noPushEverWritesToAsubmodulesOwnRemote(_ command: [String]) {
        #expect(command.contains("--recurse-submodules=no"))
    }

    // MARK: - The reads

    /// The order Git overrules these in, which is the order Publish asks them in.
    @Test
    func theRemoteKeysAreAskedInGitsOwnPrecedenceOrder() {
        #expect(
            PushCommand.remoteKeys(for: "feature/x") == [
                "branch.feature/x.pushRemote",
                "remote.pushDefault",
                "branch.feature/x.remote",
            ]
        )
    }

    @Test
    func theRemoteQueryReadsOneKeyAsAnUldelimitedValue() {
        #expect(
            PushCommand.remoteQuery("remote.pushDefault")
                == ["config", "--null", "--get", "remote.pushDefault"]
        )
    }

    /// The upstream read asks for the Branch's own Ref and reports all four things a Push needs.
    @Test
    func theUpstreamQueryAsksAboutTheBranchesOwnRef() throws {
        let command = PushCommand.upstreamQuery(for: "main")

        #expect(command.first == "for-each-ref")
        #expect(command.last == "refs/heads/main")
        let format = try #require(command.first { $0.hasPrefix("--format=") })
        let fields = [
            "%(refname)", "%(upstream:remotename)", "%(upstream:remoteref)",
            "%(upstream:short)", "%(upstream)",
        ]
        for field in fields {
            #expect(format.contains(field), "The read never asks for \(field)")
        }
    }

    /// `rev-parse` reads everything after a `--` as a path, so the Ref travels without one.
    @Test
    func theObjectIdQueryReadsArefWithoutApathSeparator() {
        let command = PushCommand.objectIDQuery(of: "refs/remotes/origin/main")

        #expect(command == ["rev-parse", "--verify", "--quiet", "refs/remotes/origin/main"])
        #expect(!command.contains("--"))
    }
}
