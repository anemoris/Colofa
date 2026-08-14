////
//  CommitIntegrationTests.swift
//  ColofaGitIntegrationTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

@Suite(.serialized)
struct CommitIntegrationTests {
    @Test
    @MainActor
    func commitContainsExactlyTheIndexAndLeavesUnstagedContentUntouched() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try fixture.createCommit(in: repositoryURL)
        let stagedURL = repositoryURL.appending(path: "staged.txt")
        try Data("staged\n".utf8).write(to: stagedURL)
        _ = try fixture.git(["add", "--", "staged.txt"], in: repositoryURL)
        // Written after staging, so the index and the working tree deliberately disagree.
        try Data("staged\nnot in the index\n".utf8).write(to: stagedURL)
        try Data("untracked\n".utf8).write(to: repositoryURL.appending(path: "untracked.txt"))

        let state = await openedWorkspace(fixture, at: repositoryURL)
        state.commitDraft.summary = "Add staged content"
        state.commitDraft.body = "Why it exists."
        await state.commit()

        #expect(
            try fixture.git(["show", "--name-only", "--format=", "HEAD"], in: repositoryURL)
                == "staged.txt"
        )
        #expect(try fixture.git(["show", "HEAD:staged.txt"], in: repositoryURL) == "staged")
        #expect(
            try fixture.git(["log", "--max-count=1", "--format=%B"], in: repositoryURL)
                == "Add staged content\n\nWhy it exists."
        )
        #expect(state.commitDraft == CommitMessageDraft())
        #expect(state.repository?.stagedChanges.isEmpty == true)
        #expect(state.repository?.unstagedChanges.map(\.path) == [
            "staged.txt", "untracked.txt",
        ])
        #expect(state.repository?.headCommit?.summary == "Add staged content")
        #expect(state.repository?.headCommit?.body == "Why it exists.")
        #expect(state.repository?.totalCommitCount == 2)
    }

    @Test
    @MainActor
    func commitWorksAsTheFirstCommitOnAnUnbornBranch() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try Data("first\n".utf8).write(to: repositoryURL.appending(path: "first.txt"))
        _ = try fixture.git(["add", "--", "first.txt"], in: repositoryURL)

        let state = await openedWorkspace(fixture, at: repositoryURL)
        #expect(state.repository?.head == .unbornBranch("main"))
        #expect(state.repository?.headCommit == nil)
        #expect(!state.canAmend)

        state.commitDraft.summary = "First commit"
        await state.commit()

        #expect(state.repository?.head == .branch("main"))
        #expect(state.repository?.totalCommitCount == 1)
        #expect(state.repository?.headCommit?.summary == "First commit")
        #expect(
            try fixture.git(["show", "--name-only", "--format=", "HEAD"], in: repositoryURL)
                == "first.txt"
        )
    }

    @Test
    @MainActor
    func configuredHooksRunAndReceiveTheMessage() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        let eventsURL = fixture.rootURL.appending(path: "hook-events")
        try writeHook(
            "pre-commit",
            in: repositoryURL,
            script: """
            echo "pre-commit" >> "\(eventsURL.normalizedFilePath)"
            """
        )
        try writeHook(
            "commit-msg",
            in: repositoryURL,
            script: """
            cat "$1" >> "\(eventsURL.normalizedFilePath)"
            """
        )
        try Data("hooked\n".utf8).write(to: repositoryURL.appending(path: "hooked.txt"))
        _ = try fixture.git(["add", "--", "hooked.txt"], in: repositoryURL)

        let state = await openedWorkspace(fixture, at: repositoryURL)
        state.commitDraft.summary = "Hooked commit"
        await state.commit()

        #expect(try String(contentsOf: eventsURL, encoding: .utf8) == "pre-commit\nHooked commit\n")
        #expect(state.repository?.totalCommitCount == 1)
    }

    @Test
    @MainActor
    func aFailingHookLeavesHeadUnchangedAndSanitizesItsOutput() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try fixture.createCommit(in: repositoryURL)
        let headBefore = try fixture.git(["rev-parse", "HEAD"], in: repositoryURL)
        try writeHook(
            "pre-commit",
            in: repositoryURL,
            script: """
            echo "refused inside $(git rev-parse --show-toplevel)" >&2
            exit 1
            """
        )
        try Data("rejected\n".utf8).write(to: repositoryURL.appending(path: "rejected.txt"))
        _ = try fixture.git(["add", "--", "rejected.txt"], in: repositoryURL)

        let state = await openedWorkspace(fixture, at: repositoryURL)
        state.commitDraft.summary = "Rejected commit"
        await state.commit()

        #expect(try fixture.git(["rev-parse", "HEAD"], in: repositoryURL) == headBefore)
        #expect(state.repository?.stagedChanges.map(\.path) == ["rejected.txt"])
        #expect(state.commitDraft.summary == "Rejected commit")

        guard case .mutationAlert(let error, let title) = state.repositoryFailure,
              let details = error.failureDetails else {
            Issue.record("Expected a Commit failure carrying the hook output")
            return
        }
        #expect(title == .commitFailed)
        #expect(details.output.contains("refused inside <Repository>"))
        #expect(!details.output.contains(repositoryURL.normalizedFilePath))
    }

    /// The message is the user's own text, so it travels on standard input and must not reappear
    /// in the command or output Colofa shows after a failure.
    @Test
    @MainActor
    func aFailedCommitNeverSerializesTheMessage() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try writeHook("pre-commit", in: repositoryURL, script: "exit 1")
        try Data("rejected\n".utf8).write(to: repositoryURL.appending(path: "rejected.txt"))
        _ = try fixture.git(["add", "--", "rejected.txt"], in: repositoryURL)

        let state = await openedWorkspace(fixture, at: repositoryURL)
        state.commitDraft.summary = "Remove the token AKIAIOSFODNN7EXAMPLE"
        state.commitDraft.body = "It was pasted into the message by mistake."
        await state.commit()

        guard case .mutationAlert(let error, _) = state.repositoryFailure,
              let details = error.failureDetails else {
            Issue.record("Expected a Commit failure")
            return
        }
        #expect(details.command == "\"git\" \"commit\" \"--file=-\"")
        #expect(!details.command.contains("AKIAIOSFODNN7EXAMPLE"))
        #expect(!details.output.contains("AKIAIOSFODNN7EXAMPLE"))
        #expect(!details.output.contains("pasted into the message"))
    }

    @Test
    @MainActor
    func aFailingHookCannotEchoTheCommitMessageIntoDiagnostics() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try writeHook(
            "commit-msg",
            in: repositoryURL,
            script: "echo \"latest diagnostic; rejected summary: $(sed -n '1p' \"$1\")\" >&2; exit 1"
        )
        try Data("rejected\n".utf8).write(to: repositoryURL.appending(path: "rejected.txt"))
        _ = try fixture.git(["add", "--", "rejected.txt"], in: repositoryURL)

        let state = await openedWorkspace(fixture, at: repositoryURL)
        state.commitDraft.summary = "test"
        await state.commit()

        guard case .mutationAlert(let error, _) = state.repositoryFailure,
              let output = error.failureDetails?.output else {
            Issue.record("Expected a Commit failure")
            return
        }
        #expect(output.contains("latest diagnostic; rejected summary: <Sensitive Input>"))
        #expect(!output.contains("summary: test"))
    }

    @Test
    @MainActor
    func configuredSigningRunsAndItsFailureLeavesHeadUnchanged() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try fixture.createCommit(in: repositoryURL)
        let headBefore = try fixture.git(["rev-parse", "HEAD"], in: repositoryURL)
        let eventsURL = fixture.rootURL.appending(path: "signing-events")
        let signingURL = fixture.rootURL.appending(path: "failing-gpg")
        try writeExecutable(
            at: signingURL,
            script: """
            echo "signing requested" >> "\(eventsURL.normalizedFilePath)"
            echo "no secret key" >&2
            exit 2
            """
        )
        _ = try fixture.git(["config", "--local", "commit.gpgsign", "true"], in: repositoryURL)
        _ = try fixture.git(
            ["config", "--local", "gpg.program", signingURL.normalizedFilePath],
            in: repositoryURL
        )
        try Data("signed\n".utf8).write(to: repositoryURL.appending(path: "signed.txt"))
        _ = try fixture.git(["add", "--", "signed.txt"], in: repositoryURL)

        let state = await openedWorkspace(fixture, at: repositoryURL)
        state.commitDraft.summary = "Signed commit"
        await state.commit()

        #expect(try String(contentsOf: eventsURL, encoding: .utf8) == "signing requested\n")
        #expect(try fixture.git(["rev-parse", "HEAD"], in: repositoryURL) == headBefore)
        #expect(state.repository?.stagedChanges.map(\.path) == ["signed.txt"])
        #expect(state.commitDraft.summary == "Signed commit")
    }
}
