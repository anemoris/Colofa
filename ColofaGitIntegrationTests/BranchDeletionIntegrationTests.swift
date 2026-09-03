////
//  BranchDeletionIntegrationTests.swift
//  ColofaGitIntegrationTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// Delete Branch against the real Git CLI, which is the only thing that can prove Colofa counts
/// what Git counts, deletes through Git's own protection, and leaves everything outside
/// `refs/heads/` exactly as it found it.
struct BranchDeletionIntegrationTests {
    private static let gitURL = URL(filePath: "/usr/bin/git")

    private func backend(_ fixture: GitTestRepository) -> GitRepositoryService {
        GitRepositoryService(candidateURLs: [Self.gitURL], environment: fixture.environment)
    }

    /// A Repository whose `topic` holds two Commits `main` does not.
    private func repositoryWithUnmergedTopic(_ fixture: GitTestRepository) throws -> URL {
        let repositoryURL = try fixture.createWorkingRepository()
        try fixture.createCommit(in: repositoryURL, named: "base.txt")
        try fixture.git(["switch", "-c", "topic"], in: repositoryURL)
        try fixture.createCommit(in: repositoryURL, named: "one.txt")
        try fixture.createCommit(in: repositoryURL, named: "two.txt")
        try fixture.git(["switch", "main"], in: repositoryURL)
        return repositoryURL
    }

    private func survey(
        _ fixture: GitTestRepository,
        at repositoryURL: URL,
        branch: String
    ) async throws -> BranchDeletionSurvey? {
        try await backend(fixture).loadBranchDeletionSurvey(
            BranchDeletionRequest(repositoryURL: repositoryURL, name: branch)
        )
    }

    private func branches(_ fixture: GitTestRepository, in repositoryURL: URL) throws -> [String] {
        try fixture.git(
            ["for-each-ref", "--format=%(refname)", "refs/heads", "refs/remotes", "refs/tags"],
            in: repositoryURL
        )
        .split(separator: "\n")
        .map(String.init)
    }

    // MARK: - What Git says

    /// The count is the History this Branch alone reaches, measured against every other Ref.
    @Test
    func countsTheCommitsNoOtherRefHolds() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try repositoryWithUnmergedTopic(fixture)

        let survey = try #require(
            try await self.survey(fixture, at: repositoryURL, branch: "topic")
        )

        #expect(survey.uniqueCommitCount == 2)
        #expect(survey.holdsUniqueCommits)
        #expect(
            survey.objectID
                == (try fixture.git(["rev-parse", "refs/heads/topic"], in: repositoryURL))
        )
    }

    /// A Branch every other Ref already holds costs nothing to remove, and says zero.
    @Test
    func countsNothingForAmergedBranch() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try repositoryWithUnmergedTopic(fixture)
        try fixture.git(["merge", "--no-ff", "-m", "Merge topic", "topic"], in: repositoryURL)

        let survey = try #require(
            try await self.survey(fixture, at: repositoryURL, branch: "topic")
        )

        #expect(survey.uniqueCommitCount == 0)
        #expect(!survey.holdsUniqueCommits)
    }

    /// A tag holding the same Commits is another Ref, so they are not unique to the Branch — and
    /// Git's own safe deletion still refuses it, which is the gap the count alone cannot close.
    @Test
    func countsNothingWhenAtagAlreadyHoldsTheCommits() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try repositoryWithUnmergedTopic(fixture)
        try fixture.git(["tag", "keep", "refs/heads/topic"], in: repositoryURL)

        let survey = try #require(
            try await self.survey(fixture, at: repositoryURL, branch: "topic")
        )

        #expect(survey.uniqueCommitCount == 0)
        #expect(throws: (any Error).self) {
            try fixture.git(["branch", "--delete", "--", "topic"], in: repositoryURL)
        }
    }

    /// A Branch Git no longer has is reported as absent rather than as a failure.
    @Test
    func reportsNothingForAbranchThatIsNotThere() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try fixture.createCommit(in: repositoryURL)

        #expect(try await survey(fixture, at: repositoryURL, branch: "gone") == nil)
    }

    // MARK: - Deleting

    /// A fully merged Branch deletes through Git's safe mode, and every other Ref survives it.
    @Test
    @MainActor
    func deletesAmergedBranchThroughGitsSafeMode() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try repositoryWithUnmergedTopic(fixture)
        try fixture.git(["merge", "--no-ff", "-m", "Merge topic", "topic"], in: repositoryURL)
        let head = try fixture.git(["rev-parse", "HEAD"], in: repositoryURL)
        let state = await openedWorkspace(fixture, at: repositoryURL)

        await state.beginDeletingBranch(.localBranch("topic"))
        #expect(state.branchDeletion?.isForceRequired == false)
        await state.confirmBranchDeletion()

        #expect(state.branchDeletion == nil)
        #expect(state.repositoryFailure == nil)
        #expect(try branches(fixture, in: repositoryURL) == ["refs/heads/main"])
        // The Commits the Branch held are still reachable, because another Ref holds them.
        #expect(try fixture.git(["rev-parse", "HEAD"], in: repositoryURL) == head)
    }

    /// Git's safe mode protects an unmerged Branch, so Delete does nothing until the box is
    /// ticked — and does exactly what was asked once it is.
    @Test
    @MainActor
    func requiresTheExplicitForceForAnUnmergedBranch() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try repositoryWithUnmergedTopic(fixture)
        let state = await openedWorkspace(fixture, at: repositoryURL)

        await state.beginDeletingBranch(.localBranch("topic"))

        #expect(state.branchDeletion?.survey.uniqueCommitCount == 2)
        #expect(state.branchDeletion?.isForceRequired == true)
        #expect(!state.canConfirmBranchDeletion)

        await state.confirmBranchDeletion()
        #expect(state.repository?.localBranches == ["main", "topic"])

        state.branchDeletion?.forcesDeletion = true
        await state.confirmBranchDeletion()

        #expect(state.branchDeletion == nil)
        #expect(state.repository?.localBranches == ["main"])
    }

    /// Colofa never deletes the Branch the working tree is on, and Git would refuse it anyway.
    @Test
    @MainActor
    func refusesToDeleteTheCurrentBranch() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try repositoryWithUnmergedTopic(fixture)
        let state = await openedWorkspace(fixture, at: repositoryURL)

        await state.beginDeletingBranch(.localBranch("main"))

        #expect(state.branchDeletion == nil)
        #expect(state.repository?.localBranches == ["main", "topic"])
    }

    /// A local cleanup must not reach shared work: the remote's own branch and the
    /// Remote-tracking Branch are both exactly where they were.
    @Test
    @MainActor
    func leavesTheRemoteBranchAndItsTrackingRefUntouched() async throws {
        let fixture = try GitTestRepository()
        let remoteURL = try fixture.createBareRemote()
        let repositoryURL = try fixture.createWorkingRepository()
        try fixture.createCommit(in: repositoryURL)
        try fixture.addRemote(remoteURL, named: "origin", to: repositoryURL)
        try fixture.git(["push", "origin", "main"], in: repositoryURL)
        try fixture.git(["switch", "-c", "topic"], in: repositoryURL)
        try fixture.createCommit(in: repositoryURL, named: "topic.txt")
        try fixture.git(["push", "--set-upstream", "origin", "topic"], in: repositoryURL)
        try fixture.git(["switch", "main"], in: repositoryURL)
        let remoteTopic = try fixture.git(
            ["rev-parse", "refs/remotes/origin/topic"],
            in: repositoryURL
        )
        let state = await openedWorkspace(fixture, at: repositoryURL)

        await state.beginDeletingBranch(.localBranch("topic"))
        // Pushed work is held by its Remote-tracking Branch, so nothing here is unique to the
        // local Branch and Git's own safe deletion carries it.
        #expect(state.branchDeletion?.survey.uniqueCommitCount == 0)
        await state.confirmBranchDeletion()

        #expect(state.repository?.localBranches == ["main"])
        #expect(
            try fixture.git(["rev-parse", "refs/remotes/origin/topic"], in: repositoryURL)
                == remoteTopic
        )
        #expect(
            try fixture.git(["rev-parse", "refs/heads/topic"], in: remoteURL) == remoteTopic
        )
        #expect(state.repository?.remoteBranches == ["origin/main", "origin/topic"])
    }

    /// A Ref that moved after the confirmation opened is refused rather than deleted under an
    /// assumption that stopped being true.
    @Test
    @MainActor
    func refusesAdeletionWhoseRefMovedAfterTheConfirmation() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try repositoryWithUnmergedTopic(fixture)
        let state = await openedWorkspace(fixture, at: repositoryURL)
        await state.beginDeletingBranch(.localBranch("topic"))
        state.branchDeletion?.forcesDeletion = true

        // Somebody else moves the Branch while the confirmation is on screen.
        try fixture.git(["branch", "--force", "topic", "refs/heads/main"], in: repositoryURL)

        await state.confirmBranchDeletion()

        #expect(state.branchDeletion == nil)
        #expect(state.isShowingStaleBranchDeletionAlert)
        #expect(state.repository?.localBranches == ["main", "topic"])
    }

    /// A refusal only Git can give — merged into another Ref but into neither HEAD nor its
    /// upstream — keeps the dialog open with Git's own words and requires the explicit force.
    @Test
    @MainActor
    func escalatesTheRefusalOnlyGitCanGive() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try repositoryWithUnmergedTopic(fixture)
        try fixture.git(["tag", "keep", "refs/heads/topic"], in: repositoryURL)
        let state = await openedWorkspace(fixture, at: repositoryURL)

        await state.beginDeletingBranch(.localBranch("topic"))
        #expect(state.branchDeletion?.isForceRequired == false)

        await state.confirmBranchDeletion()

        let deletion = try #require(state.branchDeletion)
        #expect(deletion.isForceRequired)
        #expect(deletion.failure?.details.output.isEmpty == false)
        #expect(state.repository?.localBranches == ["main", "topic"])

        state.branchDeletion?.forcesDeletion = true
        await state.confirmBranchDeletion()

        #expect(state.repository?.localBranches == ["main"])
        // Forcing removed the name; the tag still holds the History it named.
        #expect(try fixture.git(["rev-parse", "refs/tags/keep"], in: repositoryURL).isEmpty == false)
    }
}
