////
//  PullWorkspaceFactory.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation
import Testing
@testable import Colofa

let pullRepositoryURL = URL(filePath: "/tmp/Pull Store")

/// A Repository whose current Branch has an upstream and nothing standing in the way of a Pull.
func pullRepository(
    at url: URL = pullRepositoryURL,
    head: RepositoryHead = .branch("main"),
    upstream: String? = "origin/main",
    ahead: Int = 0,
    behind: Int = 2,
    operation: RepositoryOperation? = nil,
    stagedChanges: [RepositoryChange] = [],
    unstagedChanges: [RepositoryChange] = [],
    totalCommitCount: Int = 12
) -> RepositorySnapshot {
    repository(
        at: url,
        head: head,
        headCommit: RepositoryHeadCommit(objectID: "head", summary: "Fixture commit"),
        upstream: upstream.map { RepositoryUpstream(name: $0, ahead: ahead, behind: behind) },
        operation: operation,
        remotes: [RepositoryRemote(name: "origin", url: "ssh://example.invalid/origin.git")],
        localBranches: ["main"],
        remoteBranches: ["origin/main"],
        stagedChanges: stagedChanges,
        unstagedChanges: unstagedChanges,
        totalCommitCount: totalCommitCount
    )
}

/// A Store holding an open Repository a Pull can run in, with the app's own defaults left
/// writable so the last-Fetch time a Pull records can be read back.
@MainActor
func pullWorkspace(
    _ stub: RepositoryServiceStub,
    at repositoryURL: URL = pullRepositoryURL,
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
