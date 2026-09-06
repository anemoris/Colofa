////
//  MergeWorkspaceFactory.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation
@testable import Colofa

let mergeRepositoryURL = URL(filePath: "/tmp/Merge Store")

/// A Repository with a Branch worth merging in and a clean working tree.
///
/// Kept apart from `branchRepository` because a Merge needs the opposite starting tree: the branch
/// fixture carries a tracked local change so a refused Checkout has work to protect, and that same
/// change would refuse every Merge before a command ever ran.
func mergeRepository(
    at url: URL = mergeRepositoryURL,
    head: RepositoryHead = .branch("main"),
    localBranches: [String] = ["feature", "main"],
    stagedChanges: [RepositoryChange] = [],
    unstagedChanges: [RepositoryChange] = [],
    operation: RepositoryOperation? = nil,
    mergeHead: MergeHead? = nil
) -> RepositorySnapshot {
    repository(
        at: url,
        head: head,
        headCommit: RepositoryHeadCommit(objectID: "head", summary: "Fixture commit"),
        operation: operation,
        mergeHead: mergeHead,
        remotes: [RepositoryRemote(name: "origin", url: "ssh://example.invalid/x.git")],
        localBranches: localBranches,
        remoteBranches: ["origin/main"],
        tags: ["v1.0"],
        stagedChanges: stagedChanges,
        unstagedChanges: unstagedChanges
    )
}

/// The Repository an unfinished Merge that stopped at one Conflict reports.
func conflictedMergeRepository(
    at url: URL = mergeRepositoryURL,
    head: RepositoryHead = .branch("main"),
    mergeHead: MergeHead? = MergeHead(branch: "feature", objectID: "abc1234"),
    unstagedChanges: [RepositoryChange] = [
        RepositoryChange(path: "conflict.txt", kind: .conflict),
    ]
) -> RepositorySnapshot {
    mergeRepository(
        at: url,
        head: head,
        unstagedChanges: unstagedChanges,
        operation: .merge,
        mergeHead: mergeHead
    )
}

/// Options no Merge Colofa runs may ever carry. Each is a decision the user did not make: a
/// Squash Merge flattens the Branch, `--no-commit` and `--no-verify` leave out a step the user
/// expects, `--autostash` moves work nobody asked to move, and unrelated histories are a merge
/// Git refuses on purpose.
let refusedMergeOptions = [
    "--squash", "--no-commit", "--no-verify", "--autostash",
    "--allow-unrelated-histories", "-X", "--strategy-option",
]
