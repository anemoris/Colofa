////
//  StagingIntegrationTests.swift
//  ColofaGitIntegrationTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

@Suite(.serialized)
struct StagingIntegrationTests {
    @Test
    @MainActor
    func stagesAndUnstagesModifiedDeletedRenamedAndUntrackedFiles() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try Data("base\n".utf8).write(to: repositoryURL.appending(path: "modified.txt"))
        try Data("delete\n".utf8).write(to: repositoryURL.appending(path: "deleted.txt"))
        try Data("rename\n".utf8).write(to: repositoryURL.appending(path: "old name.txt"))
        _ = try fixture.git(["add", "--all"], in: repositoryURL)
        _ = try fixture.git(["commit", "-m", "Base"], in: repositoryURL)

        try Data("changed\n".utf8).write(to: repositoryURL.appending(path: "modified.txt"))
        try FileManager.default.removeItem(at: repositoryURL.appending(path: "deleted.txt"))
        try FileManager.default.moveItem(
            at: repositoryURL.appending(path: "old name.txt"),
            to: repositoryURL.appending(path: "new name.txt")
        )
        try Data("new\n".utf8).write(to: repositoryURL.appending(path: "untracked.txt"))

        let state = WorkspaceState(repositoryService: service(), launchArguments: ["--ui-testing"])
        await state.handleRepositorySelection(.success(repositoryURL))

        for path in [
            "deleted.txt", "modified.txt", "old name.txt", "new name.txt", "untracked.txt",
        ] {
            let change = try #require(state.repository?.unstagedChanges.first { $0.path == path })
            await state.stage(change)
        }

        #expect(state.repository?.unstagedChanges.isEmpty == true)
        #expect(state.repository?.stagedChanges.map(\.path) == [
            "deleted.txt", "modified.txt", "new name.txt", "untracked.txt",
        ])
        #expect(
            state.repository?.stagedChanges.first { $0.path == "new name.txt" }?.kind
                == .renamed(from: "old name.txt")
        )

        for path in ["deleted.txt", "modified.txt", "new name.txt", "untracked.txt"] {
            let change = try #require(state.repository?.stagedChanges.first { $0.path == path })
            await state.unstage(change)
        }

        #expect(state.repository?.stagedChanges.isEmpty == true)
        #expect(state.repository?.unstagedChanges.map(\.path) == [
            "deleted.txt", "modified.txt", "new name.txt", "old name.txt", "untracked.txt",
        ])
    }

    @Test
    @MainActor
    func bulkActionsPreserveConflictsAndPartialStaging() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        let conflictURL = repositoryURL.appending(path: "conflict.txt")
        let partialURL = repositoryURL.appending(path: "partial.txt")
        try Data("base\n".utf8).write(to: conflictURL)
        try Data("base\n".utf8).write(to: partialURL)
        _ = try fixture.git(["add", "--all"], in: repositoryURL)
        _ = try fixture.git(["commit", "-m", "Base"], in: repositoryURL)
        _ = try fixture.git(["checkout", "-b", "topic"], in: repositoryURL)
        try Data("topic\n".utf8).write(to: conflictURL)
        _ = try fixture.git(["commit", "-am", "Topic"], in: repositoryURL)
        _ = try fixture.git(["checkout", "main"], in: repositoryURL)
        try Data("main\n".utf8).write(to: conflictURL)
        _ = try fixture.git(["commit", "-am", "Main"], in: repositoryURL)
        do {
            _ = try fixture.git(["merge", "topic"], in: repositoryURL)
            Issue.record("Expected a merge conflict")
        } catch {
            // The unresolved Conflict is the fixture this test needs.
        }
        try Data("base\nstaged\n".utf8).write(to: partialURL)
        _ = try fixture.git(["add", "--", "partial.txt"], in: repositoryURL)
        try Data("base\nstaged\nunstaged\n".utf8).write(to: partialURL)
        try Data("ordinary\n".utf8).write(to: repositoryURL.appending(path: "ordinary.txt"))

        let state = WorkspaceState(repositoryService: service(), launchArguments: ["--ui-testing"])
        await state.handleRepositorySelection(.success(repositoryURL))

        await state.stageAll()

        #expect(state.repository?.unstagedChanges == [
            RepositoryChange(path: "conflict.txt", kind: .conflict),
        ])
        #expect(state.repository?.stagedChanges.map(\.path) == ["ordinary.txt", "partial.txt"])

        await state.unstageAll()

        #expect(state.repository?.stagedChanges.isEmpty == true)
        #expect(state.repository?.unstagedChanges.map(\.path) == [
            "conflict.txt", "ordinary.txt", "partial.txt",
        ])
    }

    @Test
    @MainActor
    func unstagesTheFirstCommitOnAnUnbornBranch() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try Data("first\n".utf8).write(to: repositoryURL.appending(path: "first.txt"))
        _ = try fixture.git(["add", "--", "first.txt"], in: repositoryURL)
        try Data("first\nmodified after staging\n".utf8)
            .write(to: repositoryURL.appending(path: "first.txt"))
        let state = WorkspaceState(repositoryService: service(), launchArguments: ["--ui-testing"])
        await state.handleRepositorySelection(.success(repositoryURL))

        await state.unstageAll()

        #expect(state.repository?.head == .unbornBranch("main"))
        #expect(state.repository?.stagedChanges.isEmpty == true)
        #expect(state.repository?.unstagedChanges == [
            RepositoryChange(path: "first.txt", kind: .untracked),
        ])
    }

    @Test
    @MainActor
    func treatsPathspecMagicAsALiteralFileName() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try Data("ordinary\n".utf8).write(to: repositoryURL.appending(path: "other.txt"))
        try Data("literal\n".utf8).write(to: repositoryURL.appending(path: ":(top)other.txt"))
        let state = WorkspaceState(repositoryService: service(), launchArguments: ["--ui-testing"])
        await state.handleRepositorySelection(.success(repositoryURL))

        let literal = try #require(
            state.repository?.unstagedChanges.first { $0.path == ":(top)other.txt" }
        )
        await state.stage(literal)

        #expect(state.repository?.stagedChanges.map(\.path) == [":(top)other.txt"])
        #expect(state.repository?.unstagedChanges.map(\.path) == ["other.txt"])

        let staged = try #require(state.repository?.stagedChanges.first)
        await state.unstage(staged)

        #expect(state.repository?.stagedChanges.isEmpty == true)
        #expect(state.repository?.unstagedChanges.map(\.path) == [":(top)other.txt", "other.txt"])
    }

    private func service() -> RepositoryService {
        let backend = GitRepositoryService(candidateURLs: [URL(filePath: "/usr/bin/git")])
        return RepositoryService(
            availability: { await backend.availability() },
            load: { try await backend.loadRepository(at: $0) },
            runMutation: { try await backend.runMutation($0, standardInput: $1, in: $2) },
            loadDiff: { try await backend.loadDiff($0) },
            loadHistory: { try await backend.loadHistory($0) },
            loadCommitDetail: { try await backend.loadCommitDetail($0) },
            validateBranchName: { try await backend.validateBranchName($0) },
            loadCheckoutComparison: { try await backend.loadCheckoutComparison($0) },
            loadSkippedRemotes: { try await backend.loadSkippedRemotes(in: $0) },
            loadTagConflicts: { try await backend.loadTagConflicts($0) },
            runNetworkMutation: { try await backend.runNetworkMutation($0, in: $1, responder: $2) }
        )
    }
}
