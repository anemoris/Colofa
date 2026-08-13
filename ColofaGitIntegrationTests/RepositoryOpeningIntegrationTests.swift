////
//  RepositoryOpeningIntegrationTests.swift
//  ColofaGitIntegrationTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

@Suite(.serialized)
struct RepositoryOpeningIntegrationTests {
    @Test
    func opensOrdinaryAndUnbornRepositories() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        let service = GitRepositoryService(candidateURLs: [URL(filePath: "/usr/bin/git")])

        let unborn = try await service.loadRepository(at: repositoryURL)

        #expect(unborn.rootURL == repositoryURL.standardizedFileURL)
        #expect(unborn.gitDirectoryURL == repositoryURL.appending(path: ".git").standardizedFileURL)
        #expect(unborn.head == .unbornBranch("main"))

        _ = try fixture.createCommit(in: repositoryURL)
        let repository = try await service.loadRepository(at: repositoryURL)

        #expect(repository.head == .branch("main"))
    }

    @Test
    func loadsRealReferencesUpstreamAndWorkingTreeProjections() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository(named: "状态 Repo")
        let remoteURL = try fixture.createBareRemote()
        try fixture.addRemote(remoteURL, named: "origin", to: repositoryURL)
        let trackedURL = repositoryURL.appending(path: "partial 文件.txt")
        let renamedURL = repositoryURL.appending(path: "old name.txt")
        let deletedURL = repositoryURL.appending(path: "deleted.txt")
        let typeChangedURL = repositoryURL.appending(path: "type changed.txt")
        try Data("base\n".utf8).write(to: trackedURL)
        try Data("rename me\n".utf8).write(to: renamedURL)
        try Data("delete me\n".utf8).write(to: deletedURL)
        try Data("regular file\n".utf8).write(to: typeChangedURL)
        _ = try fixture.git(["add", "--all"], in: repositoryURL)
        _ = try fixture.git(["commit", "-m", "Base"], in: repositoryURL)
        _ = try fixture.git(["push", "-u", "origin", "main"], in: repositoryURL)
        _ = try fixture.git(["branch", "feature/真实"], in: repositoryURL)
        _ = try fixture.git(["tag", "v1.0-测试"], in: repositoryURL)

        try Data("base\nstaged\n".utf8).write(to: trackedURL)
        _ = try fixture.git(["add", "--", "partial 文件.txt"], in: repositoryURL)
        try Data("added\n".utf8).write(to: repositoryURL.appending(path: "added.txt"))
        _ = try fixture.git(["add", "--", "added.txt"], in: repositoryURL)
        _ = try fixture.git(["mv", "old name.txt", "renamed 名称.txt"], in: repositoryURL)
        try Data("base\nstaged\nunstaged\n".utf8).write(to: trackedURL)
        try FileManager.default.removeItem(at: deletedURL)
        try FileManager.default.removeItem(at: typeChangedURL)
        try FileManager.default.createSymbolicLink(
            at: typeChangedURL,
            withDestinationURL: trackedURL
        )
        try Data("untracked\n".utf8).write(
            to: repositoryURL.appending(path: "emoji 🦄.md")
        )

        let service = GitRepositoryService(
            candidateURLs: [URL(filePath: "/usr/bin/git")],
            environment: fixture.environment
        )
        let repository = try await service.loadRepository(at: repositoryURL)

        #expect(repository.upstream == RepositoryUpstream(name: "origin/main", ahead: 0, behind: 0))
        #expect(repository.localBranches == ["feature/真实", "main"])
        #expect(repository.remoteBranches == ["origin/main"])
        #expect(repository.tags == ["v1.0-测试"])
        #expect(repository.remotes.map(\.name) == ["origin"])
        #expect(
            repository.stagedChanges.map(\.path)
                == ["added.txt", "partial 文件.txt", "renamed 名称.txt"]
        )
        #expect(repository.stagedChanges.last?.kind == .renamed(from: "old name.txt"))
        #expect(
            repository.unstagedChanges.map(\.path)
                == ["deleted.txt", "emoji 🦄.md", "partial 文件.txt", "type changed.txt"]
        )
        #expect(repository.unstagedChanges.first?.kind == .deleted)
        #expect(repository.unstagedChanges.last?.kind == .typeChanged)
        #expect(repository.totalCommitCount == 1)
        #expect(repository.gitObjectSize > 0)
    }

    @Test
    func detectsMergeStateAndSortsConflictFirst() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        let conflictedURL = repositoryURL.appending(path: "conflict.txt")
        try Data("base\n".utf8).write(to: conflictedURL)
        _ = try fixture.git(["add", "--", "conflict.txt"], in: repositoryURL)
        _ = try fixture.git(["commit", "-m", "Base"], in: repositoryURL)
        _ = try fixture.git(["checkout", "-b", "topic"], in: repositoryURL)
        try Data("topic\n".utf8).write(to: conflictedURL)
        _ = try fixture.git(["commit", "-am", "Topic"], in: repositoryURL)
        _ = try fixture.git(["checkout", "main"], in: repositoryURL)
        try Data("main\n".utf8).write(to: conflictedURL)
        _ = try fixture.git(["commit", "-am", "Main"], in: repositoryURL)
        try Data("ordinary\n".utf8).write(
            to: repositoryURL.appending(path: "ordinary.txt")
        )
        do {
            _ = try fixture.git(["merge", "topic"], in: repositoryURL)
            Issue.record("Expected a merge conflict")
        } catch {
            // The conflicted Repository is the fixture this test needs.
        }

        let service = GitRepositoryService(candidateURLs: [URL(filePath: "/usr/bin/git")])
        let repository = try await service.loadRepository(at: repositoryURL)

        #expect(repository.operation == .merge)
        #expect(repository.unstagedChanges.first?.kind == .conflict)
        #expect(repository.unstagedChanges.first?.path == "conflict.txt")
    }

    @Test
    func detectsRebaseGitAmCherryPickAndRevertMetadataAfterRefresh() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        _ = try fixture.createCommit(in: repositoryURL)
        let gitDirectoryURL = repositoryURL.appending(path: ".git", directoryHint: .isDirectory)
        let rebaseDirectoryURL = gitDirectoryURL.appending(
            path: "rebase-merge",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: rebaseDirectoryURL,
            withIntermediateDirectories: false
        )
        let service = GitRepositoryService(candidateURLs: [URL(filePath: "/usr/bin/git")])

        let rebasing = try await service.loadRepository(at: repositoryURL)
        #expect(rebasing.operation == .rebase)

        try FileManager.default.removeItem(at: rebaseDirectoryURL)
        let applyDirectoryURL = gitDirectoryURL.appending(
            path: "rebase-apply",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: applyDirectoryURL,
            withIntermediateDirectories: false
        )
        try Data().write(to: applyDirectoryURL.appending(path: "applying"))

        let applyingMailbox = try await service.loadRepository(at: repositoryURL)
        #expect(applyingMailbox.operation == .am)

        try FileManager.default.removeItem(at: applyDirectoryURL)
        try Data("0123456789abcdef\n".utf8).write(
            to: gitDirectoryURL.appending(path: "CHERRY_PICK_HEAD")
        )

        let cherryPicking = try await service.loadRepository(at: repositoryURL)
        #expect(cherryPicking.operation == .cherryPick)

        try FileManager.default.removeItem(
            at: gitDirectoryURL.appending(path: "CHERRY_PICK_HEAD")
        )
        try Data("0123456789abcdef\n".utf8).write(
            to: gitDirectoryURL.appending(path: "REVERT_HEAD")
        )

        let reverting = try await service.loadRepository(at: repositoryURL)
        #expect(reverting.operation == .revert)
    }

    @Test
    func opensRepositoriesWithSpacesAndNonASCIICharacters() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository(named: "My Repo 项目")
        let service = GitRepositoryService(candidateURLs: [URL(filePath: "/usr/bin/git")])

        let repository = try await service.loadRepository(at: repositoryURL)

        #expect(repository.rootURL == repositoryURL.standardizedFileURL)
        #expect(repository.rootURL.normalizedFilePath.contains("My Repo 项目"))
    }

    @Test
    func ignoresSuccessfulGitDiagnosticsWhenParsingStandardOutput() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        var environment = ProcessInfo.processInfo.environment
        environment["GIT_TRACE"] = "1"
        let service = GitRepositoryService(
            candidateURLs: [URL(filePath: "/usr/bin/git")],
            environment: environment
        )

        let repository = try await service.loadRepository(at: repositoryURL)

        #expect(repository.rootURL == repositoryURL.standardizedFileURL)
        #expect(repository.head == .unbornBranch("main"))
    }

    @Test
    func opensLinkedWorktrees() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        _ = try fixture.createCommit(in: repositoryURL)
        let worktreeURL = try fixture.createLinkedWorktree(from: repositoryURL)
        let service = GitRepositoryService(candidateURLs: [URL(filePath: "/usr/bin/git")])

        let repository = try await service.loadRepository(at: worktreeURL)

        #expect(repository.rootURL == worktreeURL.standardizedFileURL)
        #expect(repository.head == .branch("linked"))
    }

    @Test
    func opensRepositoriesInsideSubmoduleDirectories() async throws {
        let fixture = try GitTestRepository()
        let parentURL = try fixture.createWorkingRepository(named: "parent")
        let submoduleSourceURL = try fixture.createWorkingRepository(named: "submodule-source")
        _ = try fixture.createCommit(in: submoduleSourceURL)
        let submoduleURL = try fixture.addSubmodule(
            submoduleSourceURL,
            named: "Nested",
            to: parentURL
        )
        let service = GitRepositoryService(candidateURLs: [URL(filePath: "/usr/bin/git")])

        let repository = try await service.loadRepository(at: submoduleURL)

        #expect(repository.rootURL == submoduleURL.standardizedFileURL)
        #expect(repository.head == .branch("main"))
    }

    @Test
    func opensDetachedHeadExplicitly() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        let commit = try fixture.createCommit(in: repositoryURL)
        _ = try fixture.git(["checkout", "--detach", commit], in: repositoryURL)
        let service = GitRepositoryService(candidateURLs: [URL(filePath: "/usr/bin/git")])

        let repository = try await service.loadRepository(at: repositoryURL)

        #expect(repository.head == .detached(commit))
    }

    @Test
    func rejectsBareRepositories() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createBareRemote()
        let service = GitRepositoryService(candidateURLs: [URL(filePath: "/usr/bin/git")])

        await #expect(throws: RepositoryOpenError.bareRepository) {
            try await service.loadRepository(at: repositoryURL)
        }
    }

    @Test
    func rejectsFoldersThatAreNotRepositories() async throws {
        let fixture = try GitTestRepository()
        let directoryURL = fixture.rootURL.appending(
            path: "plain-folder",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        let service = GitRepositoryService(candidateURLs: [URL(filePath: "/usr/bin/git")])

        await #expect(throws: RepositoryOpenError.notRepository) {
            try await service.loadRepository(at: directoryURL)
        }
    }

    @Test
    func exposesSanitizedDetailsForCorruptRepositoryMetadata() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try Data("not a valid HEAD\n".utf8).write(
            to: repositoryURL.appending(path: ".git/HEAD")
        )
        let service = GitRepositoryService(candidateURLs: [URL(filePath: "/usr/bin/git")])

        do {
            _ = try await service.loadRepository(at: repositoryURL)
            Issue.record("Expected corrupt metadata to fail")
        } catch RepositoryOpenError.commandFailed(let details) {
            #expect(details.exitStatus != nil)
            #expect(!details.output.contains(repositoryURL.normalizedFilePath))
        }
    }

    @Test
    func reportsUnavailableGit() async {
        let service = GitRepositoryService(
            candidateURLs: [URL(filePath: "/definitely-missing/git")]
        )

        #expect(await service.availability() == .unavailable)
    }

    @Test
    func rejectsAnExecutableThatIsNotGit() async {
        let service = GitRepositoryService(
            candidateURLs: [URL(filePath: "/usr/bin/true")]
        )

        #expect(await service.availability() == .unavailable)
    }

    @Test
    func invalidatesACachedGitExecutableThatDisappears() async throws {
        let fixture = try GitTestRepository()
        let candidateURL = fixture.rootURL.appending(path: "git")
        try FileManager.default.createSymbolicLink(
            at: candidateURL,
            withDestinationURL: URL(filePath: "/usr/bin/git")
        )
        let service = GitRepositoryService(candidateURLs: [candidateURL])

        #expect(await service.availability() == .available(candidateURL))

        try FileManager.default.removeItem(at: candidateURL)

        #expect(await service.availability() == .unavailable)
    }

    @Test
    func serializesMutatingCommands() async throws {
        let fixture = try GitTestRepository()
        let executableURL = fixture.rootURL.appending(path: "recording-git")
        let eventsURL = fixture.rootURL.appending(path: "mutation-events")
        try fixture.createMutationRecordingGit(at: executableURL, eventsURL: eventsURL)
        let service = GitRepositoryService(candidateURLs: [executableURL])

        #expect(await service.availability() == .available(executableURL))

        async let first: Void = service.runMutation(["first"], in: fixture.rootURL)
        async let second: Void = service.runMutation(["second"], in: fixture.rootURL)
        try await first
        try await second

        let events = String(decoding: try Data(contentsOf: eventsURL), as: UTF8.self)
            .split(separator: "\n")
            .map(String.init)
        guard events.count == 4 else {
            Issue.record("Expected two complete mutation intervals, got \(events)")
            return
        }

        #expect(events[0].hasSuffix("-start"))
        #expect(events[1] == events[0].replacing("-start", with: "-end"))
        #expect(events[2].hasSuffix("-start"))
        #expect(events[3] == events[2].replacing("-start", with: "-end"))
    }

    @Test
    func sanitizesCommandFailureDetails() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository(named: "My Repo 项目")
        let service = GitRepositoryService(candidateURLs: [URL(filePath: "/usr/bin/git")])
        let missingPath = repositoryURL
            .appending(path: "missing-file")
            .normalizedFilePath

        do {
            try await service.runMutation(
                ["add", "--", missingPath],
                in: repositoryURL
            )
            Issue.record("Expected Git to reject the missing path")
        } catch RepositoryOpenError.commandFailed(let details) {
            #expect(details.command.contains("\"git\" \"add\""))
            #expect(details.command.contains("<Repository>/missing-file"))
            #expect(!details.command.contains(repositoryURL.normalizedFilePath))
            #expect(!details.output.contains(repositoryURL.normalizedFilePath))
            #expect(!details.output.contains("\0"))
            #expect(details.output.count <= 4_000)
        }
    }
}
