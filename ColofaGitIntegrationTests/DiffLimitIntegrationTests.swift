////
//  DiffLimitIntegrationTests.swift
//  ColofaGitIntegrationTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// The limits, exercised against real patches whose exact size is measured first.
@Suite(.serialized)
struct DiffLimitIntegrationTests {
    /// Which answer a patch of a given size got, named so the boundary expectations read as the
    /// rule they are checking.
    private enum SizeClass: Equatable {
        case automatic
        case confirmationRequired
        case beyondHardLimit
    }

    @Test
    func stopsReadingAtTheHardLimitInsteadOfDrainingThePatch() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try fixture.createCommit(in: repositoryURL)
        // Far larger than the bound below, so a loader that read to the end would be obvious.
        try write(
            String(repeating: "a line of filler text\n", count: 400_000),
            to: "big.txt",
            in: repositoryURL
        )

        let source = DiffSource.untracked(path: "big.txt")
        let result = try await diffLoader(fixture).load(
            DiffLoadRequest(
                source: source,
                repositoryURL: repositoryURL,
                limits: DiffLimits(
                    automaticByteCount: 1_024,
                    automaticLineCount: 16,
                    hardByteCount: 64 * 1_024,
                    hardLineCount: 1_024
                )
            )
        )

        guard case .beyondHardLimit(let summary) = result else {
            Issue.record("Expected a refusal, got \(result)")
            return
        }
        #expect(!summary.measurement.isComplete)
        // Stopping happens on a chunk boundary, so the count may overshoot by one chunk at most.
        #expect(summary.measurement.byteCount < 64 * 1_024 + 128 * 1_024)
        // Git still counts the lines it never had to write out.
        #expect(summary.stats == DiffStats(additions: 400_000, deletions: 0))
    }

    /// Cancelling the task that is reading a Diff has to end Git rather than let it finish
    /// writing a patch nobody is waiting for.
    ///
    /// The command is a controlled slow one rather than real Git: it writes a line, reports that
    /// it is running, and then blocks. Cancellation therefore arrives at a command that is known
    /// to be running, and how long the answer takes is a fact about cancellation rather than
    /// about the machine's speed.
    @Test
    func cancellingAReadEndsGitInsteadOfWaitingItOut() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        let slowGitURL = fixture.rootURL.appending(path: "slow-git")
        let readyURL = fixture.rootURL.appending(path: "slow-git-ready")
        // Far longer than the assertion below allows, so waiting it out cannot pass.
        try fixture.createSlowGit(at: slowGitURL, seconds: 30, readyURL: readyURL)

        let loader = GitDiffLoader(
            git: GitProcess(executableURL: slowGitURL, environment: fixture.environment)
        )
        let read = Task {
            try await loader.load(
                DiffLoadRequest(
                    source: .workingTree(paths: ["slow.txt"]),
                    repositoryURL: repositoryURL
                )
            )
        }
        // Waiting for the stand-in's own signal rather than a fixed delay: on a slow machine a
        // timed wait can cancel a task that has not reached the blocking read yet, which would
        // pass without exercising anything.
        try await fixture.waitForReadySignal(at: readyURL)
        read.cancel()

        let started = ContinuousClock.now
        let result = await read.result
        let elapsed = started.duration(to: .now)

        // A cut-off read must be reported as cancelled, never handed back as a whole patch.
        #expect(throws: CancellationError.self) { try result.get() }
        #expect(elapsed < .seconds(5), "A cancelled read took \(elapsed) to come back")
    }

    @Test
    func decidesEachLimitByItsExactBoundary() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try sizedRepository(fixture, line: "boundary line\n")
        let source = DiffSource.workingTree(paths: ["sized.txt"])

        // The patch Git actually writes, measured independently of the loader that bounds it.
        let patch = try fixture.rawGit(
            GitDiffCommand.patch(for: source).arguments,
            in: repositoryURL
        )
        let byteCount = Data(patch.utf8).count
        let lineCount = patch.count(where: { $0 == "\n" })
        let loader = diffLoader(fixture)

        func sizeClass(_ limits: DiffLimits) async throws -> SizeClass {
            switch try await loader.load(
                DiffLoadRequest(source: source, repositoryURL: repositoryURL, limits: limits)
            ) {
            case .diff: .automatic
            case .confirmationRequired: .confirmationRequired
            case .beyondHardLimit: .beyondHardLimit
            }
        }

        // Bytes, immediately below the patch, exactly at it, and immediately above it.
        #expect(try await sizeClass(automatic(bytes: byteCount - 1)) == .confirmationRequired)
        #expect(try await sizeClass(automatic(bytes: byteCount)) == .automatic)
        #expect(try await sizeClass(automatic(bytes: byteCount + 1)) == .automatic)
        #expect(try await sizeClass(hard(bytes: byteCount - 1)) == .beyondHardLimit)
        #expect(try await sizeClass(hard(bytes: byteCount)) == .confirmationRequired)
        #expect(try await sizeClass(hard(bytes: byteCount + 1)) == .confirmationRequired)

        // Lines, on the same three points.
        #expect(try await sizeClass(automatic(lines: lineCount - 1)) == .confirmationRequired)
        #expect(try await sizeClass(automatic(lines: lineCount)) == .automatic)
        #expect(try await sizeClass(automatic(lines: lineCount + 1)) == .automatic)
        #expect(try await sizeClass(hard(lines: lineCount - 1)) == .beyondHardLimit)
        #expect(try await sizeClass(hard(lines: lineCount)) == .confirmationRequired)
        #expect(try await sizeClass(hard(lines: lineCount + 1)) == .confirmationRequired)
    }

    @Test
    func rendersAConfirmedPatchOnlyUpToTheHardLimit() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try sizedRepository(fixture, line: "confirmed line\n")
        let source = DiffSource.workingTree(paths: ["sized.txt"])
        let loader = diffLoader(fixture)
        let offered = DiffLimits(
            automaticByteCount: 16,
            automaticLineCount: 4,
            hardByteCount: 1_024 * 1_024,
            hardLineCount: 100_000
        )

        let unconfirmed = try await loader.load(
            DiffLoadRequest(source: source, repositoryURL: repositoryURL, limits: offered)
        )
        let confirmed = try await loader.load(
            DiffLoadRequest(
                source: source,
                repositoryURL: repositoryURL,
                limits: offered,
                isConfirmed: true
            )
        )

        guard case .confirmationRequired(let summary) = unconfirmed,
              case .diff(let diff) = confirmed else {
            Issue.record("Expected an offer then a rendered Diff, got \(unconfirmed), \(confirmed)")
            return
        }
        #expect(summary.measurement.isComplete)
        #expect(summary.stats == DiffStats(additions: 64, deletions: 0))
        #expect(diff.stats == DiffStats(additions: 64, deletions: 0))
        #expect(diff.measurement.byteCount == summary.measurement.byteCount)
    }

    /// A Repository whose only working-tree change is one sized text file, so its patch can be
    /// measured exactly and compared against each limit.
    private func sizedRepository(_ fixture: GitTestRepository, line: String) throws -> URL {
        let repositoryURL = try fixture.createWorkingRepository()
        try write(String(repeating: line, count: 64), to: "sized.txt", in: repositoryURL)
        _ = try fixture.git(["add", "--all"], in: repositoryURL)
        _ = try fixture.git(["commit", "-m", "Base"], in: repositoryURL)
        try write(String(repeating: line, count: 128), to: "sized.txt", in: repositoryURL)
        return repositoryURL
    }

    /// Only the automatic limit under test can be reached; the hard one is left out of reach.
    private func automatic(bytes: Int = .max, lines: Int = .max) -> DiffLimits {
        DiffLimits(
            automaticByteCount: bytes,
            automaticLineCount: lines,
            hardByteCount: .max,
            hardLineCount: .max
        )
    }

    /// The automatic limit is deliberately unreachable, so only the hard limit under test decides.
    private func hard(bytes: Int = .max, lines: Int = .max) -> DiffLimits {
        DiffLimits(
            automaticByteCount: 0,
            automaticLineCount: 0,
            hardByteCount: bytes,
            hardLineCount: lines
        )
    }

    private func diffLoader(_ fixture: GitTestRepository) -> GitDiffLoader {
        GitDiffLoader(
            git: GitProcess(
                executableURL: URL(filePath: "/usr/bin/git"),
                environment: fixture.environment
            )
        )
    }
    private func write(_ contents: String, to path: String, in repositoryURL: URL) throws {
        try Data(contents.utf8).write(to: repositoryURL.appending(path: path))
    }
}
