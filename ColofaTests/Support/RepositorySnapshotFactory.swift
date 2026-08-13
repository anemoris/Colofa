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
    operation: RepositoryOperation? = nil,
    stagedChanges: [RepositoryChange] = [],
    unstagedChanges: [RepositoryChange] = [],
    configuration: GitConfigurationSnapshot = .empty
) -> RepositorySnapshot {
    RepositorySnapshot(
        name: url.lastPathComponent,
        rootURL: url,
        gitDirectoryURL: url.appending(path: ".git"),
        head: head,
        stagedChanges: stagedChanges,
        unstagedChanges: unstagedChanges,
        operation: operation,
        configuration: configuration
    )
}
