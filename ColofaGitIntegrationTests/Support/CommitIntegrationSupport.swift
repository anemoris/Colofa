////
//  CommitIntegrationSupport.swift
//  ColofaGitIntegrationTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// A Store driving real Git inside `fixture`, isolated from the developer's own configuration.
@MainActor
func openedWorkspace(
    _ fixture: GitTestRepository,
    at repositoryURL: URL
) async -> WorkspaceState {
    let backend = GitRepositoryService(
        candidateURLs: [URL(filePath: "/usr/bin/git")],
        environment: fixture.environment
    )
    let service = RepositoryService(
        availability: { await backend.availability() },
        load: { try await backend.loadRepository(at: $0) },
        runMutation: { try await backend.runMutation($0, standardInput: $1, in: $2) }
    )
    let state = WorkspaceState(repositoryService: service, launchArguments: ["--ui-testing"])
    await state.handleRepositorySelection(.success(repositoryURL))
    #expect(state.repository != nil)
    return state
}

func writeHook(_ name: String, in repositoryURL: URL, script: String) throws {
    try writeExecutable(
        at: repositoryURL.appending(path: ".git/hooks").appending(path: name),
        script: script
    )
}

func writeExecutable(at url: URL, script: String) throws {
    try Data("#!/bin/sh\n\(script)\n".utf8).write(to: url)
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o755],
        ofItemAtPath: url.normalizedFilePath
    )
}
