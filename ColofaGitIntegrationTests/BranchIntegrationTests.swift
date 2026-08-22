////
//  BranchIntegrationTests.swift
//  ColofaGitIntegrationTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// New Branch and Checkout against the real Git CLI, which is the only thing that can prove
/// Colofa accepts exactly the names Git accepts and refuses exactly the Checkouts Git refuses.
struct BranchIntegrationTests {
    private static let gitURL = URL(filePath: "/usr/bin/git")

    private func backend(_ fixture: GitTestRepository) -> GitRepositoryService {
        GitRepositoryService(
            candidateURLs: [Self.gitURL],
            environment: fixture.environment
        )
    }

    /// A working tree whose `shared.txt` differs between `main` and `other`, so a Checkout
    /// between them has something real to refuse.
    private func divergingRepository(_ fixture: GitTestRepository) throws -> URL {
        let repositoryURL = try fixture.createWorkingRepository()
        try write("main content\n", to: "shared.txt", in: repositoryURL)
        try fixture.git(["add", "--", "shared.txt"], in: repositoryURL)
        try fixture.git(["commit", "-m", "Add shared"], in: repositoryURL)
        try fixture.git(["switch", "-c", "other"], in: repositoryURL)
        try write("other content\n", to: "shared.txt", in: repositoryURL)
        try write("only on other\n", to: "arriving.txt", in: repositoryURL)
        try fixture.git(["add", "--", "shared.txt", "arriving.txt"], in: repositoryURL)
        try fixture.git(["commit", "-m", "Change shared"], in: repositoryURL)
        try fixture.git(["switch", "main"], in: repositoryURL)
        return repositoryURL
    }

    private func write(_ contents: String, to path: String, in repositoryURL: URL) throws {
        try Data(contents.utf8).write(to: repositoryURL.appending(path: path))
    }

    private func contents(of path: String, in repositoryURL: URL) throws -> String {
        try String(contentsOf: repositoryURL.appending(path: path), encoding: .utf8)
    }

    // MARK: - Names

    /// Colofa accepts exactly the names `git branch` accepts, which is why it asks Git rather
    /// than reproducing Git's rules.
    @Test(
        arguments: [
            "feature", "feature/work", "release-1.0", "分支",
            "HEAD", "-foo", "-", "bad name", "a..b", "x.lock", "feature@{1}",
            ".hidden", "trailing/", "with~tilde", "with:colon", "with*star", "with[bracket",
        ]
    )
    func acceptsExactlyTheNamesGitAccepts(_ name: String) async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try fixture.createCommit(in: repositoryURL)

        let isAcceptedByColofa = try await backend(fixture).validateBranchName(
            BranchNameValidationRequest(repositoryURL: repositoryURL, name: name)
        )
        var isAcceptedByGit = true
        do {
            try fixture.git(["branch", "--", name, "HEAD"], in: repositoryURL)
        } catch {
            isAcceptedByGit = false
        }

        #expect(
            isAcceptedByColofa == isAcceptedByGit,
            "Colofa and Git disagree about “\(name)”"
        )
    }

    /// `check-ref-format --branch` resolves shorthands such as `@{-1}`. Creating a branch under a
    /// name the user did not type is not what the dialog showed, so a rewritten name is refused.
    @Test
    func refusesAnameGitWouldRewrite() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try fixture.createCommit(in: repositoryURL)
        try fixture.git(["switch", "-c", "previous"], in: repositoryURL)
        try fixture.git(["switch", "main"], in: repositoryURL)

        #expect(
            try await backend(fixture).validateBranchName(
                BranchNameValidationRequest(repositoryURL: repositoryURL, name: "@{-1}")
            ) == false
        )
    }

    // MARK: - Creating

    /// Creating without Checkout writes one ref: HEAD stays where it was and so does every file.
    @Test
    @MainActor
    func createsAbranchWithoutTouchingHeadOrTheWorkingTree() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try fixture.createCommit(in: repositoryURL)
        try write("uncommitted\n", to: "README.md", in: repositoryURL)
        let state = await openedWorkspace(fixture, at: repositoryURL)
        let head = try fixture.git(["rev-parse", "HEAD"], in: repositoryURL)

        state.beginCreatingBranch()
        state.branchCreation?.name = "feature/work"
        state.branchCreation?.checksOutNewBranch = false
        await state.validateBranchName()
        await state.createBranch()

        #expect(state.branchCreation == nil)
        #expect(
            try fixture.git(["rev-parse", "refs/heads/feature/work"], in: repositoryURL) == head
        )
        #expect(try fixture.git(["branch", "--show-current"], in: repositoryURL) == "main")
        #expect(try contents(of: "README.md", in: repositoryURL) == "uncommitted\n")
        #expect(state.repository?.localBranches == ["feature/work", "main"])
    }

    @Test
    @MainActor
    func createsAndChecksOutAbranchAtASelectedCommit() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        let first = try fixture.createCommit(in: repositoryURL, named: "first.txt")
        try fixture.createCommit(in: repositoryURL, named: "second.txt")
        let state = await openedWorkspace(fixture, at: repositoryURL)
        let commit = try #require(
            await firstCommit(in: state, matching: first)
        )

        state.beginCreatingBranch(at: commit)
        state.branchCreation?.name = "recovery"
        await state.validateBranchName()
        await state.createBranch()

        #expect(state.repository?.head == .branch("recovery"))
        #expect(try fixture.git(["rev-parse", "HEAD"], in: repositoryURL) == first)
    }

    // MARK: - Checkout

    /// A change to a path the target Ref does not touch travels with the Checkout, exactly as
    /// Git allows.
    @Test
    @MainActor
    func carriesCompatibleLocalChangesToTheCheckedOutBranch() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try divergingRepository(fixture)
        try write("work in progress\n", to: "notes.txt", in: repositoryURL)
        try fixture.git(["add", "--", "notes.txt"], in: repositoryURL)
        let state = await openedWorkspace(fixture, at: repositoryURL)

        await state.checkout(.localBranch("other"))

        #expect(state.repositoryFailure == nil)
        #expect(state.repository?.head == .branch("other"))
        #expect(try contents(of: "notes.txt", in: repositoryURL) == "work in progress\n")
        #expect(state.repository?.stagedChanges.map(\.path) == ["notes.txt"])
    }

    /// Git refuses to overwrite an uncommitted change, and the refusal names the path it
    /// protected rather than only reporting an exit status.
    @Test
    @MainActor
    func refusesAcheckoutThatWouldOverwriteAtrackedChange() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try divergingRepository(fixture)
        try write("local edit\n", to: "shared.txt", in: repositoryURL)
        let state = await openedWorkspace(fixture, at: repositoryURL)

        await state.checkout(.localBranch("other"))

        let failure = try #require(state.repositoryFailure)
        guard case .checkoutRefusedAlert(let obstruction, let reference, _) = failure else {
            Issue.record("Expected the Checkout refusal, got \(failure)")
            return
        }
        #expect(obstruction.modifiedPaths == ["shared.txt"])
        #expect(obstruction.untrackedPaths.isEmpty)
        #expect(reference == "other")
        // Nothing moved and nothing was overwritten.
        #expect(state.repository?.head == .branch("main"))
        #expect(try contents(of: "shared.txt", in: repositoryURL) == "local edit\n")
    }

    /// An untracked file standing where the Ref writes one is refused too, and asks to be moved
    /// rather than committed.
    @Test
    @MainActor
    func refusesAcheckoutThatWouldOverwriteAnUntrackedFile() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try divergingRepository(fixture)
        try write("mine\n", to: "arriving.txt", in: repositoryURL)
        let state = await openedWorkspace(fixture, at: repositoryURL)

        await state.checkout(.localBranch("other"))

        let failure = try #require(state.repositoryFailure)
        guard case .checkoutRefusedAlert(let obstruction, _, _) = failure else {
            Issue.record("Expected the Checkout refusal, got \(failure)")
            return
        }
        #expect(obstruction.untrackedPaths == ["arriving.txt"])
        #expect(try contents(of: "arriving.txt", in: repositoryURL) == "mine\n")
    }

    /// A remote branch is checked out as a same-name local tracking branch, so later Pull and
    /// Push have an upstream.
    @Test
    @MainActor
    func checksOutAremoteBranchAsAlocalTrackingBranch() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try publishedRepository(fixture)
        let state = await openedWorkspace(fixture, at: repositoryURL)

        await state.checkout(.remoteBranch("origin/feature"))

        #expect(state.repository?.head == .branch("feature"))
        #expect(
            try fixture.git(["rev-parse", "--abbrev-ref", "feature@{upstream}"], in: repositoryURL)
                == "origin/feature"
        )
    }

    /// Recreating the local branch from the remote would move it back and drop the Commit it
    /// holds that the remote does not.
    @Test
    @MainActor
    func keepsAlocalCommitWhenCheckingOutItsRemoteBranch() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try publishedRepository(fixture)
        try fixture.git(["switch", "-c", "feature", "refs/remotes/origin/feature"], in: repositoryURL)
        try fixture.createCommit(in: repositoryURL, named: "local-only.txt")
        let localHead = try fixture.git(["rev-parse", "HEAD"], in: repositoryURL)
        try fixture.git(["switch", "main"], in: repositoryURL)
        let state = await openedWorkspace(fixture, at: repositoryURL)

        await state.checkout(.remoteBranch("origin/feature"))

        #expect(state.repository?.head == .branch("feature"))
        #expect(try fixture.git(["rev-parse", "HEAD"], in: repositoryURL) == localHead)
        #expect(
            FileManager.default.fileExists(
                atPath: repositoryURL.appending(path: "local-only.txt").normalizedFilePath
            )
        )
    }

    /// A tag names a Commit rather than a branch, so checking one out enters Detached HEAD
    /// visibly — and creating a branch from it is what makes Commit available again.
    @Test
    @MainActor
    func checksOutAtagAsDetachedHeadThatAbranchReattaches() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        let first = try fixture.createCommit(in: repositoryURL, named: "first.txt")
        try fixture.git(["tag", "v1.0", first], in: repositoryURL)
        try fixture.createCommit(in: repositoryURL, named: "second.txt")
        let state = await openedWorkspace(fixture, at: repositoryURL)

        await state.checkout(.tag("v1.0"))

        #expect(state.repository?.head == .detached(first))
        #expect(state.commitUnavailabilityReason == .detachedHead)

        state.beginCreatingBranch()
        state.branchCreation?.name = "from-tag"
        await state.validateBranchName()
        await state.createBranch()

        #expect(state.repository?.head == .branch("from-tag"))
        #expect(state.commitUnavailabilityReason != .detachedHead)
    }

    /// An Unborn Branch has nothing to compare against, so every path the Ref holds is read as
    /// one the Checkout would add.
    @Test
    func comparesAnUnbornBranchAgainstTheTargetTree() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try fixture.createCommit(in: repositoryURL, named: "tracked.txt")
        try fixture.git(["checkout", "--orphan", "fresh"], in: repositoryURL)
        try fixture.git(["rm", "-rf", "--cached", "."], in: repositoryURL)

        let comparison = try await backend(fixture).loadCheckoutComparison(
            CheckoutComparisonRequest(
                repositoryURL: repositoryURL,
                revision: "refs/heads/main",
                hasHeadCommit: false
            )
        )

        #expect(comparison.changedPaths == ["tracked.txt"])
        #expect(comparison.addedPaths == ["tracked.txt"])
    }

    /// A Repository with `origin` holding a `feature` branch that no local branch tracks yet.
    private func publishedRepository(_ fixture: GitTestRepository) throws -> URL {
        let remoteURL = try fixture.createBareRemote()
        let repositoryURL = try fixture.createWorkingRepository()
        try fixture.createCommit(in: repositoryURL)
        try fixture.addRemote(remoteURL, named: "origin", to: repositoryURL)
        try fixture.git(["push", "origin", "main"], in: repositoryURL)
        try fixture.git(["switch", "-c", "feature"], in: repositoryURL)
        try fixture.createCommit(in: repositoryURL, named: "feature.txt")
        try fixture.git(["push", "origin", "feature"], in: repositoryURL)
        try fixture.git(["switch", "main"], in: repositoryURL)
        try fixture.git(["branch", "--delete", "--force", "feature"], in: repositoryURL)
        return repositoryURL
    }

    /// The Commit in the current Ref's History whose object ID is `objectID`.
    @MainActor
    private func firstCommit(
        in state: WorkspaceState,
        matching objectID: String
    ) async -> HistoryCommit? {
        await state.loadHistory()
        return state.history?.timeline?.commits.first { $0.objectID == objectID }
    }
}
