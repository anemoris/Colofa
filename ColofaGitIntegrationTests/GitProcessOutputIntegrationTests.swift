////
//  GitProcessOutputIntegrationTests.swift
//  ColofaGitIntegrationTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// What happens when Git writes more than a pipe can hold, which only a real process can prove.
///
/// A pipe stops accepting writes at the operating system's buffer size, so Git blocks until
/// something empties it. Every read below therefore has to outlive that boundary rather than
/// stopping at it: an unread pipe is a Git that never exits, and a Git that never exits is an
/// app that never answers.
@Suite(.serialized)
struct GitProcessOutputIntegrationTests {
    private static let gitURL = URL(filePath: "/usr/bin/git")

    /// Comfortably past the 64 KiB a pipe holds on macOS, so the boundary is crossed rather than
    /// approached.
    private static let pipeBufferSize = 64 * 1_024

    private func git(_ fixture: GitTestRepository) -> GitProcess {
        GitProcess(executableURL: Self.gitURL, environment: fixture.environment)
    }

    /// The plain read returns every byte Git wrote, not the first pipeful of them.
    @Test
    func readsStandardOutputLargerThanThePipeBuffer() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        let contents = String(repeating: "colofa\n", count: Self.pipeBufferSize)
        try Data(contents.utf8).write(to: repositoryURL.appending(path: "large.txt"))
        try fixture.git(["add", "--", "large.txt"], in: repositoryURL)
        try fixture.git(["commit", "-m", "Add large"], in: repositoryURL)

        let output = try await git(fixture).data(["show", "HEAD:large.txt"], in: repositoryURL)

        #expect(output.count > Self.pipeBufferSize)
        #expect(output == Data(contents.utf8))
    }

    /// A limit bounds what is kept, never what is read: Git still gets to write the rest, so the
    /// command ends instead of blocking on a pipe nobody is emptying.
    @Test
    func keepsOnlyTheLimitWhileStillLettingGitFinish() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        let contents = String(repeating: "colofa\n", count: Self.pipeBufferSize)
        try Data(contents.utf8).write(to: repositoryURL.appending(path: "large.txt"))
        try fixture.git(["add", "--", "large.txt"], in: repositoryURL)
        try fixture.git(["commit", "-m", "Add large"], in: repositoryURL)

        let output = try await git(fixture).data(
            ["show", "HEAD:large.txt"],
            in: repositoryURL,
            outputLimit: 4_000
        )

        #expect(output.count == 4_000)
        #expect(output == Data(contents.utf8.prefix(4_000)))
    }

    /// The Repository read itself crosses the boundary as soon as a working tree holds enough
    /// untracked paths, which is what a `.gitignore` that stops covering a build directory does.
    @Test
    func opensArepositoryWhoseStatusOutputExceedsThePipeBuffer() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try fixture.createCommit(in: repositoryURL)
        let untrackedCount = try createUntrackedFiles(1_200, in: repositoryURL)

        // Stated rather than assumed: a shorter path or a smaller count would quietly stop
        // testing the boundary this test exists for.
        let status = try fixture.rawGit(
            ["status", "--porcelain=v2", "-z", "--untracked-files=all"],
            in: repositoryURL
        )
        #expect(status.utf8.count > Self.pipeBufferSize)

        let snapshot = try await GitRepositoryService(
            candidateURLs: [Self.gitURL],
            environment: fixture.environment
        ).loadRepository(at: repositoryURL)

        #expect(snapshot.head == .branch("main"))
        #expect(snapshot.unstagedChanges.count == untrackedCount)
        #expect(snapshot.unstagedChanges.allSatisfy { $0.kind == .untracked })
    }

    /// - Returns: How many files were written, so the assertion counts the fixture rather than
    ///   repeating its size.
    @discardableResult
    private func createUntrackedFiles(_ count: Int, in repositoryURL: URL) throws -> Int {
        let directoryURL = repositoryURL
            .appending(path: "untracked/deeply/nested/generated-build-output", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        for index in 0..<count {
            try Data().write(
                to: directoryURL.appending(path: "generated-artifact-\(index)-2CJKQ1PZ4LFR7.tmp")
            )
        }
        return count
    }
}
