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
/// - Parameters:
///   - gitURL: Which Git the Store drives, so a suite can substitute a controlled stand-in for
///     the real one.
///   - askPassHelperURL: The AskPass program Git and OpenSSH are pointed at. `nil` leaves the
///     Store without a channel at all, which is what every suite that never authenticates wants.
@MainActor
func openedWorkspace(
    _ fixture: GitTestRepository,
    at repositoryURL: URL,
    gitURL: URL = URL(filePath: "/usr/bin/git"),
    askPassHelperURL: URL? = nil
) async -> WorkspaceState {
    let backend = GitRepositoryService(
        candidateURLs: [gitURL],
        environment: fixture.environment,
        askPassHelperURL: askPassHelperURL
    )
    let service = RepositoryService(
        availability: { await backend.availability() },
        load: { try await backend.loadRepository(at: $0) },
        runMutation: { try await backend.runMutation($0, standardInput: $1, in: $2) },
        loadDiff: { try await backend.loadDiff($0) },
        loadHistory: { try await backend.loadHistory($0) },
        loadCommitDetail: { try await backend.loadCommitDetail($0) },
        validateBranchName: { try await backend.validateBranchName($0) },
        loadCheckoutComparison: { try await backend.loadCheckoutComparison($0) },
        loadSkippedRemotes: { try await backend.loadSkippedRemotes(in: $0) },
        loadTagConflicts: { try await backend.loadTagConflicts($0) },
        loadPublishRemote: { try await backend.loadPublishRemote($0) },
        loadPushTarget: { try await backend.loadPushTarget($0) },
        loadPushDestination: { try await backend.loadPushDestination($0) },
        runNetworkMutation: { try await backend.runNetworkMutation($0, in: $1, responder: $2) }
    )
    let state = WorkspaceState(repositoryService: service, launchArguments: ["--ui-testing"])
    await state.handleRepositorySelection(.success(repositoryURL))
    #expect(state.repository != nil)
    return state
}

nonisolated func writeHook(_ name: String, in repositoryURL: URL, script: String) throws {
    try writeExecutable(
        at: repositoryURL.appending(path: ".git/hooks").appending(path: name),
        script: script
    )
}

/// Declared `nonisolated` because the project defaults to Main Actor isolation, and writing a
/// stand-in program is file I/O a suite may do from anywhere.
nonisolated func writeExecutable(at url: URL, script: String) throws {
    try Data("#!/bin/sh\n\(script)\n".utf8).write(to: url)
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o755],
        ofItemAtPath: url.normalizedFilePath
    )
}
