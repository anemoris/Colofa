////
//  DiffIntegrationTests.swift
//  ColofaGitIntegrationTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

@Suite(.serialized)
struct DiffIntegrationTests {
    @Test
    @MainActor
    func readsStagedAndUnstagedTextDiffsSeparately() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try write("one\ntwo\nthree\n", to: "notes.txt", in: repositoryURL)
        _ = try fixture.git(["add", "--all"], in: repositoryURL)
        _ = try fixture.git(["commit", "-m", "Base"], in: repositoryURL)

        try write("one\nSTAGED\nthree\n", to: "notes.txt", in: repositoryURL)
        _ = try fixture.git(["add", "--", "notes.txt"], in: repositoryURL)
        try write("one\nSTAGED\nWORKING\n", to: "notes.txt", in: repositoryURL)

        let state = await openedWorkspace(fixture, at: repositoryURL)

        state.selectedChange = RepositoryChangeSelection(path: "notes.txt", isStaged: true)
        await state.loadDiff()
        let staged = try #require(loadedDiff(state))
        #expect(staged.stats == DiffStats(additions: 1, deletions: 1))
        #expect(
            staged.files.first?.hunks.first?.lines.filter { $0.kind == .addition }.map(\.text)
                == ["STAGED"]
        )

        state.selectedChange = RepositoryChangeSelection(path: "notes.txt", isStaged: false)
        await state.loadDiff()
        let unstaged = try #require(loadedDiff(state))
        #expect(
            unstaged.files.first?.hunks.first?.lines.filter { $0.kind == .addition }.map(\.text)
                == ["WORKING"]
        )
    }

    @Test
    @MainActor
    func readsAnUntrackedPathAgainstNothing() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try fixture.createCommit(in: repositoryURL)
        try write("first\nsecond\n", to: "untracked 名称.txt", in: repositoryURL)

        let state = await openedWorkspace(fixture, at: repositoryURL)
        state.selectedChange = RepositoryChangeSelection(
            path: "untracked 名称.txt",
            isStaged: false
        )
        await state.loadDiff()

        let diff = try #require(loadedDiff(state))
        #expect(diff.files.first?.oldPath == nil)
        #expect(diff.files.first?.newPath == "untracked 名称.txt")
        #expect(diff.stats == DiffStats(additions: 2, deletions: 0))
    }

    /// `diff.noPrefix` drops the `a/` and `b/` prefixes and `diff.mnemonicPrefix` replaces them
    /// with `i/` and `w/`. The header naming both paths at once is only separable by them, so a
    /// Diff that inherited either setting would lose a binary change's path and leave the
    /// mnemonic letter on every other one.
    @Test
    @MainActor
    func readsPathsWhateverTheRepositoryConfiguredDiffPrefixesToBe() async throws {
        for setting in ["diff.noPrefix", "diff.mnemonicPrefix"] {
            let fixture = try GitTestRepository()
            let repositoryURL = try fixture.createWorkingRepository()
            try write("one\ntwo\n", to: "notes.txt", in: repositoryURL)
            try Data([0x00, 0x01, 0x02, 0xFF]).write(
                to: repositoryURL.appending(path: "image.bin")
            )
            _ = try fixture.git(["add", "--all"], in: repositoryURL)
            _ = try fixture.git(["commit", "-m", "Base"], in: repositoryURL)
            _ = try fixture.git(["config", setting, "true"], in: repositoryURL)

            try write("one\nchanged\n", to: "notes.txt", in: repositoryURL)
            try Data([0x00, 0xFE, 0x02, 0xFF, 0x10]).write(
                to: repositoryURL.appending(path: "image.bin")
            )

            let state = await openedWorkspace(fixture, at: repositoryURL)
            state.selectedChange = RepositoryChangeSelection(path: "notes.txt", isStaged: false)
            await state.loadDiff()
            #expect(loadedDiff(state)?.files.first?.newPath == "notes.txt", "with \(setting)")

            // A binary change has no `---`/`+++` lines, so only the two-path header names it.
            state.selectedChange = RepositoryChangeSelection(path: "image.bin", isStaged: false)
            await state.loadDiff()
            let binary = try #require(loadedDiff(state)?.files.first)
            #expect(binary.newPath == "image.bin", "with \(setting)")
            #expect(binary.content == .binary, "with \(setting)")
        }
    }

    /// `git diff --no-index` reports both "these differ" and "I could not read that" as status 1,
    /// and only the second writes to standard error. Without that distinction an untracked file
    /// deleted from under the selection would come back as a Diff with nothing in it.
    @Test
    @MainActor
    func anUntrackedPathThatVanishedFailsRatherThanReadingAsAnEmptyDiff() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try fixture.createCommit(in: repositoryURL)
        try write("first\n", to: "untracked.txt", in: repositoryURL)

        let state = await openedWorkspace(fixture, at: repositoryURL)
        state.selectedChange = RepositoryChangeSelection(path: "untracked.txt", isStaged: false)
        await state.loadDiff()
        #expect(loadedDiff(state)?.stats == DiffStats(additions: 1, deletions: 0))

        // Gone from disk, but still the selection: the Repository has not been read again.
        try FileManager.default.removeItem(at: repositoryURL.appending(path: "untracked.txt"))
        await state.loadDiff()

        guard case .failed = state.diff else {
            Issue.record("Expected a stable error, got \(String(describing: state.diff))")
            return
        }
    }

    @Test
    @MainActor
    func showsBothPathsOfARename() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try write("kept\nkept\nkept\nold tail\n", to: "old name.txt", in: repositoryURL)
        _ = try fixture.git(["add", "--all"], in: repositoryURL)
        _ = try fixture.git(["commit", "-m", "Base"], in: repositoryURL)
        _ = try fixture.git(["mv", "old name.txt", "new 名称.txt"], in: repositoryURL)
        try write("kept\nkept\nkept\nnew tail\n", to: "new 名称.txt", in: repositoryURL)
        _ = try fixture.git(["add", "--all"], in: repositoryURL)

        let state = await openedWorkspace(fixture, at: repositoryURL)
        state.selectedChange = RepositoryChangeSelection(path: "new 名称.txt", isStaged: true)
        await state.loadDiff()

        let file = try #require(loadedDiff(state)?.files.first)
        #expect(file.oldPath == "old name.txt")
        #expect(file.newPath == "new 名称.txt")
        #expect(file.isRenamed)
    }

    @Test
    @MainActor
    func showsBinaryContentAsMetadataRatherThanText() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        let binaryURL = repositoryURL.appending(path: "image.bin")
        try Data([0x00, 0x01, 0x02, 0xFF]).write(to: binaryURL)
        _ = try fixture.git(["add", "--all"], in: repositoryURL)
        _ = try fixture.git(["commit", "-m", "Base"], in: repositoryURL)
        try Data([0x00, 0xFE, 0x02, 0xFF, 0x10]).write(to: binaryURL)

        let state = await openedWorkspace(fixture, at: repositoryURL)
        state.selectedChange = RepositoryChangeSelection(path: "image.bin", isStaged: false)
        await state.loadDiff()

        let file = try #require(loadedDiff(state)?.files.first)
        #expect(file.content == .binary)
        #expect(file.newPath == "image.bin")
    }

    /// `diff.submodule=log` makes Git describe a submodule with a `Submodule <path> <a>..<b>:`
    /// summary and its Commit subjects instead of a patch, so a Diff that inherited the setting
    /// would have no Commit IDs to show and nothing it could parse.
    @Test
    @MainActor
    func showsBothCommitIDsWhateverTheRepositoryConfiguredSubmoduleFormatToBe() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try fixture.createCommit(in: repositoryURL)
        let moduleSourceURL = try fixture.createWorkingRepository(named: "module-source")
        let firstCommit = try fixture.createCommit(in: moduleSourceURL)
        let submoduleURL = try fixture.addSubmodule(
            moduleSourceURL,
            named: "vendor",
            to: repositoryURL
        )
        _ = try fixture.git(["commit", "-m", "Add submodule"], in: repositoryURL)
        _ = try fixture.git(["config", "diff.submodule", "log"], in: repositoryURL)

        try write("moved\n", to: "second.txt", in: submoduleURL)
        _ = try fixture.git(["add", "--all"], in: submoduleURL)
        _ = try fixture.git(["commit", "-m", "Move submodule"], in: submoduleURL)
        let secondCommit = try fixture.git(["rev-parse", "HEAD"], in: submoduleURL)

        let state = await openedWorkspace(fixture, at: repositoryURL)
        state.selectedChange = RepositoryChangeSelection(path: "vendor", isStaged: false)
        await state.loadDiff()

        let file = try #require(loadedDiff(state)?.files.first)
        #expect(file.content == .submodule(oldCommitID: firstCommit, newCommitID: secondCommit))
    }

    @Test
    @MainActor
    func showsBothCommitIDsOfASubmoduleChange() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try fixture.createCommit(in: repositoryURL)
        let moduleSourceURL = try fixture.createWorkingRepository(named: "module-source")
        let firstCommit = try fixture.createCommit(in: moduleSourceURL)
        let submoduleURL = try fixture.addSubmodule(
            moduleSourceURL,
            named: "vendor",
            to: repositoryURL
        )
        _ = try fixture.git(["commit", "-m", "Add submodule"], in: repositoryURL)

        try write("moved\n", to: "second.txt", in: submoduleURL)
        _ = try fixture.git(["add", "--all"], in: submoduleURL)
        _ = try fixture.git(["commit", "-m", "Move submodule"], in: submoduleURL)
        let secondCommit = try fixture.git(["rev-parse", "HEAD"], in: submoduleURL)

        let state = await openedWorkspace(fixture, at: repositoryURL)
        state.selectedChange = RepositoryChangeSelection(path: "vendor", isStaged: false)
        await state.loadDiff()

        let file = try #require(loadedDiff(state)?.files.first)
        #expect(file.content == .submodule(oldCommitID: firstCommit, newCommitID: secondCommit))
    }

    @Test
    @MainActor
    func reportsAModeOnlyChangeWithoutInventingLines() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        let scriptURL = repositoryURL.appending(path: "script.sh")
        try write("echo hello\n", to: "script.sh", in: repositoryURL)
        _ = try fixture.git(["add", "--all"], in: repositoryURL)
        _ = try fixture.git(["commit", "-m", "Base"], in: repositoryURL)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: scriptURL.normalizedFilePath
        )

        let state = await openedWorkspace(fixture, at: repositoryURL)
        state.selectedChange = RepositoryChangeSelection(path: "script.sh", isStaged: false)
        await state.loadDiff()

        let file = try #require(loadedDiff(state)?.files.first)
        // The mode is the whole change, so Git has no lines to show and Colofa invents none.
        #expect(file.content == .text([]))
        #expect(file.changedMode?.old == "100644")
        #expect(file.changedMode?.new == "100755")
    }

    @Test
    @MainActor
    func aSelectedPathThatDisappearsReloadsWithoutStaleContent() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try write("one\ntwo\n", to: "notes.txt", in: repositoryURL)
        _ = try fixture.git(["add", "--all"], in: repositoryURL)
        _ = try fixture.git(["commit", "-m", "Base"], in: repositoryURL)
        try write("one\nchanged\n", to: "notes.txt", in: repositoryURL)

        let state = await openedWorkspace(fixture, at: repositoryURL)
        state.selectedChange = RepositoryChangeSelection(path: "notes.txt", isStaged: false)
        await state.loadDiff()
        #expect(loadedDiff(state)?.stats == DiffStats(additions: 1, deletions: 1))

        try FileManager.default.removeItem(at: repositoryURL.appending(path: "notes.txt"))
        await state.refresh()
        await state.loadDiff()

        let selection = RepositoryChangeSelection(path: "notes.txt", isStaged: false)
        #expect(state.change(for: selection)?.kind == .deleted)
        #expect(loadedDiff(state)?.stats == DiffStats(additions: 0, deletions: 2))
        #expect(state.diffFileURL == nil)
    }

    @MainActor
    private func loadedDiff(_ state: WorkspaceState) -> Diff? {
        if case .loaded(let diff) = state.diff {
            diff
        } else {
            nil
        }
    }

    private func write(_ contents: String, to path: String, in repositoryURL: URL) throws {
        try Data(contents.utf8).write(to: repositoryURL.appending(path: path))
    }
}
