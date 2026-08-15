////
//  DiffResponsivenessIntegrationTests.swift
//  ColofaGitIntegrationTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// What a Diff limit exists to protect: the Main Actor, while the largest patch Colofa renders is
/// being read from Git and parsed.
///
/// A `nonisolated` declaration states where work is *allowed* to run, and under this project's
/// concurrency settings it does not even state that much: an ordinary `nonisolated async` function
/// runs on whichever actor called it, so what keeps a patch off the Main Actor is the Repository
/// service being an actor of its own. That is what is measured here — the real service, asked for
/// a real patch from the Main Actor exactly as `WorkspaceState` asks, with a Main Actor heartbeat
/// ticking beside it.
@Suite(.serialized)
struct DiffResponsivenessIntegrationTests {
    /// How long the Main Actor may go unserved while the fixture is read and parsed.
    ///
    /// Far above the heartbeat's own interval, so ordinary scheduling jitter cannot reach it, and
    /// far below how long the fixture takes, so a load that held the Main Actor throughout cannot
    /// hide underneath it. A threshold scaled to the load's own duration was neither: it shrank to
    /// the length of a scheduling hiccup exactly when the machine was fast enough to have one.
    private static let allowance = Duration.milliseconds(75)

    /// A line long enough that reading and parsing 90,000 of them costs real time, while the patch
    /// they make stays inside both hard limits — 100,000 lines and 10 MiB, which it fills to about
    /// three quarters — so it is read and parsed in full rather than refused partway through.
    private static let fillerLine =
        "a line of filler text that a patch has to carry in full, from its beginning to its end\n"
    private static let fillerLineCount = 90_000

    /// How long the Main Actor went without running the heartbeat.
    ///
    /// A load that stayed off the Main Actor leaves gaps the size of the heartbeat's own interval;
    /// one that did not leaves a single gap the size of the whole load.
    @MainActor
    private final class Heartbeat {
        private(set) var longestGap = Duration.zero
        private(set) var beats = 0
        private var lastBeat = ContinuousClock.now
        private var beating: Task<Void, Never>?

        private static let interval = Duration.milliseconds(5)

        /// Beats until stopped, returning once the measurement has begun: the wait for the first
        /// beat is not itself a gap in serving the Main Actor.
        func start() async throws {
            beating = Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    self?.beat()
                    try? await Task.sleep(for: Self.interval)
                }
            }
            try await waitForNextBeat()
            lastBeat = .now
            longestGap = .zero
            beats = 0
        }

        /// Records whatever gap is still open before stopping.
        ///
        /// A gap is only measured by the beat that ends it, so a load that held the Main Actor to
        /// its last instant leaves its own gap unrecorded. Stopping the heartbeat the moment the
        /// load returns is how a load that blocked everything reports having blocked nothing.
        func stop() async throws {
            try await waitForNextBeat()
            cancel()
            await beating?.value
        }

        func cancel() {
            beating?.cancel()
        }

        private func beat() {
            let now = ContinuousClock.now
            longestGap = max(longestGap, lastBeat.duration(to: now))
            lastBeat = now
            beats += 1
        }

        private func waitForNextBeat(timeout: Duration = .seconds(10)) async throws {
            let recorded = beats
            let deadline = ContinuousClock.now.advanced(by: timeout)
            while beats == recorded {
                try #require(
                    ContinuousClock.now < deadline,
                    "The Main Actor heartbeat never ran again"
                )
                try await Task.sleep(for: .milliseconds(1))
            }
        }
    }

    @Test
    @MainActor
    func readingAndParsingALargePatchLeavesTheMainActorFree() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try fixture.createCommit(in: repositoryURL)
        try Data(String(repeating: Self.fillerLine, count: Self.fillerLineCount).utf8)
            .write(to: repositoryURL.appending(path: "large.txt"))

        let service = GitRepositoryService(
            candidateURLs: [URL(filePath: "/usr/bin/git")],
            environment: fixture.environment
        )
        let request = DiffLoadRequest(
            source: .untracked(path: "large.txt"),
            repositoryURL: repositoryURL,
            isConfirmed: true
        )
        // Read once without measuring: these tests are hosted by the app, and AppKit's own startup
        // holds the main thread for longer than any bound the load is then held to.
        _ = try await service.loadDiff(request)

        let heartbeat = Heartbeat()
        defer { heartbeat.cancel() }
        try await heartbeat.start()
        let started = ContinuousClock.now
        let result = try await service.loadDiff(request)
        let elapsed = started.duration(to: .now)
        try await heartbeat.stop()

        guard case .diff(let diff) = result else {
            Issue.record("Expected a rendered Diff, got \(result)")
            return
        }
        #expect(diff.stats == DiffStats(additions: Self.fillerLineCount, deletions: 0))
        #expect(
            elapsed > Self.allowance,
            """
            The fixture was read and parsed in \(elapsed), inside the \(Self.allowance) a stall is \
            allowed, so a Main Actor held for the whole load would pass unseen. Grow the fixture.
            """
        )
        #expect(
            heartbeat.longestGap < Self.allowance,
            """
            The Main Actor stalled for \(heartbeat.longestGap) while a patch was read and parsed \
            in \(elapsed)
            """
        )
    }
}
