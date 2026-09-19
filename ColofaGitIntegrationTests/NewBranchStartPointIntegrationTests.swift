////
//  NewBranchStartPointIntegrationTests.swift
//  ColofaGitIntegrationTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation
import Testing
@testable import Colofa

/// New Branch creates the Branch at the Commit its dialog showed, even when something outside
/// Colofa moves HEAD while the dialog is open. Only real Git can move HEAD under an open dialog.
struct NewBranchStartPointIntegrationTests {
    /// A Commit made in another terminal moves the Branch HEAD names, so a start point that
    /// still said `HEAD` would follow it there.
    @Test
    @MainActor
    func createsTheBranchAtTheCommitShownWhenHeadMovesUnderTheDialog() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try fixture.git(["commit", "--allow-empty", "-m", "Shown in the dialog"], in: repositoryURL)
        let shown = try fixture.git(["rev-parse", "HEAD"], in: repositoryURL)
        let state = await openedWorkspace(fixture, at: repositoryURL)

        state.beginCreatingBranch()
        #expect(state.branchCreation?.startPoint.summary == "Shown in the dialog")
        try fixture.git(["commit", "--allow-empty", "-m", "Made while open"], in: repositoryURL)
        try await create("feature", in: state)

        #expect(state.branchCreation == nil)
        #expect(try fixture.git(["rev-parse", "refs/heads/feature"], in: repositoryURL) == shown)
    }

    /// A Detached HEAD moved elsewhere leaves the Commit the dialog abbreviated behind.
    @Test
    @MainActor
    func createsTheBranchAtTheDetachedCommitShownWhenHeadMovesUnderTheDialog() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        let shown = try fixture.createCommit(in: repositoryURL, named: "first.txt")
        try fixture.createCommit(in: repositoryURL, named: "second.txt")
        try fixture.git(["switch", "--detach", shown], in: repositoryURL)
        let state = await openedWorkspace(fixture, at: repositoryURL)

        state.beginCreatingBranch()
        #expect(state.branchCreation?.startPoint.label == String(shown.prefix(12)))
        try fixture.git(["switch", "main"], in: repositoryURL)
        try await create("recovery", in: state)

        #expect(state.branchCreation == nil)
        #expect(try fixture.git(["rev-parse", "refs/heads/recovery"], in: repositoryURL) == shown)
    }

    /// A message Colofa cannot decode leaves HEAD without a Summary to show, which is no reason
    /// to stop naming the Commit a Branch starts at.
    @Test
    @MainActor
    func startsAtTheCommitWhoseMessageColofaCannotDecode() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        let shown = try writeLatin1Commit(in: repositoryURL, of: fixture)
        let state = await openedWorkspace(fixture, at: repositoryURL)
        try #require(state.repository?.headCommit == nil)

        #expect(state.canBeginCreatingBranch)
        state.beginCreatingBranch()
        #expect(state.branchCreation?.startPoint.label == "main")
        #expect(state.branchCreation?.startPoint.summary == "")
        try fixture.git(["commit", "--allow-empty", "-m", "Made while open"], in: repositoryURL)
        try await create("feature", in: state)

        #expect(try fixture.git(["rev-parse", "refs/heads/feature"], in: repositoryURL) == shown)
    }

    /// Points `main` at a Commit whose message is “café” in Latin-1 with no encoding header, as
    /// an imported history can hold. `git commit` would repair those bytes into UTF-8, so the
    /// object is written directly.
    private func writeLatin1Commit(
        in repositoryURL: URL,
        of fixture: GitTestRepository
    ) throws -> String {
        let tree = try fixture.git(["write-tree"], in: repositoryURL)
        let signature = "Colofa Tests <colofa-tests@example.invalid> 0 +0000"
        var object = Data("tree \(tree)\nauthor \(signature)\ncommitter \(signature)\n\n".utf8)
        object.append(contentsOf: [0x63, 0x61, 0x66, 0xE9, 0x0A])
        let objectURL = fixture.rootURL.appending(path: "latin1-commit")
        try object.write(to: objectURL)
        let commit = try fixture.git(
            ["hash-object", "-t", "commit", "-w", "--", objectURL.normalizedFilePath],
            in: repositoryURL
        )
        try fixture.git(["update-ref", "refs/heads/main", commit], in: repositoryURL)
        return commit
    }

    /// Creates `name` without Checkout, so HEAD moving is the only thing that could differ.
    @MainActor
    private func create(_ name: String, in state: WorkspaceState) async throws {
        state.branchCreation?.name = name
        state.branchCreation?.checksOutNewBranch = false
        await state.validateBranchName()
        try #require(state.canCreateBranch)
        await state.createBranch()
    }
}
