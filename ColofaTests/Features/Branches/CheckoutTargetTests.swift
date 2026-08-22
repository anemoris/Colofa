////
//  CheckoutTargetTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

struct CheckoutTargetTests {
    private static let repositoryURL = URL(filePath: "/tmp/colofa-branch-tests")

    private static func snapshot(
        localBranches: [String] = ["main"],
        remoteBranches: [String] = ["origin/feature", "origin/main"],
        remotes: [String] = ["origin"]
    ) -> RepositorySnapshot {
        repository(
            at: repositoryURL,
            head: .branch("main"),
            remotes: remotes.map {
                RepositoryRemote(name: $0, url: "ssh://example.invalid/x.git")
            },
            localBranches: localBranches,
            remoteBranches: remoteBranches,
            tags: ["v1.0"]
        )
    }

    /// HEAD is already checked out, so it offers no Checkout at all.
    @Test
    func offersNoCheckoutForHead() {
        #expect(CheckoutTarget.resolve(.head, in: Self.snapshot()) == nil)
    }

    @Test
    func switchesToALocalBranch() throws {
        let target = try #require(
            CheckoutTarget.resolve(
                .localBranch("feature"),
                in: Self.snapshot(localBranches: ["feature", "main"])
            )
        )

        #expect(target.arguments == ["switch", "--no-guess", "--", "feature"])
        #expect(target.revision == "refs/heads/feature")
        #expect(target.localBranchName == "feature")
        #expect(!target.detachesHead)
    }

    /// A remote branch becomes a same-name local tracking branch, so later Pull and Push have an
    /// upstream.
    @Test
    func createsASameNameTrackingBranchForARemoteBranch() throws {
        let target = try #require(
            CheckoutTarget.resolve(.remoteBranch("origin/feature"), in: Self.snapshot())
        )

        #expect(
            target.arguments == [
                "switch", "--track", "--create", "feature", "refs/remotes/origin/feature",
            ]
        )
        #expect(target.localBranchName == "feature")
        #expect(target.displayName == "origin/feature")
    }

    /// Recreating an existing local branch from the remote would move it back and drop whatever
    /// it holds that the remote does not, so Checkout switches to the branch that is already here.
    @Test
    func switchesToAnExistingLocalBranchRatherThanRecreatingIt() throws {
        let target = try #require(
            CheckoutTarget.resolve(
                .remoteBranch("origin/feature"),
                in: Self.snapshot(localBranches: ["feature", "main"])
            )
        )

        #expect(target.arguments == ["switch", "--no-guess", "--", "feature"])
        #expect(!target.arguments.contains("--create"))
    }

    @Test
    func detachesHeadForATag() throws {
        let target = try #require(CheckoutTarget.resolve(.tag("v1.0"), in: Self.snapshot()))

        #expect(target.arguments == ["switch", "--detach", "refs/tags/v1.0"])
        #expect(target.detachesHead)
        #expect(target.localBranchName == nil)
    }

    /// No Checkout Colofa builds may carry a way to overwrite local work.
    @Test(
        arguments: [
            GitReference.localBranch("feature"),
            .remoteBranch("origin/feature"),
            .tag("v1.0"),
        ]
    )
    func neverForcesMergesOrStashes(_ reference: GitReference) throws {
        let target = try #require(CheckoutTarget.resolve(reference, in: Self.snapshot()))
        let refused = ["--force", "-f", "--merge", "-m", "--discard-changes", "stash"]

        #expect(!target.arguments.contains(where: refused.contains))
    }

    /// A remote may be named with a slash in it, so the configured remotes decide where the
    /// branch name starts rather than the first slash does.
    @Test(
        arguments: [
            ("origin/feature", ["origin"], "feature"),
            ("origin/feature/work", ["origin"], "feature/work"),
            ("team/upstream/feature", ["team/upstream", "team"], "feature"),
            ("unknown/feature", [], "feature"),
            ("solo", [], "solo"),
        ]
    )
    func namesTheTrackingBranchWithoutItsRemote(
        _ remoteBranch: String,
        _ remotes: [String],
        _ expected: String
    ) {
        #expect(
            CheckoutTarget.trackingBranchName(for: remoteBranch, remotes: remotes) == expected
        )
    }
}
