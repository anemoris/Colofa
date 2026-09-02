////
//  FetchWorkspaceFactory.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation
import Testing
@testable import Colofa

let fetchRepositoryURL = URL(filePath: "/tmp/Fetch Store")

/// A Repository with remotes worth fetching and nothing standing in the way of one.
func fetchRepository(
    at url: URL = fetchRepositoryURL,
    remotes: [String] = ["origin", "mirror"],
    remoteBranches: [String] = ["origin/main"],
    tags: [String] = ["v1.0"]
) -> RepositorySnapshot {
    repository(
        at: url,
        head: .branch("main"),
        headCommit: RepositoryHeadCommit(objectID: "head", summary: "Fixture commit"),
        upstream: RepositoryUpstream(name: "origin/main", ahead: 1, behind: 0),
        remotes: remotes.map {
            RepositoryRemote(name: $0, url: "ssh://example.invalid/\($0).git")
        },
        localBranches: ["main"],
        remoteBranches: remoteBranches,
        tags: tags
    )
}

/// A Store holding an open Repository, with the app's own defaults left writable.
///
/// Unlike `openedWorkspace`, this one does not claim to be UI testing: the app-owned last-Fetch
/// time is deliberately not written during a UI test, and these tests are what prove it is
/// written at all.
@MainActor
func fetchWorkspace(
    _ stub: RepositoryServiceStub,
    at repositoryURL: URL = fetchRepositoryURL,
    defaults: UserDefaults
) async -> WorkspaceState {
    let state = WorkspaceState(
        repositoryService: stub.service,
        userDefaults: defaults,
        launchArguments: []
    )
    await state.handleRepositorySelection(.success(repositoryURL))
    #expect(state.repository != nil)
    return state
}

/// Options neither the toolbar's Fetch nor Fetch Tags may ever carry: they may add refs, never
/// replace or delete one, and they never widen what Git's own configuration asked for.
///
/// Fetch Remotes is held to a narrower rule of its own, because `--prune` is exactly what the
/// user pressed it for.
let refusedFetchOptions = [
    "--force", "-f", "--prune", "-p", "--prune-tags", "--all", "--multiple", "--update-head-ok",
]

/// Waits for something a running Fetch does, so a test can act while it is known to still be
/// running rather than by sleeping and hoping.
@MainActor
func waitForFetch(
    _ condition: @MainActor () async -> Bool,
    _ comment: Comment,
    timeout: Duration = .seconds(5)
) async throws {
    let deadline = ContinuousClock.now.advanced(by: timeout)
    while !(await condition()) {
        try #require(ContinuousClock.now < deadline, comment)
        await Task.yield()
    }
}
