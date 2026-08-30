////
//  PushWorkspaceFactory.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

let pushRepositoryURL = URL(filePath: "/tmp/Push Store")

/// What the fixture's remote-tracking Ref points at, which is the lease a Force Push supplies.
let pushExpectedObjectID = "0123456789abcdef0123456789abcdef01234567"

/// What the fixture's own Branch points at, which is the history a Force Push would install.
let pushLocalObjectID = "head"

/// Where the fixture's Push goes, as Git itself would report it.
func pushTarget(
    remote: String = "origin",
    remoteRef: String = "refs/heads/main",
    upstream: String = "origin/main",
    expectedObjectID: String? = pushExpectedObjectID
) -> PushTarget {
    PushTarget(
        remote: remote,
        remoteRef: remoteRef,
        upstream: upstream,
        trackingRef: "refs/remotes/\(upstream)",
        expectedObjectID: expectedObjectID
    )
}

/// The one address the fixture's remote resolves to, which is what a confirmation captures and
/// checks again before anything is sent.
nonisolated func pushDestination(remote: String = "origin") -> PushDestination {
    PushDestination("ssh://example.invalid/\(remote).git")
}

/// The confirmation the fixture's Push opens.
func pushConfirmation(
    branch: String = "main",
    target: PushTarget = pushTarget(),
    destination: PushDestination = pushDestination(),
    localObjectID: String? = pushLocalObjectID
) -> PushConfirmation {
    PushConfirmation(
        branch: branch,
        target: target,
        destination: destination,
        localObjectID: localObjectID
    )
}

/// A Repository whose current Branch can be pushed, with nothing standing in the way of one.
func pushRepository(
    at url: URL = pushRepositoryURL,
    head: RepositoryHead = .branch("main"),
    headObjectID: String = pushLocalObjectID,
    upstream: String? = "origin/main",
    ahead: Int = 2,
    behind: Int = 0,
    remotes: [String] = ["origin"],
    operation: RepositoryOperation? = nil,
    unstagedChanges: [RepositoryChange] = []
) -> RepositorySnapshot {
    repository(
        at: url,
        head: head,
        headCommit: RepositoryHeadCommit(
            objectID: headObjectID,
            summary: "Fixture commit"
        ),
        upstream: upstream.map { RepositoryUpstream(name: $0, ahead: ahead, behind: behind) },
        operation: operation,
        remotes: remotes.map {
            RepositoryRemote(name: $0, url: "ssh://example.invalid/\($0).git")
        },
        localBranches: ["main"],
        remoteBranches: upstream.map { [$0] } ?? [],
        unstagedChanges: unstagedChanges,
        totalCommitCount: 12
    )
}

/// A Store holding an open Repository a Push can run in.
@MainActor
func pushWorkspace(
    _ stub: RepositoryServiceStub,
    at repositoryURL: URL = pushRepositoryURL,
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
