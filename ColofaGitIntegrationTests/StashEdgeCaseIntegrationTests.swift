////
//  StashEdgeCaseIntegrationTests.swift
//  ColofaGitIntegrationTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// The Repository shapes in which Git's own Stash behaviour is not what the ordinary case
/// suggests, each proved against the real Git CLI because only Git can say what it does.
struct StashEdgeCaseIntegrationTests {
    private typealias Support = StashIntegrationSupport

    // MARK: - One path on both sides

    /// A file removed from the index with `git rm --cached` and then edited is saved twice: once
    /// as the tracked change and once as an untracked file. Each is its own row, and the
    /// untracked one reads from the untracked Commit rather than from the first row with its path.
    @Test
    func aPathSavedOnBothSidesIsTwoRowsWithTheirOwnDiffs() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try Support.stashableRepository(fixture)
        try fixture.git(["rm", "--cached", "--quiet", "--", Support.trackedPath], in: repositoryURL)
        try writeFile("edited after removal\n", to: Support.trackedPath, in: repositoryURL)
        try await Support.createStash(fixture, in: repositoryURL, includesUntrackedFiles: true)

        let backend = Support.backend(fixture)
        let stash = try #require(try await backend.loadStashes(in: repositoryURL).first)
        let detail = try await backend.loadStashDetail(stash.detailRequest(in: repositoryURL))
        let rows = detail.files.filter { $0.summary.newPath == Support.trackedPath }
        #expect(rows.map(\.isUntracked) == [false, true])
        #expect(Set(detail.files.map(\.id)).count == detail.files.count)

        let untracked = try #require(rows.last)
        #expect(detail.file(untracked.id) == untracked)
        let result = try await backend.loadDiff(
            DiffLoadRequest(
                source: try #require(stash.diffSource(of: untracked)),
                repositoryURL: repositoryURL
            )
        )
        guard case .diff(let diff) = result else {
            Issue.record("Expected the patch to be rendered")
            return
        }
        #expect(diff.files.map(\.newPath) == [Support.trackedPath])
        #expect(diff.stats == DiffStats(additions: 1, deletions: 0))
    }

    // MARK: - Submodules

    /// Each shape a submodule's change can take. Git decides whether there is anything to save
    /// while ignoring submodules, so every one of them alone makes `git stash push` exit
    /// successfully having saved nothing.
    enum SubmoduleChange: CaseIterable, Sendable {
        case dirtyWorkingTree
        case untrackedFileInside
        case movedCommit
        case stagedMove
    }

    @Test(arguments: SubmoduleChange.allCases)
    func aSubmoduleChangeAloneIsRefusedBecauseGitWouldSaveNothing(
        change: SubmoduleChange
    ) async throws {
        let fixture = try GitTestRepository()
        let project = try superproject(fixture)
        try apply(change, to: project, of: fixture)

        let backend = Support.backend(fixture)
        let snapshot = try await backend.loadRepository(at: project.repositoryURL)
        #expect(
            StashCreationUnavailabilityReason.evaluate(
                repository: snapshot,
                includesUntrackedFiles: true,
                isMutating: false
            ) == .submoduleChangesOnly
        )

        // What the refusal stands in for: Git runs, succeeds, and creates nothing.
        try await Support.createStash(fixture, in: project.repositoryURL, includesUntrackedFiles: true)
        #expect(try await backend.loadStashes(in: project.repositoryURL).isEmpty)
    }

    /// Beside other work the Stash runs, and the submodule does not get in its way.
    @Test
    func aSubmoduleChangeBesideTrackedWorkIsSaved() async throws {
        let fixture = try GitTestRepository()
        let project = try superproject(fixture)
        try apply(.dirtyWorkingTree, to: project, of: fixture)
        try writeFile("changed\n", to: "README.md", in: project.repositoryURL)

        let backend = Support.backend(fixture)
        let snapshot = try await backend.loadRepository(at: project.repositoryURL)
        #expect(
            StashCreationUnavailabilityReason.evaluate(
                repository: snapshot,
                includesUntrackedFiles: false,
                isMutating: false
            ) == nil
        )

        try await Support.createStash(fixture, in: project.repositoryURL)
        #expect(try await backend.loadStashes(in: project.repositoryURL).count == 1)
    }

    private struct Superproject {
        let repositoryURL: URL
        let submoduleURL: URL
    }

    private func superproject(_ fixture: GitTestRepository) throws -> Superproject {
        let sourceURL = try fixture.createWorkingRepository(named: "module-source")
        try fixture.createCommit(in: sourceURL)
        let repositoryURL = try fixture.createWorkingRepository()
        try fixture.createCommit(in: repositoryURL)
        let submoduleURL = try fixture.addSubmodule(sourceURL, named: "vendor", to: repositoryURL)
        try fixture.git(["commit", "-m", "Add submodule"], in: repositoryURL)
        return Superproject(repositoryURL: repositoryURL, submoduleURL: submoduleURL)
    }

    private func apply(
        _ change: SubmoduleChange,
        to project: Superproject,
        of fixture: GitTestRepository
    ) throws {
        switch change {
        case .dirtyWorkingTree:
            try writeFile("dirty\n", to: "README.md", in: project.submoduleURL)
        case .untrackedFileInside:
            try writeFile("new\n", to: "new.txt", in: project.submoduleURL)
        case .movedCommit:
            try commitFile("moved\n", to: "moved.txt", in: project.submoduleURL, of: fixture)
        case .stagedMove:
            try commitFile("moved\n", to: "moved.txt", in: project.submoduleURL, of: fixture)
            try fixture.git(["add", "--", "vendor"], in: project.repositoryURL)
        }
    }

    // MARK: - Descriptions

    /// Git keeps a `0x1e` a message carried in the description it stores, so the list must be
    /// read without relying on any printable byte to separate entries.
    @Test
    func aDescriptionHoldingTheASCIIRecordSeparatorIsStillOneEntry() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try Support.stashableRepository(fixture)

        try await Support.createStash(fixture, in: repositoryURL, message: "first")
        try writeFile("second\n", to: Support.trackedPath, in: repositoryURL)
        try await Support.createStash(
            fixture,
            in: repositoryURL,
            message: "subject\u{1e}separator"
        )

        let stashes = try await Support.backend(fixture).loadStashes(in: repositoryURL)
        #expect(stashes.map(\.selector) == ["stash@{0}", "stash@{1}"])
        #expect(stashes.map(\.message) == ["On main: subject\u{1e}separator", "On main: first"])
    }
}
