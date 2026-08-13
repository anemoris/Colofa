////
//  ConfigurationIntegrationTests.swift
//  ColofaGitIntegrationTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation
import Testing
@testable import Colofa

/// Reads configuration back through real Git, with every scope and both include forms present,
/// against fixtures fully isolated from the developer's own configuration.
struct ConfigurationIntegrationTests {
    @Test
    func loadsEffectiveConfigurationWithEverySupportedScopeAndIncludeOrigin() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository(named: "Configuration Repo")
        let sources = try configureEveryScope(in: fixture, repositoryURL: repositoryURL)
        let globalIncludeURL = sources.global
        let conditionalIncludeURL = sources.conditional
        let localIncludeURL = sources.local

        let service = GitRepositoryService(
            candidateURLs: [URL(filePath: "/usr/bin/git")],
            environment: fixture.environment
        )
        let repository = try await service.loadRepository(at: repositoryURL)
        let entries = repository.configuration.entries

        #expect(entries.contains { $0.scope == .system && $0.key == .httpProxy })
        #expect(
            entries.contains {
                $0.scope == .global && $0.key == .userName
                    && $0.origin.location == globalIncludeURL.normalizedFilePath
            }
        )
        #expect(
            entries.contains {
                $0.scope == .global && $0.key == .userEmail
                    && $0.origin.location == conditionalIncludeURL.normalizedFilePath
            }
        )
        #expect(
            entries.contains {
                $0.scope == .local && $0.key == .userEmail
                    && $0.origin.location == localIncludeURL.normalizedFilePath
            }
        )
        #expect(repository.configuration.effectiveEntry(for: .httpProxy)?.scope == .worktree)
        #expect(repository.configuration.effectiveEntry(for: .userEmail)?.scope == .local)
        #expect(
            repository.configuration.editableValue(for: .userEmail, editing: .repository) == nil
        )
        #expect(
            repository.configuration.editableValue(for: .userName, editing: .global)
                == "Colofa Tests"
        )
        #expect(repository.configuration.hasEffectiveIdentity)
    }

    /// Populates every scope Colofa reads: a system file from the fixture, a plain global
    /// include, a `gitdir:` conditional include, a local include, and a worktree override.
    private func configureEveryScope(
        in fixture: GitTestRepository,
        repositoryURL: URL
    ) throws -> ConfigurationIncludeSources {
        let globalIncludeURL = fixture.rootURL.appending(path: "global-include.gitconfig")
        let conditionalIncludeURL = fixture.rootURL
            .appending(path: "conditional-include.gitconfig")
        let localIncludeURL = repositoryURL.appending(path: "local-include.gitconfig")
        let gitDirectoryPath = try fixture.git(
            ["rev-parse", "--absolute-git-dir"],
            in: repositoryURL
        )

        _ = try fixture.git(
            ["config", "--file", globalIncludeURL.normalizedFilePath, "user.name", "Included Name"]
        )
        _ = try fixture.git(
            [
                "config", "--file", conditionalIncludeURL.normalizedFilePath,
                "user.email", "conditional@example.invalid",
            ]
        )
        _ = try fixture.git(
            [
                "config", "--file", localIncludeURL.normalizedFilePath,
                "user.email", "included@example.invalid",
            ]
        )
        _ = try fixture.git(
            ["config", "--global", "include.path", globalIncludeURL.normalizedFilePath]
        )
        _ = try fixture.git(
            [
                "config", "--global",
                "includeIf.gitdir:\(gitDirectoryPath).path",
                conditionalIncludeURL.normalizedFilePath,
            ]
        )
        _ = try fixture.git(
            ["config", "--local", "include.path", localIncludeURL.normalizedFilePath],
            in: repositoryURL
        )
        _ = try fixture.git(["config", "extensions.worktreeConfig", "true"], in: repositoryURL)
        _ = try fixture.git(
            ["config", "--worktree", "http.proxy", "http://worktree.example.invalid:8080"],
            in: repositoryURL
        )
        return ConfigurationIncludeSources(
            global: globalIncludeURL,
            conditional: conditionalIncludeURL,
            local: localIncludeURL
        )
    }
}
