////
//  CommitWorkspaceFactory.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation
import Testing
@testable import Colofa

/// A Repository nothing prevents a Commit in: Staged Changes, a HEAD to amend, and an identity.
///
/// Shared by the Commit and Amend suites so both start from the same uninteresting state and
/// only spell out what their own case changes.
func committableRepository(
    at url: URL,
    head: RepositoryHead = .branch("main"),
    headCommit: RepositoryHeadCommit? = RepositoryHeadCommit(
        objectID: "fixture-head",
        summary: "Previous summary"
    ),
    upstream: RepositoryUpstream? = nil,
    operation: RepositoryOperation? = nil,
    stagedChanges: [RepositoryChange] = [RepositoryChange(path: "staged.txt", kind: .modified)],
    unstagedChanges: [RepositoryChange] = [],
    totalCommitCount: Int = 0
) -> RepositorySnapshot {
    repository(
        at: url,
        head: head,
        headCommit: headCommit,
        upstream: upstream,
        operation: operation,
        stagedChanges: stagedChanges,
        unstagedChanges: unstagedChanges,
        totalCommitCount: totalCommitCount,
        configuration: identityConfiguration()
    )
}

@MainActor
func openedWorkspace(
    _ stub: RepositoryServiceStub,
    at repositoryURL: URL,
    defaults: UserDefaults
) async -> WorkspaceState {
    let state = WorkspaceState(
        repositoryService: stub.service,
        userDefaults: defaults,
        launchArguments: ["--ui-testing"]
    )
    await state.handleRepositorySelection(.success(repositoryURL))
    #expect(state.repository != nil)
    return state
}
