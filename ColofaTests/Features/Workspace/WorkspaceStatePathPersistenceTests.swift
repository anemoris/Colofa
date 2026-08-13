////
//  WorkspaceStatePathPersistenceTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

@Suite(.serialized)
struct WorkspaceStatePathPersistenceTests {
    @Test
    @MainActor
    func selectedRepositoryRootPathIsRestored() async throws {
        let suiteName = "com.anemoris.Colofa.WorkspaceStatePathPersistenceTests"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let selectedURL = URL(filePath: "/tmp/Repository/Sources", directoryHint: .isDirectory)
        let repositoryURL = URL(filePath: "/tmp/Repository", directoryHint: .isDirectory)
        let repository = RepositorySnapshot(
            name: "Repository",
            rootURL: repositoryURL,
            gitDirectoryURL: repositoryURL.appending(path: ".git"),
            head: .branch("main"),
            upstream: nil,
            remotes: [],
            localBranches: ["main"],
            remoteBranches: [],
            tags: [],
            stagedChanges: [],
            unstagedChanges: [],
            operation: nil,
            totalCommitCount: 0,
            gitObjectSize: 0
        )
        let stub = RepositoryServiceStub(
            snapshots: [selectedURL: [repository], repositoryURL: [repository]]
        )
        let selectedState = WorkspaceState(
            repositoryService: stub.service,
            userDefaults: defaults,
            launchArguments: []
        )

        await selectedState.handleRepositorySelection(.success(selectedURL))

        #expect(
            defaults.string(forKey: "lastRepositoryPath")
                == repositoryURL.normalizedFilePath
        )

        let restoredState = WorkspaceState(
            repositoryService: stub.service,
            userDefaults: defaults,
            launchArguments: []
        )
        await restoredState.start()

        #expect(restoredState.repository == repository)
        #expect(!restoredState.isPresentingRepositoryPicker)
    }
}
