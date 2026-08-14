////
//  WorkspaceStateConfigurationTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation
import Testing
@testable import Colofa

/// Store-level behaviour of configuration editing: which Git command each edit produces, and
/// which scope it lands in.
@Suite(.serialized)
final class WorkspaceStateConfigurationTests {
    private let defaults: UserDefaults

    /// Its own defaults suite, wiped on entry, so restored-Repository state cannot leak in from
    /// another suite.
    init() throws {
        let suiteName = "com.anemoris.Colofa.WorkspaceStateConfigurationTests"
        defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test
    @MainActor
    func savesConfigurationAtTheSelectedScopeAndUnsetsOnClear() async throws {
        let repositoryURL = URL(filePath: "/tmp/Configuration Mutation")
        let localName = entry(.userName, "Local Name", .local)
        let globalEmail = entry(.userEmail, "global@example.invalid", .global)
        let afterSave = repository(
            at: repositoryURL,
            configuration: GitConfigurationSnapshot(entries: [
                entry(.userName, "Updated Name", .local),
                globalEmail,
            ])
        )
        let afterClear = repository(
            at: repositoryURL,
            configuration: GitConfigurationSnapshot(entries: [globalEmail])
        )
        let stub = RepositoryServiceStub(
            snapshots: [
                repositoryURL: [
                    repository(
                        at: repositoryURL,
                        configuration: GitConfigurationSnapshot(entries: [localName, globalEmail])
                    ),
                    afterSave,
                    afterClear,
                ],
            ]
        )
        let state = WorkspaceState(
            repositoryService: stub.service,
            userDefaults: defaults,
            launchArguments: ["--ui-testing"]
        )

        await state.handleRepositorySelection(.success(repositoryURL))
        #expect(state.hasEffectiveCommitIdentity)
        await state.updateConfiguration(.userName, value: "Updated Name", in: .repository)
        await state.updateConfiguration(.userName, value: nil, in: .repository)

        #expect(await stub.recordedArguments() == [
            ["config", "--local", "--replace-all", "user.name", "Updated Name"],
            ["config", "--local", "--unset-all", "user.name"],
        ])
        #expect(state.repository == afterClear)
        #expect(!state.hasEffectiveCommitIdentity)
    }

    @Test
    @MainActor
    func configurationCanBeWrittenGloballyEvenWhenRepositoryOverridesIt() async throws {
        let repositoryURL = URL(filePath: "/tmp/Global Configuration Mutation")
        let globalEmail = entry(.userEmail, "global@example.invalid", .global)
        let localEmail = entry(.userEmail, "local@example.invalid", .local)
        let before = repository(
            at: repositoryURL,
            configuration: GitConfigurationSnapshot(entries: [globalEmail, localEmail])
        )
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [before, before]]
        )
        let state = WorkspaceState(
            repositoryService: stub.service,
            userDefaults: defaults,
            launchArguments: ["--ui-testing"]
        )
        state.configurationEditingScope = .global

        await state.handleRepositorySelection(.success(repositoryURL))
        await state.updateConfiguration(
            .userEmail,
            value: "new@example.invalid",
            in: .global
        )

        #expect(await stub.recordedArguments() == [
            ["config", "--global", "--replace-all", "user.email", "new@example.invalid"],
        ])
    }

    @Test
    @MainActor
    func repositoryOverrideCanBeRemovedWhileEditingGlobalConfiguration() async throws {
        let repositoryURL = URL(filePath: "/tmp/Remove Repository Override")
        let globalEmail = entry(.userEmail, "global@example.invalid", .global)
        let before = repository(
            at: repositoryURL,
            configuration: GitConfigurationSnapshot(entries: [
                globalEmail,
                entry(.userEmail, "local@example.invalid", .local),
            ])
        )
        let after = repository(
            at: repositoryURL,
            configuration: GitConfigurationSnapshot(entries: [globalEmail])
        )
        let stub = RepositoryServiceStub(snapshots: [repositoryURL: [before, after]])
        let state = WorkspaceState(
            repositoryService: stub.service,
            userDefaults: defaults,
            launchArguments: ["--ui-testing"]
        )
        state.configurationEditingScope = .global

        await state.handleRepositorySelection(.success(repositoryURL))
        await state.updateConfiguration(.userEmail, value: nil, in: .repository)

        #expect(await stub.recordedArguments() == [
            ["config", "--local", "--unset-all", "user.email"],
        ])
        #expect(state.repository == after)
    }

    /// Origins are irrelevant to these assertions, so each scope gets one canonical file.
    private func entry(
        _ key: GitConfigurationKey,
        _ value: String,
        _ scope: GitConfigurationScope
    ) -> GitConfigurationEntry {
        GitConfigurationEntry(
            key: key,
            value: value,
            scope: scope,
            origin: GitConfigurationOrigin(
                rawValue: scope == .global ? "file:/tmp/global.gitconfig" : "file:.git/config"
            )
        )
    }
}
