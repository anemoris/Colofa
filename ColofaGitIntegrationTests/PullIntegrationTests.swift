////
//  PullIntegrationTests.swift
//  ColofaGitIntegrationTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// Pull against the real Git CLI and a local bare remote, which is the only thing that can prove
/// Colofa fast-forwards and never does anything else — including under the configuration that
/// would make `git pull` merge, rebase, or stash on its own.
struct PullIntegrationTests {

    // MARK: - Fast-forward

    /// The whole point of Pull: the Branch, the working tree, the ahead/behind counts, and the
    /// app-owned time all move together.
    @Test
    @MainActor
    func pullFastForwardsTheCurrentBranchOntoItsUpstream() async throws {
        let fixture = try GitTestRepository()
        let published = try publishedRepository(fixture)
        try commitFile("later\n", to: "later.txt", in: published.publisherURL, of: fixture)
        try fixture.git(["push", "origin", "main"], in: published.publisherURL)
        let state = await openedWorkspace(fixture, at: published.cloneURL)

        await state.pull()

        #expect(state.repositoryFailure == nil)
        #expect(state.repository?.upstream?.behind == 0)
        #expect(state.repository?.upstream?.ahead == 0)
        #expect(state.lastFetchDate != nil)
        #expect(
            FileManager.default.fileExists(
                atPath: published.cloneURL.appending(path: "later.txt").normalizedFilePath
            ),
            "The fast-forward never reached the working tree"
        )
        #expect(
            try fixture.git(["rev-parse", "HEAD"], in: published.cloneURL)
                == fixture.git(["rev-parse", "origin/main"], in: published.cloneURL)
        )
    }

    /// A Branch already at its upstream is a Pull that succeeds having changed nothing, which is
    /// an answer rather than a failure.
    @Test
    @MainActor
    func pullOfAnAlreadyCurrentBranchChangesNothingAndRaisesNoAlert() async throws {
        let fixture = try GitTestRepository()
        let published = try publishedRepository(fixture)
        let state = await openedWorkspace(fixture, at: published.cloneURL)
        let head = try fixture.git(["rev-parse", "HEAD"], in: published.cloneURL)

        await state.pull()

        #expect(state.repositoryFailure == nil)
        #expect(try fixture.git(["rev-parse", "HEAD"], in: published.cloneURL) == head)
        #expect(state.repository?.upstream?.behind == 0)
        #expect(state.lastFetchDate != nil)
    }

    /// A fast-forward is not a merge, so `merge.ff` set to refuse one changes nothing about it.
    @Test
    @MainActor
    func pullNeverCreatesAmergeCommitEvenWhereGitIsConfiguredTo() async throws {
        let fixture = try GitTestRepository()
        let published = try publishedRepository(fixture)
        try fixture.git(["config", "merge.ff", "false"], in: published.cloneURL)
        try fixture.git(["config", "pull.ff", "false"], in: published.cloneURL)
        try commitFile("later\n", to: "later.txt", in: published.publisherURL, of: fixture)
        try fixture.git(["push", "origin", "main"], in: published.publisherURL)
        let state = await openedWorkspace(fixture, at: published.cloneURL)

        await state.pull()

        #expect(state.repositoryFailure == nil)
        #expect(
            try fixture.git(["rev-list", "--count", "--merges", "HEAD"], in: published.cloneURL)
                == "0",
            "The Pull created a merge commit"
        )
        #expect(state.repository?.operation == nil)
    }

    // MARK: - Divergence

    /// Both sides moved, which is the one thing a fast-forward can never resolve. Nothing about
    /// the Repository changes, and the refusal names the two commands that could.
    @Test
    @MainActor
    func pullRefusesAdivergenceAndDirectsToMergeOrRebase() async throws {
        let fixture = try GitTestRepository()
        let published = try divergedRepository(fixture)
        let state = await openedWorkspace(fixture, at: published.cloneURL)
        let head = try fixture.git(["rev-parse", "HEAD"], in: published.cloneURL)

        await state.pull()

        #expect(try fixture.git(["rev-parse", "HEAD"], in: published.cloneURL) == head)
        #expect(state.repository?.upstream?.ahead == 1)
        #expect(state.repository?.upstream?.behind == 1)
        let message = englishFailureMessage(state)
        #expect(message?.contains("Merge") == true)
        #expect(message?.contains("Rebase") == true)
    }

    /// A refused fast-forward starts nothing there is anything to abort, so no active operation
    /// appears — Git wrote no `MERGE_HEAD` to leave one behind.
    @Test
    @MainActor
    func arefusedPullLeavesNoGitOperationToAbort() async throws {
        let fixture = try GitTestRepository()
        let published = try divergedRepository(fixture)
        let state = await openedWorkspace(fixture, at: published.cloneURL)

        await state.pull()

        #expect(state.repository?.operation == nil)
        #expect(
            !FileManager.default.fileExists(
                atPath: published.cloneURL.appending(path: ".git/MERGE_HEAD").normalizedFilePath
            ),
            "The refused Pull left a Merge in progress"
        )
    }

    /// `pull.rebase` is exactly the configuration that makes `git pull` rewrite local commits.
    /// Colofa never runs `git pull`, so the local Commit is still the one it was.
    @Test
    @MainActor
    func pullNeverRebasesLocalCommitsEvenWhereGitIsConfiguredTo() async throws {
        let fixture = try GitTestRepository()
        let published = try divergedRepository(fixture)
        try fixture.git(["config", "pull.rebase", "true"], in: published.cloneURL)
        let state = await openedWorkspace(fixture, at: published.cloneURL)
        let head = try fixture.git(["rev-parse", "HEAD"], in: published.cloneURL)

        await state.pull()

        #expect(
            try fixture.git(["rev-parse", "HEAD"], in: published.cloneURL) == head,
            "The Pull rewrote a local Commit"
        )
        #expect(state.repository?.upstream?.ahead == 1)
    }

    // MARK: - Local work in the way

    /// Git refuses to overwrite the file, Colofa names it, and the edit is still on disk.
    @Test
    @MainActor
    func pullRefusesToOverwriteLocalChangesAndNamesThem() async throws {
        let fixture = try GitTestRepository()
        let published = try publishedRepository(fixture)
        try commitFile("upstream\n", to: "shared.txt", in: published.publisherURL, of: fixture)
        try fixture.git(["push", "origin", "main"], in: published.publisherURL)
        let sharedURL = published.cloneURL.appending(path: "shared.txt")
        try Data("local edit\n".utf8).write(to: sharedURL)
        let state = await openedWorkspace(fixture, at: published.cloneURL)

        await state.pull()

        #expect(state.repositoryFailureTitle == .pullBlockedTitle)
        #expect(englishFailureMessage(state)?.contains("shared.txt") == true)
        #expect(try String(contentsOf: sharedURL, encoding: .utf8) == "local edit\n")
    }

    /// `merge.autoStash` would otherwise stash the working tree, fast-forward, and re-apply —
    /// which is how the same case ends in a conflicted tree nobody asked for.
    @Test
    @MainActor
    func pullNeverStashesLocalWorkEvenWhereGitIsConfiguredTo() async throws {
        let fixture = try GitTestRepository()
        let published = try publishedRepository(fixture)
        try fixture.git(["config", "merge.autoStash", "true"], in: published.cloneURL)
        try commitFile("upstream\n", to: "shared.txt", in: published.publisherURL, of: fixture)
        try fixture.git(["push", "origin", "main"], in: published.publisherURL)
        let sharedURL = published.cloneURL.appending(path: "shared.txt")
        try Data("local edit\n".utf8).write(to: sharedURL)
        let state = await openedWorkspace(fixture, at: published.cloneURL)

        await state.pull()

        #expect(
            try fixture.git(["stash", "list"], in: published.cloneURL).isEmpty,
            "The Pull stashed the user's work"
        )
        #expect(try String(contentsOf: sharedURL, encoding: .utf8) == "local edit\n")
        #expect(
            try fixture.git(["diff", "--name-only", "--diff-filter=U"], in: published.cloneURL)
                .isEmpty,
            "The Pull left a Conflict behind"
        )
    }

    // MARK: - Refusing before the command

    @Test
    @MainActor
    func pullIsUnavailableWithoutAnUpstream() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try fixture.createCommit(in: repositoryURL)
        let state = await openedWorkspace(fixture, at: repositoryURL)

        #expect(!state.canPull)
        #expect(state.pullUnavailabilityReason == .noUpstream)
    }

    /// A clone of a repository that was empty has an upstream and no Commit of its own, which is
    /// exactly the state a first Pull resolves.
    @Test
    @MainActor
    func pullFastForwardsAnUnbornBranchOntoItsUpstream() async throws {
        let fixture = try GitTestRepository()
        let remoteURL = try fixture.createBareRemote()
        let cloneURL = try fixture.createClone(of: remoteURL, named: "clone")
        let publisherURL = try fixture.createClone(of: remoteURL, named: "publisher")
        try fixture.createCommit(in: publisherURL)
        try fixture.git(["push", "origin", "main"], in: publisherURL)
        let state = await openedWorkspace(fixture, at: cloneURL)
        #expect(state.canPull)

        await state.pull()

        #expect(state.repositoryFailure == nil)
        #expect(state.repository?.head == .branch("main"))
        #expect(
            FileManager.default.fileExists(
                atPath: cloneURL.appending(path: "README.md").normalizedFilePath
            )
        )
    }

    // MARK: - Fixtures

    /// A clone whose Branch and upstream have each gained one Commit the other does not have.
    private func divergedRepository(
        _ fixture: GitTestRepository
    ) throws -> PublishedRepository {
        let published = try publishedRepository(fixture)
        try commitFile("upstream\n", to: "upstream.txt", in: published.publisherURL, of: fixture)
        try fixture.git(["push", "origin", "main"], in: published.publisherURL)
        try commitFile("local\n", to: "local.txt", in: published.cloneURL, of: fixture)
        return published
    }

    /// The failure on screen, read in the language these assertions are written in rather than
    /// in whatever language the machine running them is set to.
    @MainActor
    private func englishFailureMessage(_ state: WorkspaceState) -> String? {
        guard var message = state.repositoryFailureMessage else {
            return nil
        }
        message.locale = Locale(identifier: "en")
        return String(localized: message)
    }
}
