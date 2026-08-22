////
//  RepositorySnapshotFactory.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation
@testable import Colofa

/// Builds a `RepositorySnapshot` with only the fields a test cares about.
///
/// Shared by every Store-level suite so they agree on what an otherwise-uninteresting
/// Repository looks like.
func repository(
    at url: URL,
    head: RepositoryHead = .branch("main"),
    headCommit: RepositoryHeadCommit? = nil,
    upstream: RepositoryUpstream? = nil,
    operation: RepositoryOperation? = nil,
    remotes: [RepositoryRemote] = [],
    localBranches: [String] = [],
    remoteBranches: [String] = [],
    tags: [String] = [],
    stagedChanges: [RepositoryChange] = [],
    unstagedChanges: [RepositoryChange] = [],
    totalCommitCount: Int = 0,
    configuration: GitConfigurationSnapshot = .empty
) -> RepositorySnapshot {
    RepositorySnapshot(
        name: url.lastPathComponent,
        rootURL: url,
        gitDirectoryURL: url.appending(path: ".git"),
        head: head,
        headCommit: headCommit,
        upstream: upstream,
        remotes: remotes,
        localBranches: localBranches,
        remoteBranches: remoteBranches,
        tags: tags,
        stagedChanges: stagedChanges,
        unstagedChanges: unstagedChanges,
        operation: operation,
        totalCommitCount: totalCommitCount,
        configuration: configuration
    )
}

/// A configuration that satisfies Git's identity requirement, which Commit checks before it runs.
func identityConfiguration() -> GitConfigurationSnapshot {
    GitConfigurationSnapshot(
        entries: [
            GitConfigurationEntry(
                key: .userName,
                value: "Colofa Tests",
                scope: .global,
                origin: GitConfigurationOrigin(rawValue: "file:/tmp/global.gitconfig")
            ),
            GitConfigurationEntry(
                key: .userEmail,
                value: "colofa-tests@example.invalid",
                scope: .global,
                origin: GitConfigurationOrigin(rawValue: "file:/tmp/global.gitconfig")
            ),
        ]
    )
}
