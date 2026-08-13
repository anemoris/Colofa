////
//  GitTestRepositoryTests.swift
//  ColofaGitIntegrationTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

@Suite(.serialized)
struct GitTestRepositoryTests {
    @Test
    func createsAnIsolatedWorkingRepository() throws {
        let fixture = try GitTestRepository()

        let repositoryURL = try fixture.createWorkingRepository()

        #expect(try fixture.git(["rev-parse", "--is-inside-work-tree"], in: repositoryURL) == "true")
        #expect(try fixture.git(["config", "--global", "user.name"], in: repositoryURL) == "Colofa Tests")
        #expect(
            try fixture.git(["config", "--global", "user.email"], in: repositoryURL)
                == "colofa-tests@example.invalid"
        )
    }

    @Test
    func createsAndConnectsALocalBareRemote() throws {
        let fixture = try GitTestRepository()

        let repositoryURL = try fixture.createWorkingRepository()
        let remoteURL = try fixture.createBareRemote()
        try fixture.addRemote(remoteURL, named: "origin", to: repositoryURL)

        #expect(try fixture.git(["rev-parse", "--is-bare-repository"], in: remoteURL) == "true")
        #expect(
            try fixture.git(["remote", "get-url", "origin"], in: repositoryURL)
                == remoteURL.normalizedFilePath
        )
    }

    @Test
    func removesTemporaryRepositoryWhenReleased() throws {
        var fixture: GitTestRepository? = try GitTestRepository()
        let rootURL = try #require(fixture?.rootURL)

        fixture = nil

        #expect(!FileManager.default.fileExists(atPath: rootURL.normalizedFilePath))
    }
}
