////
//  StashIntegrationTests.swift
//  ColofaGitIntegrationTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// Creating and reading Stashes against the real Git CLI, which is the only thing that can prove
/// each option has the exact Git semantics it claims and that ignored files never travel.
struct StashIntegrationTests {
    private typealias Support = StashIntegrationSupport

    // MARK: - What each option combination saves

    /// The default options save every eligible tracked change and leave a truthful working tree:
    /// what the Stash took is exactly what Git stops reporting.
    @Test
    func theDefaultOptionsSaveTrackedWorkAndLeaveTheTreeClean() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try Support.stashableRepository(fixture)

        try await Support.createStash(fixture, in: repositoryURL)

        #expect(try Support.contents(of: Support.trackedPath, in: repositoryURL) == "base\n")
        #expect(try Support.contents(of: Support.stagedPath, in: repositoryURL) == "base\n")
        let snapshot = try await Support.backend(fixture).loadRepository(at: repositoryURL)
        #expect(snapshot.stagedChanges.isEmpty)
        #expect(snapshot.unstagedChanges.map(\.path) == [Support.untrackedPath])
    }

    /// Keep Staged Changes preserves the index while the Stash still holds everything.
    @Test
    func keepStagedChangesLeavesTheIndexAsItWas() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try Support.stashableRepository(fixture)

        try await Support.createStash(fixture, in: repositoryURL, keepsStagedChanges: true)

        let snapshot = try await Support.backend(fixture).loadRepository(at: repositoryURL)
        #expect(snapshot.stagedChanges.map(\.path) == [Support.stagedPath])
        // The other eligible change is still saved and gone from the working tree.
        #expect(try Support.contents(of: Support.trackedPath, in: repositoryURL) == "base\n")
        #expect(try Support.contents(of: Support.stagedPath, in: repositoryURL) == "index\n")

        let stashes = try await Support.backend(fixture).loadStashes(in: repositoryURL)
        let detail = try await Support.backend(fixture)
            .loadStashDetail(try #require(stashes.first).detailRequest(in: repositoryURL))
        #expect(
            Support.savedPaths(of: detail).sorted() == [Support.stagedPath, Support.trackedPath]
        )
    }

    /// Include Untracked Files adds paths Git was not tracking, and Git records them as a third
    /// parent rather than inside the Stash's own tree.
    @Test
    func includeUntrackedFilesSavesUntrackedPaths() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try Support.stashableRepository(fixture)

        try await Support.createStash(fixture, in: repositoryURL, includesUntrackedFiles: true)

        #expect(!Support.exists(Support.untrackedPath, in: repositoryURL))
        let stashes = try await Support.backend(fixture).loadStashes(in: repositoryURL)
        let stash = try #require(stashes.first)
        #expect(stash.includesUntrackedFiles)

        let detail = try await Support.backend(fixture)
            .loadStashDetail(stash.detailRequest(in: repositoryURL))
        #expect(
            Support.savedPaths(of: detail).sorted()
                == [Support.stagedPath, Support.trackedPath, Support.untrackedPath]
        )
        #expect(detail.files.filter(\.isUntracked).map(\.summary.newPath) == [Support.untrackedPath])
    }

    @Test
    func bothOptionsTogetherKeepTheIndexAndTakeTheUntrackedFile() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try Support.stashableRepository(fixture)

        try await Support.createStash(
            fixture,
            in: repositoryURL,
            keepsStagedChanges: true,
            includesUntrackedFiles: true
        )

        let snapshot = try await Support.backend(fixture).loadRepository(at: repositoryURL)
        #expect(snapshot.stagedChanges.map(\.path) == [Support.stagedPath])
        #expect(snapshot.unstagedChanges.isEmpty)
        #expect(!Support.exists(Support.untrackedPath, in: repositoryURL))
    }

    // MARK: - Ignored files

    /// `--include-untracked` and never `--all`: ignored paths are build output and secrets rather
    /// than work, and no option Colofa offers ever sweeps them in.
    @Test(
        arguments: [
            (false, false), (true, false), (false, true), (true, true),
        ]
    )
    func noOptionCombinationEverSavesAnIgnoredFile(
        keepsStagedChanges: Bool,
        includesUntrackedFiles: Bool
    ) async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try Support.stashableRepository(fixture)

        try await Support.createStash(
            fixture,
            in: repositoryURL,
            keepsStagedChanges: keepsStagedChanges,
            includesUntrackedFiles: includesUntrackedFiles
        )

        #expect(Support.exists(Support.ignoredPath, in: repositoryURL))
        #expect(try Support.contents(of: Support.ignoredPath, in: repositoryURL) == "ignored\n")

        let stashes = try await Support.backend(fixture).loadStashes(in: repositoryURL)
        let stash = try #require(stashes.first)
        let detail = try await Support.backend(fixture)
            .loadStashDetail(stash.detailRequest(in: repositoryURL))
        #expect(!Support.savedPaths(of: detail).contains(Support.ignoredPath))
    }

    // MARK: - Metadata

    /// A message the user gave becomes Git's own description, prefixed the way Git prefixes it.
    @Test
    func aMessageBecomesTheDescriptionGitStores() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try Support.stashableRepository(fixture)

        try await Support.createStash(fixture, in: repositoryURL, message: "parser rewrite")

        let stashes = try await Support.backend(fixture).loadStashes(in: repositoryURL)
        let stash = try #require(stashes.first)
        #expect(stash.message == "On main: parser rewrite")
        #expect(stash.selector == "stash@{0}")
        #expect(stash.authorName == "Colofa Tests")
        #expect(stash.authorEmail == "colofa-tests@example.invalid")
        #expect(!stash.objectID.isEmpty)
        #expect(stash.objectID.hasPrefix(stash.abbreviatedObjectID))
        // The Stash is compared against the Commit that was checked out when it was saved.
        #expect(stash.baseObjectID == (try fixture.git(["rev-parse", "HEAD"], in: repositoryURL)))
    }

    /// No message is not an empty description: Git writes its own `WIP on <branch>:` line.
    @Test
    func noMessageStillCarriesGitsOwnDescription() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try Support.stashableRepository(fixture)

        try await Support.createStash(fixture, in: repositoryURL)

        let stashes = try await Support.backend(fixture).loadStashes(in: repositoryURL)
        let stash = try #require(stashes.first)
        #expect(stash.message.hasPrefix("WIP on main:"))
    }

    /// Every entry is listed, newest first, at the address Git holds it at.
    @Test
    func everyEntryIsListedNewestFirst() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try Support.stashableRepository(fixture)

        try await Support.createStash(fixture, in: repositoryURL, message: "first")
        try writeFile("second\n", to: Support.trackedPath, in: repositoryURL)
        try await Support.createStash(fixture, in: repositoryURL, message: "second")

        let stashes = try await Support.backend(fixture).loadStashes(in: repositoryURL)
        #expect(stashes.map(\.selector) == ["stash@{0}", "stash@{1}"])
        #expect(stashes.map(\.message) == ["On main: second", "On main: first"])
    }

    @Test
    func aRepositoryWithNoStashesReportsAnEmptyList() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try Support.stashableRepository(fixture)

        #expect(try await Support.backend(fixture).loadStashes(in: repositoryURL).isEmpty)
    }

    // MARK: - The Diff

    /// A tracked path's patch is the change the Stash saved, compared against the Commit it was
    /// saved on.
    @Test
    func aTrackedPathReadsAsTheChangeTheStashSaved() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try Support.stashableRepository(fixture)
        try await Support.createStash(fixture, in: repositoryURL)

        let backend = Support.backend(fixture)
        let stash = try #require(try await backend.loadStashes(in: repositoryURL).first)
        let detail = try await backend.loadStashDetail(stash.detailRequest(in: repositoryURL))
        let file = try #require(
            detail.files.first { $0.summary.newPath == Support.trackedPath }
        )

        let result = try await backend.loadDiff(
            DiffLoadRequest(
                source: try #require(stash.diffSource(of: file)),
                repositoryURL: repositoryURL
            )
        )
        guard case .diff(let diff) = result else {
            Issue.record("Expected the patch to be rendered")
            return
        }
        #expect(diff.files.map(\.newPath) == [Support.trackedPath])
        #expect(diff.stats == DiffStats(additions: 1, deletions: 1))
    }

    /// An untracked file lives in a Commit with no parent, so it reads as everything that Commit
    /// introduced — an addition, which is what it was.
    @Test
    func anUntrackedPathReadsAsAnAddition() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try Support.stashableRepository(fixture)
        try await Support.createStash(fixture, in: repositoryURL, includesUntrackedFiles: true)

        let backend = Support.backend(fixture)
        let stash = try #require(try await backend.loadStashes(in: repositoryURL).first)
        let detail = try await backend.loadStashDetail(stash.detailRequest(in: repositoryURL))
        let file = try #require(detail.files.first { $0.isUntracked })

        let result = try await backend.loadDiff(
            DiffLoadRequest(
                source: try #require(stash.diffSource(of: file)),
                repositoryURL: repositoryURL
            )
        )
        guard case .diff(let diff) = result else {
            Issue.record("Expected the patch to be rendered")
            return
        }
        #expect(diff.files.map(\.newPath) == [Support.untrackedPath])
        #expect(diff.stats == DiffStats(additions: 1, deletions: 0))
    }

    // MARK: - What Git refuses

    /// An Unborn Branch has no Commit for a Stash to be saved against, which is exactly what
    /// `StashCreationUnavailabilityReason` refuses before the command runs.
    @Test
    func gitRefusesAStashOnAnUnbornBranch() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try writeFile("staged\n", to: "new.txt", in: repositoryURL)
        try fixture.git(["add", "--", "new.txt"], in: repositoryURL)

        await #expect(throws: (any Error).self) {
            try await Support.createStash(fixture, in: repositoryURL)
        }
    }

    /// Git refuses to save an index holding unmerged paths, which is why a Conflict is refused
    /// before the command runs.
    @Test
    func gitRefusesAStashWhileAPathIsUnmerged() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try MergeIntegrationSupport.divergingRepository(fixture)
        try await MergeIntegrationSupport.startConflictedMerge(fixture, in: repositoryURL)

        await #expect(throws: (any Error).self) {
            try await Support.createStash(fixture, in: repositoryURL)
        }
    }

    /// A clean tree makes `git stash push` succeed while creating nothing, which is why the
    /// state is refused in the app rather than reported as a Stash that does not exist.
    @Test
    func gitCreatesNothingForACleanRepository() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try fixture.createCommit(in: repositoryURL)

        try await Support.createStash(fixture, in: repositoryURL)

        #expect(try await Support.backend(fixture).loadStashes(in: repositoryURL).isEmpty)
    }

    /// The same is true when the only work is untracked and the option is off, which is the
    /// refusal the sheet names Include Untracked Files for.
    @Test
    func gitCreatesNothingWhenTheOnlyWorkIsUntrackedAndUnasked() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try fixture.createCommit(in: repositoryURL)
        try writeFile("untracked\n", to: Support.untrackedPath, in: repositoryURL)

        try await Support.createStash(fixture, in: repositoryURL)

        #expect(try await Support.backend(fixture).loadStashes(in: repositoryURL).isEmpty)
        #expect(Support.exists(Support.untrackedPath, in: repositoryURL))
    }
}
