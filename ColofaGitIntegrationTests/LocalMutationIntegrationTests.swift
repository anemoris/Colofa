////
//  LocalMutationIntegrationTests.swift
//  ColofaGitIntegrationTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

struct LocalMutationIntegrationTests {
    @Test
    func doesNotCancelALocalMutationAfterItStarts() async throws {
        let fixture = try GitTestRepository()
        let executableURL = fixture.rootURL.appending(path: "recording-git")
        let eventsURL = fixture.rootURL.appending(path: "mutation-events")
        try fixture.createMutationRecordingGit(at: executableURL, eventsURL: eventsURL)
        let service = GitRepositoryService(candidateURLs: [executableURL])
        #expect(await service.availability() == .available(executableURL))

        let mutation = Task {
            try await service.runMutation(["stage"], in: fixture.rootURL)
        }
        for _ in 0..<100 {
            let events = (try? String(contentsOf: eventsURL, encoding: .utf8)) ?? ""
            if events.contains("stage-start") {
                break
            }
            try await Task.sleep(for: .milliseconds(5))
        }
        mutation.cancel()
        try await mutation.value

        let events = String(decoding: try Data(contentsOf: eventsURL), as: UTF8.self)
        #expect(events.split(separator: "\n") == ["stage-start", "stage-end"])
    }

    @Test
    func writesAndUnsetsConfigurationAtExplicitScopes() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        let service = GitRepositoryService(
            candidateURLs: [URL(filePath: "/usr/bin/git")],
            environment: fixture.environment
        )

        try await service.runMutation(
            ["config", "--local", "--replace-all", "user.name", "Repository Name"],
            in: repositoryURL
        )
        #expect(
            try fixture.git(["config", "--local", "user.name"], in: repositoryURL)
                == "Repository Name"
        )

        try await service.runMutation(
            ["config", "--global", "--replace-all", "user.email", "global@example.invalid"],
            in: repositoryURL
        )
        #expect(
            try fixture.git(["config", "--global", "user.email"], in: repositoryURL)
                == "global@example.invalid"
        )

        try await service.runMutation(
            ["config", "--local", "--unset-all", "user.name"],
            in: repositoryURL
        )
        do {
            _ = try fixture.git(["config", "--local", "user.name"], in: repositoryURL)
            Issue.record("Expected the Repository value to be unset")
        } catch {
            // An unset key makes git config --get fail with exit status 1.
        }
    }

    /// A config file may legitimately list a key twice. Git refuses to overwrite or unset a
    /// multi-valued key through the singular commands, so the editor must converge it instead
    /// of failing.
    @Test
    func savingAndClearingConvergeAKeyThatIsSetTwice() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        let service = GitRepositoryService(
            candidateURLs: [URL(filePath: "/usr/bin/git")],
            environment: fixture.environment
        )
        _ = try fixture.git(
            ["config", "--local", "user.email", "first@example.invalid"],
            in: repositoryURL
        )
        _ = try fixture.git(
            ["config", "--local", "--add", "user.email", "second@example.invalid"],
            in: repositoryURL
        )

        try await service.runMutation(
            ["config", "--local", "--replace-all", "user.email", "only@example.invalid"],
            in: repositoryURL
        )
        #expect(
            try fixture.git(["config", "--local", "--get-all", "user.email"], in: repositoryURL)
                == "only@example.invalid"
        )

        try await service.runMutation(
            ["config", "--local", "--unset-all", "user.email"],
            in: repositoryURL
        )
        do {
            _ = try fixture.git(
                ["config", "--local", "--get-all", "user.email"],
                in: repositoryURL
            )
            Issue.record("Expected every Repository value to be unset")
        } catch {
            // Reading a key with no values left makes git config fail with exit status 1.
        }
    }
}
