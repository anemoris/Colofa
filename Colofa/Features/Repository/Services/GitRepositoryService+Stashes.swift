////
//  GitRepositoryService+Stashes.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// The reads behind the Stashes pane.
///
/// Grouped in a file of its own, the way the stubbed service's Stash answers are: neither of
/// these is published Repository state, and both are paid for only while that pane is open.
extension GitRepositoryService {
    func loadStashes(in repositoryURL: URL) async throws -> [Stash] {
        try await GitStashReader(git: try await resolvedGit()).list(inRepositoryAt: repositoryURL)
    }

    func loadStashDetail(_ request: StashDetailRequest) async throws -> StashDetail {
        try await GitStashReader(git: try await resolvedGit()).detail(request)
    }
}
