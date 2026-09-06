////
//  MergeIntegrationTests.swift
//  ColofaGitIntegrationTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// The three merge strategies against the real Git CLI, which is the only thing that can prove
/// each has the exact Git semantics it claims and inherits none of the configuration Colofa
/// deliberately overrules.
struct MergeIntegrationTests {
    // MARK: - Strategies

    /// Default is ordinary Git behaviour: it fast-forwards where it can.
    @Test
    func defaultFastForwardsWhenGitCan() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try MergeIntegrationSupport.fastForwardableRepository(fixture)

        try await MergeIntegrationSupport.backend(fixture).runMutation(
            MergeStrategy.automatic.arguments(merging: MergeIntegrationSupport.source("other")),
            in: repositoryURL
        )

        #expect(try MergeIntegrationSupport.contents(of: "shared.txt", in: repositoryURL) == "other\n")
        #expect(try MergeIntegrationSupport.parentCount(in: repositoryURL, of: fixture) == 1)
    }

    /// …and creates a merge Commit where it cannot.
    @Test
    func defaultCreatesAMergeCommitWhenItCannotFastForward() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try writeFile("base\n", to: "shared.txt", in: repositoryURL)
        try fixture.git(["add", "--", "shared.txt"], in: repositoryURL)
        try fixture.git(["commit", "-m", "Add shared"], in: repositoryURL)
        try fixture.git(["switch", "-c", "other"], in: repositoryURL)
        try writeFile("arriving\n", to: "arriving.txt", in: repositoryURL)
        try fixture.git(["add", "--", "arriving.txt"], in: repositoryURL)
        try fixture.git(["commit", "-m", "Add arriving"], in: repositoryURL)
        try fixture.git(["switch", "main"], in: repositoryURL)
        try writeFile("only on main\n", to: "main.txt", in: repositoryURL)
        try fixture.git(["add", "--", "main.txt"], in: repositoryURL)
        try fixture.git(["commit", "-m", "Add main"], in: repositoryURL)

        try await MergeIntegrationSupport.backend(fixture).runMutation(
            MergeStrategy.automatic.arguments(merging: MergeIntegrationSupport.source("other")),
            in: repositoryURL
        )

        #expect(try MergeIntegrationSupport.parentCount(in: repositoryURL, of: fixture) == 2)
        // Git records the argument it was handed, so a full refname would have left
        // `Merge branch 'refs/heads/other'` in History forever.
        #expect(
            try fixture.git(["log", "--format=%s", "-1"], in: repositoryURL)
                == "Merge branch 'other'"
        )
    }

    /// Default overrules a configured `merge.ff = false`, which would otherwise turn it into
    /// Always Create Merge Commit without the user asking.
    @Test
    func defaultOverrulesAconfiguredMergeFf() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try MergeIntegrationSupport.fastForwardableRepository(fixture)
        try fixture.git(["config", "merge.ff", "false"], in: repositoryURL)

        try await MergeIntegrationSupport.backend(fixture).runMutation(
            MergeStrategy.automatic.arguments(merging: MergeIntegrationSupport.source("other")),
            in: repositoryURL
        )

        #expect(try MergeIntegrationSupport.parentCount(in: repositoryURL, of: fixture) == 1)
    }

    @Test
    func fastForwardOnlyRefusesAdivergenceAndChangesNothing() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try MergeIntegrationSupport.divergingRepository(fixture)
        let head = try fixture.git(["rev-parse", "HEAD"], in: repositoryURL)

        await #expect(throws: (any Error).self) {
            try await MergeIntegrationSupport.backend(fixture).runMutation(
                MergeStrategy.fastForwardOnly.arguments(merging: MergeIntegrationSupport.source("other")),
                in: repositoryURL
            )
        }

        #expect(try fixture.git(["rev-parse", "HEAD"], in: repositoryURL) == head)
        #expect(try MergeIntegrationSupport.contents(of: "shared.txt", in: repositoryURL) == "main\n")
    }

    @Test
    func fastForwardOnlyStillFastForwardsWhenItCan() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try MergeIntegrationSupport.fastForwardableRepository(fixture)

        try await MergeIntegrationSupport.backend(fixture).runMutation(
            MergeStrategy.fastForwardOnly.arguments(merging: MergeIntegrationSupport.source("other")),
            in: repositoryURL
        )

        #expect(try MergeIntegrationSupport.parentCount(in: repositoryURL, of: fixture) == 1)
    }

    @Test
    func alwaysCreateMergeCommitRecordsOneEvenWhereAfastForwardWasPossible() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try MergeIntegrationSupport.fastForwardableRepository(fixture)

        try await MergeIntegrationSupport.backend(fixture).runMutation(
            MergeStrategy.alwaysCreateMergeCommit.arguments(merging: MergeIntegrationSupport.source("other")),
            in: repositoryURL
        )

        #expect(try MergeIntegrationSupport.parentCount(in: repositoryURL, of: fixture) == 2)
    }

    /// `merge.autoStash` would stash the working tree, merge, and re-apply — a Stash nobody asked
    /// for, which can end in a conflicted tree the user never chose.
    @Test
    func noStrategyInheritsAconfiguredAutoStash() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try MergeIntegrationSupport.divergingRepository(fixture)
        try fixture.git(["config", "merge.autoStash", "true"], in: repositoryURL)
        try writeFile("uncommitted\n", to: "local.txt", in: repositoryURL)
        try fixture.git(["add", "--", "local.txt"], in: repositoryURL)

        await #expect(throws: (any Error).self) {
            try await MergeIntegrationSupport.backend(fixture).runMutation(
                MergeStrategy.fastForwardOnly.arguments(merging: MergeIntegrationSupport.source("other")),
                in: repositoryURL
            )
        }

        #expect(try fixture.git(["stash", "list"], in: repositoryURL).isEmpty)
        #expect(try MergeIntegrationSupport.contents(of: "local.txt", in: repositoryURL) == "uncommitted\n")
    }

    // MARK: - The collision Git refuses

    @Test
    func anUntrackedFileInTheWayRefusesTheMergeAndIsNamed() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try MergeIntegrationSupport.fastForwardableRepository(fixture)
        try writeFile("local\n", to: "arriving.txt", in: repositoryURL)

        await #expect(throws: (any Error).self) {
            try await MergeIntegrationSupport.backend(fixture).runMutation(
                MergeStrategy.automatic.arguments(merging: MergeIntegrationSupport.source("other")),
                in: repositoryURL
            )
        }
        #expect(try MergeIntegrationSupport.contents(of: "arriving.txt", in: repositoryURL) == "local\n")

        // The explanation is Git's own name-status walk, not text scraped from its message.
        let comparison = try await MergeIntegrationSupport.backend(fixture).loadCheckoutComparison(
            CheckoutComparisonRequest(
                repositoryURL: repositoryURL,
                revision: "refs/heads/other",
                hasHeadCommit: true
            )
        )
        let snapshot = try await MergeIntegrationSupport.backend(fixture).loadRepository(at: repositoryURL)
        let collision = MergeCollision.evaluate(comparison: comparison, in: snapshot)

        #expect(collision.paths == ["arriving.txt"])
    }
}
