////
//  UITestingSlowDiff.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

#if DEBUG
import Foundation

/// The handshake between the app and a UI test over the one Diff the stub does not answer at once.
///
/// A fixed delay is a race at any length: too short and a loaded machine misses the state the test
/// came to see, too long and every run pays for it whether it needed to or not. The stub holds the
/// read open instead, and the test releases it once it has observed the pane reporting that it is
/// reading — so the loading state is watched rather than caught.
///
/// This file is compiled into both the app and the UI test target, keeping both processes on the
/// same contract. The signal is a file inside the Repository directory the test created, because
/// the two sides are separate processes and that directory is removed when the test ends.
///
/// Declared `nonisolated` because the project defaults to Main Actor isolation while the stubbed
/// Repository service answers from an actor.
nonisolated enum UITestingSlowDiff {
    /// How long the stub holds a read open before answering anyway, so a test that fails before
    /// releasing the read does not leave the app waiting for a signal that is no longer coming.
    private static let timeout = Duration.seconds(30)

    private static let pollingInterval = Duration.milliseconds(20)

    private static let fileName = ".colofa-ui-testing-slow-diff-released"

    static func releaseURL(in repositoryURL: URL) -> URL {
        repositoryURL.appending(path: fileName)
    }

    /// The app's side: returns once the test has released the read, or once `timeout` has passed.
    static func waitForRelease(in repositoryURL: URL) async throws {
        let path = releaseURL(in: repositoryURL).path(percentEncoded: false)
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while !FileManager.default.fileExists(atPath: path), ContinuousClock.now < deadline {
            try await Task.sleep(for: pollingInterval)
        }
    }

    /// The test's side: lets the held read finish.
    static func release(in repositoryURL: URL) throws {
        try Data().write(to: releaseURL(in: repositoryURL))
    }
}
#endif
