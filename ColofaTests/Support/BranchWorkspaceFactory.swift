////
//  BranchWorkspaceFactory.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation
@testable import Colofa

let branchRepositoryURL = URL(filePath: "/tmp/Branch Store")

/// A Repository with Refs worth checking out and nothing standing in the way of one.
///
/// Shared by the New Branch and Checkout suites so both start from the same uninteresting state
/// and only spell out what their own case changes.
func branchRepository(
    at url: URL = branchRepositoryURL,
    head: RepositoryHead = .branch("main"),
    localBranches: [String] = ["main"],
    unstagedChanges: [RepositoryChange] = []
) -> RepositorySnapshot {
    repository(
        at: url,
        head: head,
        headCommit: RepositoryHeadCommit(objectID: "head", summary: "Fixture commit"),
        remotes: [RepositoryRemote(name: "origin", url: "ssh://example.invalid/x.git")],
        localBranches: localBranches,
        remoteBranches: ["origin/feature"],
        tags: ["v1.0"],
        unstagedChanges: unstagedChanges
    )
}

/// Options no command Colofa runs may ever carry: a Checkout that would overwrite local work is
/// refused rather than given a way to overwrite it.
let refusedCheckoutOptions = [
    "--force", "-f", "--force-create", "-C", "--merge", "-m", "--discard-changes", "stash",
]
