////
//  DiffWorkspaceFactory.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// A Repository whose Changes cover one Diff answer each: rendered, offered, refused, and
/// conflicted.
///
/// Shared by the Diff suites so a case about the pane says only what it changes, and so two
/// Repositories can report the very same paths.
let diffRepositoryURL = URL(filePath: "/tmp/colofa-diff-tests")

/// A second Repository reporting the same paths, which is what makes a patch or a confirmation
/// that carried over from the first one visible.
let otherDiffRepositoryURL = URL(filePath: "/tmp/colofa-diff-tests-other")

func diffRepositoryStub(
    at urls: [URL] = [diffRepositoryURL],
    diffDelay: Duration? = nil
) -> RepositoryServiceStub {
    RepositoryServiceStub(
        snapshots: Dictionary(
            uniqueKeysWithValues: urls.map { ($0, [diffRepositorySnapshot(at: $0)]) }
        ),
        diffResults: [
            "notes.txt": .diff(replacementDiff(path: "notes.txt")),
            "large.txt": .confirmationRequired(
                diffSummary(
                    path: "large.txt",
                    stats: DiffStats(additions: 40_000, deletions: 2),
                    byteCount: 3_000_000,
                    lineCount: 40_010,
                    isComplete: true
                )
            ),
            "huge.bin": .beyondHardLimit(
                diffSummary(
                    path: "huge.bin",
                    stats: nil,
                    byteCount: 10_485_761,
                    lineCount: 4,
                    isComplete: false
                )
            ),
        ],
        diffDelay: diffDelay
    )
}

func diffRepositorySnapshot(at url: URL) -> RepositorySnapshot {
    repository(
        at: url,
        stagedChanges: [RepositoryChange(path: "notes.txt", kind: .modified)],
        unstagedChanges: [
            RepositoryChange(path: "conflict.txt", kind: .conflict),
            RepositoryChange(path: "huge.bin", kind: .modified),
            RepositoryChange(path: "large.txt", kind: .modified),
            RepositoryChange(path: "notes.txt", kind: .modified),
        ]
    )
}

@MainActor
func diffWorkspace(
    _ stub: RepositoryServiceStub,
    at url: URL = diffRepositoryURL
) async -> WorkspaceState {
    let state = WorkspaceState(
        repositoryService: stub.service,
        launchArguments: ["--ui-testing"]
    )
    await state.handleRepositorySelection(.success(url))
    #expect(state.repository != nil)
    return state
}

/// Waits for the pane to report that it is reading, rather than assuming the load reached that
/// point by the time the test looked.
@MainActor
func waitForDiffLoadingState(of state: WorkspaceState) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(5))
    while state.diff != .loading {
        try #require(
            ContinuousClock.now < deadline,
            "The Diff pane never reported that it was loading"
        )
        try await Task.sleep(for: .milliseconds(1))
    }
}
