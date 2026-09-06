////
//  MergeConflictIntegrationTests.swift
//  ColofaGitIntegrationTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// Conflict recovery against the real Git CLI, which is the only thing that can prove the labels
/// come from Git's own refs and that nothing Colofa runs waits on an editor it has no window for.
struct MergeConflictIntegrationTests {
    /// The label a version choice carries comes from Git's own refs rather than from the words in
    /// `MERGE_MSG`, which are a translated sentence rather than data.
    @Test
    func anUnfinishedMergeReportsTheBranchItIsBringingIn() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try MergeIntegrationSupport.divergingRepository(fixture)

        await #expect(throws: (any Error).self) {
            try await MergeIntegrationSupport.backend(fixture).runMutation(
                MergeStrategy.automatic.arguments(merging: MergeIntegrationSupport.source("other")),
                in: repositoryURL
            )
        }

        let snapshot = try await MergeIntegrationSupport.backend(fixture).loadRepository(at: repositoryURL)
        #expect(snapshot.operation == .merge)
        #expect(snapshot.mergeHead?.branch == "other")
        #expect(snapshot.mergeHead?.label == "other")
        #expect(snapshot.unstagedChanges.first?.isConflict == true)
        #expect(snapshot.unstagedChanges.first?.path == "shared.txt")
    }

    /// A local Branch beats a Remote-tracking Branch of the same Commit, whichever way
    /// `for-each-ref` would have sorted the two names.
    @Test
    func alocalBranchIsPreferredToaRemoteTrackingBranchOfTheSameCommit() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try MergeIntegrationSupport.divergingRepository(fixture)
        // Sorted before `other`, so a single listing would have answered with this one.
        try fixture.git(
            ["update-ref", "refs/remotes/origin/aaa", "other"],
            in: repositoryURL
        )

        try await MergeIntegrationSupport.startConflictedMerge(fixture, in: repositoryURL)

        let snapshot = try await MergeIntegrationSupport.backend(fixture)
            .loadRepository(at: repositoryURL)
        #expect(snapshot.mergeHead?.branch == "other")
    }

    /// A Commit no Branch points at is still a real label; it is the Commit itself.
    @Test
    func aMergedCommitNoBranchNamesIsLabelledByItsObjectID() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try MergeIntegrationSupport.divergingRepository(fixture)
        let objectID = try fixture.git(["rev-parse", "--short", "other"], in: repositoryURL)
        try fixture.git(["switch", "--detach", "other"], in: repositoryURL)
        try fixture.git(["switch", "main"], in: repositoryURL)
        try fixture.git(["branch", "--delete", "--force", "other"], in: repositoryURL)

        await #expect(throws: (any Error).self) {
            try await MergeIntegrationSupport.backend(fixture).runMutation(
                MergeStrategy.automatic.arguments(
                    merging: MergeSource(name: objectID, revision: objectID, isRemote: false)
                ),
                in: repositoryURL
            )
        }

        let snapshot = try await MergeIntegrationSupport.backend(fixture).loadRepository(at: repositoryURL)
        #expect(snapshot.mergeHead?.branch == nil)
        #expect(snapshot.mergeHead?.label == objectID)
    }

    /// An ordinary Repository reports no `MERGE_HEAD`, and the read that asks about one is not a
    /// failure when there is none.
    @Test
    func aRepositoryWithNoUnfinishedMergeReportsNoMergeHead() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try MergeIntegrationSupport.fastForwardableRepository(fixture)

        let snapshot = try await MergeIntegrationSupport.backend(fixture).loadRepository(at: repositoryURL)

        #expect(snapshot.operation == nil)
        #expect(snapshot.mergeHead == nil)
    }

    /// Choosing a side writes the working tree and leaves the path unmerged, which is what makes
    /// Mark as Resolved a separate, explicit step rather than a formality.
    @Test(arguments: [(ConflictVersion.current, "main\n"), (.incoming, "other\n")])
    func choosingAversionWritesItWithoutStagingIt(
        version: ConflictVersion,
        expected: String
    ) async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try MergeIntegrationSupport.divergingRepository(fixture)
        try await MergeIntegrationSupport.startConflictedMerge(fixture, in: repositoryURL)

        try await MergeIntegrationSupport.backend(fixture).runMutation(
            version.arguments(for: RepositoryChange(path: "shared.txt", kind: .conflict)),
            in: repositoryURL
        )

        #expect(try MergeIntegrationSupport.contents(of: "shared.txt", in: repositoryURL) == expected)
        let snapshot = try await MergeIntegrationSupport.backend(fixture).loadRepository(at: repositoryURL)
        #expect(snapshot.unstagedChanges.contains { $0.isConflict })
    }

    @Test
    func markAsResolvedStagesThePathAndEndsTheConflict() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try MergeIntegrationSupport.divergingRepository(fixture)
        try await MergeIntegrationSupport.startConflictedMerge(fixture, in: repositoryURL)
        try writeFile("hand merged\n", to: "shared.txt", in: repositoryURL)

        try await MergeIntegrationSupport.backend(fixture).runMutation(
            MergeCommand.markingResolved(["shared.txt"]),
            in: repositoryURL
        )

        let snapshot = try await MergeIntegrationSupport.backend(fixture).loadRepository(at: repositoryURL)
        #expect(!snapshot.unstagedChanges.contains { $0.isConflict })
        // Beside `arriving.txt`, which Git merged on its own before it stopped at the Conflict.
        #expect(snapshot.stagedChanges.map(\.path).contains("shared.txt"))
        // Still unfinished: staging a path resolves it, it does not complete the operation.
        #expect(snapshot.operation == .merge)
    }

    /// Continue must complete the merge without waiting on an editor Colofa has no window for,
    /// and without leaving Git's commented conflict list in the Commit message.
    @Test
    func continueCompletesTheMergeWithoutAnEditor() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try MergeIntegrationSupport.divergingRepository(fixture)
        try await MergeIntegrationSupport.startConflictedMerge(fixture, in: repositoryURL)
        try await MergeIntegrationSupport.backend(fixture).runMutation(
            ConflictVersion.incoming.arguments(
                for: RepositoryChange(path: "shared.txt", kind: .conflict)
            ),
            in: repositoryURL
        )
        try await MergeIntegrationSupport.backend(fixture).runMutation(
            MergeCommand.markingResolved(["shared.txt"]),
            in: repositoryURL
        )

        try await MergeIntegrationSupport.backend(fixture).runMutation(MergeCommand.completing, in: repositoryURL)

        let snapshot = try await MergeIntegrationSupport.backend(fixture).loadRepository(at: repositoryURL)
        #expect(snapshot.operation == nil)
        #expect(snapshot.mergeHead == nil)
        #expect(snapshot.stagedChanges.isEmpty)
        #expect(try MergeIntegrationSupport.parentCount(in: repositoryURL, of: fixture) == 2)
        #expect(
            try fixture.git(["log", "--format=%B", "-1"], in: repositoryURL)
                == "Merge branch 'other'"
        )
    }

    /// Git refuses to complete a merge over an unmerged path, which is the same refusal the
    /// disabled Continue says before the command ever runs.
    @Test
    func continueIsRefusedByGitWhileApathIsStillUnmerged() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try MergeIntegrationSupport.divergingRepository(fixture)
        try await MergeIntegrationSupport.startConflictedMerge(fixture, in: repositoryURL)

        await #expect(throws: (any Error).self) {
            try await MergeIntegrationSupport.backend(fixture).runMutation(MergeCommand.completing, in: repositoryURL)
        }

        let snapshot = try await MergeIntegrationSupport.backend(fixture).loadRepository(at: repositoryURL)
        #expect(snapshot.operation == .merge)
    }

    @Test
    func abortRestoresTheRepositoryToWhatTheMergeStartedFrom() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try MergeIntegrationSupport.divergingRepository(fixture)
        let head = try fixture.git(["rev-parse", "HEAD"], in: repositoryURL)
        try await MergeIntegrationSupport.startConflictedMerge(fixture, in: repositoryURL)

        try await MergeIntegrationSupport.backend(fixture).runMutation(MergeCommand.abort, in: repositoryURL)

        let snapshot = try await MergeIntegrationSupport.backend(fixture).loadRepository(at: repositoryURL)
        #expect(snapshot.operation == nil)
        #expect(snapshot.mergeHead == nil)
        #expect(snapshot.stagedChanges.isEmpty)
        #expect(snapshot.unstagedChanges.isEmpty)
        #expect(try fixture.git(["rev-parse", "HEAD"], in: repositoryURL) == head)
        #expect(try MergeIntegrationSupport.contents(of: "shared.txt", in: repositoryURL) == "main\n")
    }

    /// The Repository already reports unmerged paths before everything else, which is what puts
    /// the only blocking work at the top of Changes.
    @Test
    func conflictedPathsAreReportedFirst() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try MergeIntegrationSupport.divergingRepository(fixture)
        try await MergeIntegrationSupport.startConflictedMerge(fixture, in: repositoryURL)
        try writeFile("scratch\n", to: "aaa-untracked.txt", in: repositoryURL)

        let snapshot = try await MergeIntegrationSupport.backend(fixture).loadRepository(at: repositoryURL)

        #expect(snapshot.unstagedChanges.first?.path == "shared.txt")
        #expect(snapshot.unstagedChanges.first?.isConflict == true)
    }
}
