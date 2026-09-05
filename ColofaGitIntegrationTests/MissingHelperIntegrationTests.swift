////
//  MissingHelperIntegrationTests.swift
//  ColofaGitIntegrationTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// What real Git does with the `PATH` Colofa hands it, and what it says when a program it needs
/// is not on that path.
///
/// A stand-in filter reproduces the reported Git LFS failure exactly — Git runs the configured
/// process through a shell, the shell cannot find it, and Git reports the work that was
/// interrupted rather than the program that was missing.
@Suite(.serialized)
struct MissingHelperIntegrationTests {
    private let gitURL = URL(filePath: "/usr/bin/git")

    /// A Repository whose tracked file is filtered by a program that does not exist, which is the
    /// shape of every Repository holding Git LFS pointers on a machine where `git-lfs` cannot be
    /// found.
    private func repositoryFiltered(
        by process: String,
        in fixture: GitTestRepository
    ) throws -> URL {
        let repositoryURL = try fixture.createWorkingRepository()
        try Data("content\n".utf8).write(to: repositoryURL.appending(path: "tracked.txt"))
        try Data("tracked.txt filter=colofa\n".utf8).write(
            to: repositoryURL.appending(path: ".gitattributes")
        )
        _ = try fixture.git(["add", "--all"], in: repositoryURL)
        _ = try fixture.git(["commit", "-m", "Filtered"], in: repositoryURL)
        // Configured after the Commit, so the fixture itself is built without ever running it.
        _ = try fixture.git(
            ["config", "filter.colofa.process", "\(process) filter-process"],
            in: repositoryURL
        )
        _ = try fixture.git(["config", "filter.colofa.required", "true"], in: repositoryURL)
        return repositoryURL
    }

    /// A program on `PATH` under the name `git <subcommand>` resolves to, which is exactly how
    /// `git lfs` finds `git-lfs`.
    private func writeGitSubcommand(named name: String, in directoryURL: URL) throws {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let executableURL = directoryURL.appending(path: "git-\(name)")
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: executableURL)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: executableURL.normalizedFilePath
        )
    }

    /// The reported failure, reproduced: opening the Repository runs the Status read, the Status
    /// read runs the filter, and the filter is not there.
    @Test
    func namesTheProgramGitCouldNotFindWhenOpeningARepository() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try repositoryFiltered(by: "colofa-absent-filter", in: fixture)
        let service = GitRepositoryService(
            candidateURLs: [gitURL],
            environment: fixture.environment
        )

        let error = await #expect(throws: RepositoryOpenError.self) {
            _ = try await service.loadRepository(at: repositoryURL)
        }

        #expect(
            try #require(error?.missingHelper) == GitMissingHelper(program: "colofa-absent-filter")
        )
    }

    /// The `PATH` Colofa builds is the one Git searches: a helper the environment already named a
    /// directory for is still found, so covering the well-known locations never costs the user
    /// the locations they configured themselves.
    @Test
    func findsAHelperOnTheInheritedSearchPath() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        _ = try fixture.createCommit(in: repositoryURL)
        let binURL = fixture.rootURL.appending(path: "bin", directoryHint: .isDirectory)
        try writeGitSubcommand(named: "colofa-probe", in: binURL)

        var environment = fixture.environment
        environment["PATH"] = binURL.normalizedFilePath
        let service = GitRepositoryService(candidateURLs: [gitURL], environment: environment)

        try await service.runMutation(["colofa-probe"], in: repositoryURL)
    }

    /// Where Colofa looks for Git itself is the search path of the environment it was given, so
    /// the two lists cannot disagree even when that environment is not the process's own.
    @Test
    func looksForGitOnTheSearchPathOfTheEnvironmentItWasGiven() async throws {
        let fixture = try GitTestRepository()
        let binURL = fixture.rootURL.appending(path: "bin", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: binURL, withIntermediateDirectories: true)
        let executableURL = binURL.appending(path: "git")
        try Data("#!/bin/sh\necho 'git version 2.0.0-colofa'\n".utf8).write(to: executableURL)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: executableURL.normalizedFilePath
        )

        var environment = fixture.environment
        environment["PATH"] = binURL.normalizedFilePath
        let service = GitRepositoryService(environment: environment)

        guard case .available(let foundURL) = await service.availability() else {
            Issue.record("Git was not found on the search path it was given.")
            return
        }
        #expect(foundURL.normalizedFilePath == executableURL.normalizedFilePath)
    }

    /// The same helper, with nothing pointing Git at it, is named rather than left to Git's
    /// suggestion of a command the user did not ask for.
    @Test
    func namesTheProgramBehindASubcommandThatIsNotOnTheSearchPath() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        _ = try fixture.createCommit(in: repositoryURL)

        var environment = fixture.environment
        environment["PATH"] = "/usr/bin:/bin"
        let service = GitRepositoryService(candidateURLs: [gitURL], environment: environment)

        let error = await #expect(throws: RepositoryOpenError.self) {
            try await service.runMutation(["colofa-probe"], in: repositoryURL)
        }

        #expect(
            try #require(error?.missingHelper)
                == GitMissingHelper(program: "git-colofa-probe")
        )
    }
}
