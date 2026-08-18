////
//  HistoryIntegrationTests.swift
//  ColofaGitIntegrationTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

@Suite(.serialized)
struct HistoryIntegrationTests {
    /// Selecting a Ref is inspection: real Git reports the History reachable from it, and HEAD
    /// and the working tree are exactly where they were.
    @Test
    @MainActor
    func readsALocalBranchWithoutMovingHead() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try fixture.createCommit(in: repositoryURL)
        _ = try fixture.git(["checkout", "-b", "side"], in: repositoryURL)
        try commitFile("side.txt", in: repositoryURL, fixture: fixture)
        _ = try fixture.git(["checkout", "main"], in: repositoryURL)

        let state = await openedWorkspace(fixture, at: repositoryURL)
        state.sidebarSelection = .reference(.localBranch("side"))
        await state.loadHistory()

        #expect(state.history?.timeline?.commits.map(\.summary) == ["side.txt", "Fixture commit"])
        #expect(try fixture.git(["rev-parse", "--abbrev-ref", "HEAD"], in: repositoryURL) == "main")
        #expect(try fixture.git(["status", "--porcelain"], in: repositoryURL).isEmpty)
    }

    @Test
    @MainActor
    func readsARemoteBranchWithoutCreatingALocalOne() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        let remoteURL = try fixture.createBareRemote()
        try fixture.createCommit(in: repositoryURL)
        try fixture.addRemote(remoteURL, named: "origin", to: repositoryURL)
        _ = try fixture.git(["push", "-u", "origin", "main"], in: repositoryURL)

        let state = await openedWorkspace(fixture, at: repositoryURL)
        state.sidebarSelection = .reference(.remoteBranch("origin/main"))
        await state.loadHistory()

        #expect(state.history?.timeline?.commits.map(\.summary) == ["Fixture commit"])
        #expect(
            try fixture.git(["for-each-ref", "--format=%(refname)", "refs/heads"], in: repositoryURL)
                == "refs/heads/main"
        )
    }

    /// A tag names one Commit, and the walk starts there, so selecting the tag selects it.
    @Test
    @MainActor
    func readsATagAndSelectsTheCommitItNames() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try fixture.createCommit(in: repositoryURL)
        let tagged = try fixture.git(["rev-parse", "HEAD"], in: repositoryURL)
        _ = try fixture.git(["tag", "-a", "v1.0", "-m", "Release"], in: repositoryURL)
        try commitFile("later.txt", in: repositoryURL, fixture: fixture)

        let state = await openedWorkspace(fixture, at: repositoryURL)
        state.sidebarSelection = .reference(.tag("v1.0"))
        await state.loadHistory()

        #expect(state.selectedCommitID == tagged)
        #expect(state.history?.timeline?.commits.map(\.summary) == ["Fixture commit"])
    }

    /// Every reachable Commit, including the ones a merge brought in, in the order Git walked
    /// them. Colofa has no topology lanes yet; it must still show the whole reachable set.
    @Test
    @MainActor
    func includesMergeAndSideBranchCommits() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try fixture.createCommit(in: repositoryURL)
        _ = try fixture.git(["checkout", "-b", "side"], in: repositoryURL)
        try commitFile("side.txt", in: repositoryURL, fixture: fixture)
        _ = try fixture.git(["checkout", "main"], in: repositoryURL)
        try commitFile("main.txt", in: repositoryURL, fixture: fixture)
        _ = try fixture.git(["merge", "--no-ff", "side", "-m", "Merge side"], in: repositoryURL)

        let state = await openedWorkspace(fixture, at: repositoryURL)
        await state.loadHistory()

        let commits = try #require(state.history?.timeline?.commits)
        #expect(Set(commits.map(\.summary)) == ["Merge side", "main.txt", "side.txt", "Fixture commit"])
        let merge = try #require(commits.first)
        #expect(merge.summary == "Merge side")
        #expect(merge.isMerge)
        #expect(merge.parentObjectIDs.count == 2)
        // A merge is compared against the parent History walked through.
        #expect(merge.comparisonParentObjectID == commits.first { $0.summary == "main.txt" }?.objectID)
    }

    /// The Ref's own line: at the merge the walk follows the first parent, so the side branch is
    /// represented by the merge that integrated it rather than by its Commits.
    @Test
    @MainActor
    func theFirstParentWalkFollowsOnlyTheRefsOwnLine() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try fixture.createCommit(in: repositoryURL)
        _ = try fixture.git(["checkout", "-b", "side"], in: repositoryURL)
        try commitFile("side.txt", in: repositoryURL, fixture: fixture)
        _ = try fixture.git(["checkout", "main"], in: repositoryURL)
        try commitFile("main.txt", in: repositoryURL, fixture: fixture)
        _ = try fixture.git(["merge", "--no-ff", "side", "-m", "Merge side"], in: repositoryURL)

        let state = await openedWorkspace(fixture, at: repositoryURL)
        await state.loadHistory()
        #expect(
            Set(state.history?.timeline?.commits.map(\.summary) ?? [])
                == ["Merge side", "main.txt", "side.txt", "Fixture commit"]
        )

        state.historyScope = .firstParent
        await state.loadHistory()

        #expect(
            state.history?.timeline?.commits.map(\.summary)
                == ["Merge side", "main.txt", "Fixture commit"]
        )
    }

    /// Nothing is reachable from an Unborn Branch. Asking Git to walk from one is an error, so
    /// Colofa reports the state instead of the error.
    @Test
    @MainActor
    func reportsAnUnbornBranchAsAnEmptyHistory() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()

        let state = await openedWorkspace(fixture, at: repositoryURL)
        await state.loadHistory()

        #expect(state.history == .unborn)
    }

    /// A shallow clone really does have parents it does not hold. Git says so by marking the
    /// boundary as grafted, and that is the truthful thing to render.
    @Test
    @MainActor
    func marksTheBoundaryOfAShallowRepository() async throws {
        let fixture = try GitTestRepository()
        let originURL = try fixture.createWorkingRepository(named: "origin-work")
        try fixture.createCommit(in: originURL)
        try commitFile("second.txt", in: originURL, fixture: fixture)
        try commitFile("third.txt", in: originURL, fixture: fixture)
        let shallowURL = fixture.rootURL.appending(path: "shallow", directoryHint: .isDirectory)
        _ = try fixture.git(
            [
                "clone", "--depth", "1",
                "file://\(originURL.normalizedFilePath)", shallowURL.normalizedFilePath,
            ]
        )

        let state = await openedWorkspace(fixture, at: shallowURL)
        await state.loadHistory()

        let commits = try #require(state.history?.timeline?.commits)
        #expect(commits.count == 1)
        let boundary = try #require(commits.first)
        #expect(boundary.isShallowBoundary)
        #expect(boundary.parentObjectIDs.isEmpty)
        // Not a root Commit: the Repository does not start here, this clone does.
        #expect(!boundary.isRoot)
        // `grafted` is not a Ref, so it never reaches the labels.
        #expect(!boundary.refLabels.map(\.name).contains("grafted"))
    }

    @Test
    @MainActor
    func readsTheFullMessageAndChangedFilesOfASelectedCommit() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try fixture.createCommit(in: repositoryURL)
        try writeFile("one\n", to: "renamed 名称.txt", in: repositoryURL)
        _ = try fixture.git(["add", "--all"], in: repositoryURL)
        _ = try fixture.git(
            ["commit", "-m", "Add two paths\n\nWhy it was added,\nover two lines."],
            in: repositoryURL
        )

        let state = await openedWorkspace(fixture, at: repositoryURL)
        state.sidebarSelection = .reference(.head)
        await state.loadHistory()
        state.selectedCommitID = state.history?.timeline?.commits.first?.objectID
        // The file list is what a Commit's Diff is chosen from, so it is read first.
        await state.loadCommitDetail()
        await state.loadDiff()

        let detail = try #require(state.commitDetail?.detail)
        #expect(detail.summary == "Add two paths")
        #expect(detail.body == "Why it was added,\nover two lines.")
        #expect(detail.changedFiles.map(\.newPath) == ["renamed 名称.txt"])
        guard case .loaded(let diff) = state.diff else {
            return #expect(Bool(false), "The Commit's Diff was not rendered")
        }
        #expect(diff.files.map(\.newPath) == ["renamed 名称.txt"])
        #expect(diff.stats == DiffStats(additions: 1, deletions: 0))
    }

    /// A Commit is browsed one file at a time: selecting a path reads that path's patch, and
    /// never the whole Commit's.
    @Test
    @MainActor
    func readsOneChangedFileOfACommitAtATime() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try fixture.createCommit(in: repositoryURL)
        try writeFile("first\n", to: "one.txt", in: repositoryURL)
        try writeFile("second\n", to: "two.txt", in: repositoryURL)
        _ = try fixture.git(["add", "--all"], in: repositoryURL)
        _ = try fixture.git(["commit", "-m", "Add two paths"], in: repositoryURL)

        let state = await openedWorkspace(fixture, at: repositoryURL)
        state.sidebarSelection = .reference(.head)
        await state.loadHistory()
        state.selectedCommitID = state.history?.timeline?.commits.first?.objectID
        await state.loadCommitDetail()

        let files = try #require(state.commitDetail?.detail?.changedFiles)
        #expect(files.map(\.newPath) == ["one.txt", "two.txt"])
        // The Commit opens on a file rather than on nothing.
        #expect(state.selectedCommitFile?.newPath == "one.txt")

        await state.loadDiff()
        guard case .loaded(let first) = state.diff else {
            return #expect(Bool(false), "The first file's Diff was not rendered")
        }
        #expect(first.files.map(\.newPath) == ["one.txt"])

        state.selectedCommitFileID = files[1].id
        await state.loadDiff()
        guard case .loaded(let second) = state.diff else {
            return #expect(Bool(false), "The second file's Diff was not rendered")
        }
        #expect(second.files.map(\.newPath) == ["two.txt"])
    }

    /// A root Commit has nothing to compare against, so Git compares it against an empty tree
    /// and it reads as everything it introduced.
    @Test
    @MainActor
    func rendersTheDiffOfARootCommit() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try fixture.createCommit(in: repositoryURL)

        let state = await openedWorkspace(fixture, at: repositoryURL)
        state.sidebarSelection = .reference(.head)
        await state.loadHistory()
        let root = try #require(state.history?.timeline?.commits.first)
        #expect(root.isRoot)
        state.selectedCommitID = root.objectID
        await state.loadCommitDetail()
        await state.loadDiff()

        guard case .loaded(let diff) = state.diff else {
            return #expect(Bool(false), "The root Commit's Diff was not rendered")
        }
        #expect(diff.files.map(\.newPath) == ["README.md"])
        #expect(diff.stats == DiffStats(additions: 1, deletions: 0))
    }

    /// Git prints `origin/main` for a remote-tracking branch and `main` for a local one, and
    /// nothing in the text separates them. Colofa classifies them against what the Repository
    /// actually reports.
    @Test
    @MainActor
    func classifiesEveryRefPointingAtACommit() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        let remoteURL = try fixture.createBareRemote()
        try fixture.createCommit(in: repositoryURL)
        try fixture.addRemote(remoteURL, named: "origin", to: repositoryURL)
        _ = try fixture.git(["push", "-u", "origin", "main"], in: repositoryURL)
        _ = try fixture.git(["tag", "v1.0"], in: repositoryURL)

        let state = await openedWorkspace(fixture, at: repositoryURL)
        await state.loadHistory()

        let labels = try #require(state.history?.timeline?.commits.first?.refLabels)
        #expect(labels.contains(HistoryRefLabel(name: "HEAD", kind: .head)))
        #expect(labels.contains(HistoryRefLabel(name: "main", kind: .localBranch)))
        #expect(labels.contains(HistoryRefLabel(name: "origin/main", kind: .remoteBranch)))
        #expect(labels.contains(HistoryRefLabel(name: "v1.0", kind: .tag)))
    }
}
