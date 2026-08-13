////
//  GitConfigurationSnapshotTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation
import Testing
@testable import Colofa

/// Precedence, editability, and scope-relationship projection over a parsed configuration.
struct GitConfigurationSnapshotTests {
    @Test
    func reportsShadowingAndKeepsUnusualValuesSaveable() {
        let configuration = GitConfigurationSnapshot(entries: [
            GitConfigurationEntry(
                key: .userEmail,
                value: "global@example.invalid",
                scope: .global,
                origin: GitConfigurationOrigin(rawValue: "file:/tmp/global.gitconfig")
            ),
            GitConfigurationEntry(
                key: .userEmail,
                value: "local@example.invalid",
                scope: .local,
                origin: GitConfigurationOrigin(rawValue: "file:.git/config")
            ),
        ])

        #expect(
            configuration.shadowingEntry(for: .userEmail, editing: .global)?.scope == .local
        )
        #expect(configuration.shadowingEntry(for: .userEmail, editing: .repository) == nil)
        #expect(GitConfigurationKey.userEmail.warning(for: "not-an-email") != nil)
    }

    @Test
    func editableValueComesFromTheSelectedScope() {
        let configuration = GitConfigurationSnapshot(entries: [
            GitConfigurationEntry(
                key: .userEmail,
                value: "global@example.invalid",
                scope: .global,
                origin: GitConfigurationOrigin(rawValue: "file:/tmp/global.gitconfig")
            ),
            GitConfigurationEntry(
                key: .userEmail,
                value: "local@example.invalid",
                scope: .local,
                origin: GitConfigurationOrigin(rawValue: "file:.git/config")
            ),
        ])

        #expect(
            configuration.editableValue(for: .userEmail, editing: .global)
                == "global@example.invalid"
        )
    }

    @Test
    func editingGlobalReportsTheRepositoryValueThatShadowsIt() {
        let localEntry = GitConfigurationEntry(
            key: .userEmail,
            value: "local@example.invalid",
            scope: .local,
            origin: GitConfigurationOrigin(rawValue: "file:.git/config")
        )
        let configuration = GitConfigurationSnapshot(entries: [
            GitConfigurationEntry(
                key: .userEmail,
                value: "global@example.invalid",
                scope: .global,
                origin: GitConfigurationOrigin(rawValue: "file:/tmp/global.gitconfig")
            ),
            localEntry,
        ])

        #expect(
            configuration.relationship(for: .userEmail, editing: .global)
                == .shadowedBy(localEntry, removableScope: .repository)
        )
    }

    @Test
    func editingRepositoryReportsTheGlobalValueItOverrides() {
        let globalEntry = GitConfigurationEntry(
            key: .userEmail,
            value: "global@example.invalid",
            scope: .global,
            origin: GitConfigurationOrigin(rawValue: "file:/tmp/global.gitconfig")
        )
        let configuration = GitConfigurationSnapshot(entries: [
            globalEntry,
            GitConfigurationEntry(
                key: .userEmail,
                value: "local@example.invalid",
                scope: .local,
                origin: GitConfigurationOrigin(rawValue: "file:.git/config")
            ),
        ])

        #expect(
            configuration.relationship(for: .userEmail, editing: .repository)
                == .overridesGlobal(globalEntry)
        )
    }

    @Test
    func editingRepositoryReportsTheGlobalValueItInherits() {
        let globalEntry = GitConfigurationEntry(
            key: .userEmail,
            value: "global@example.invalid",
            scope: .global,
            origin: GitConfigurationOrigin(rawValue: "file:/tmp/global.gitconfig")
        )
        let configuration = GitConfigurationSnapshot(entries: [globalEntry])

        #expect(
            configuration.relationship(for: .userEmail, editing: .repository)
                == .inheritsGlobal(globalEntry)
        )
    }

    @Test
    func relationshipsExposeOnlyRemovableRepositoryValues() {
        let globalEntry = GitConfigurationEntry(
            key: .userEmail,
            value: "global@example.invalid",
            scope: .global,
            origin: GitConfigurationOrigin(rawValue: "file:/tmp/global.gitconfig")
        )
        let localEntry = GitConfigurationEntry(
            key: .userEmail,
            value: "local@example.invalid",
            scope: .local,
            origin: GitConfigurationOrigin(rawValue: "file:.git/config")
        )

        #expect(
            GitConfigurationRelationship.shadowedBy(
                localEntry,
                removableScope: .repository
            ).removableScope == .repository
        )
        #expect(
            GitConfigurationRelationship.overridesGlobal(globalEntry).removableScope
                == .repository
        )
        #expect(GitConfigurationRelationship.inheritsGlobal(globalEntry).removableScope == nil)
    }

    @Test
    func supportedKeysProvideTheGitReadPattern() {
        #expect(
            GitConfigurationKey.gitReadPattern
                == "^(user\\.name|user\\.email|http\\.proxy)$"
        )
    }

    @Test
    func unsettingDistinguishesAStoredEmptyValueFromAMissingValue() {
        let storedEmpty = GitConfigurationSnapshot(entries: [
            GitConfigurationEntry(
                key: .httpProxy,
                value: "",
                scope: .local,
                origin: GitConfigurationOrigin(rawValue: "file:.git/config")
            ),
        ])

        #expect(storedEmpty.requiresUpdate(nil, for: .httpProxy, editing: .repository))
        #expect(!GitConfigurationSnapshot.empty.requiresUpdate(
            nil,
            for: .httpProxy,
            editing: .repository
        ))
    }

    @Test
    func includedValueIsVisibleButNotEditableAtTheParentScope() {
        let globalEntry = GitConfigurationEntry(
            key: .userEmail,
            value: "global@example.invalid",
            scope: .global,
            origin: GitConfigurationOrigin(rawValue: "file:/tmp/global.gitconfig")
        )
        let includedLocalEntry = GitConfigurationEntry(
            key: .userEmail,
            value: "included@example.invalid",
            scope: .local,
            origin: GitConfigurationOrigin(rawValue: "file:/tmp/local-include.gitconfig")
        )
        let configuration = GitConfigurationSnapshot(
            entries: [globalEntry, includedLocalEntry],
            editableEntries: [globalEntry]
        )

        #expect(configuration.editableValue(for: .userEmail, editing: .repository) == nil)
        #expect(
            configuration.relationship(for: .userEmail, editing: .repository)
                == .shadowedBy(includedLocalEntry, removableScope: nil)
        )
    }
}
