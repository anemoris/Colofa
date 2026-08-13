////
//  ConfigurationFieldDraftTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation
import Testing
@testable import Colofa

struct ConfigurationFieldDraftTests {
    @Test
    func seedsFromTheEditedScopeRatherThanTheEffectiveValue() {
        let draft = ConfigurationFieldDraft(
            key: .userEmail,
            configuration: overriddenEmail,
            editing: .global
        )

        #expect(draft.value == "global@example.invalid")
    }

    /// A field inheriting from a wider scope starts empty, so the placeholder rather than
    /// someone else's value is what the user edits.
    @Test
    func startsEmptyWhenTheEditedScopeHasNoValue() {
        let draft = ConfigurationFieldDraft(
            key: .userName,
            configuration: overriddenEmail,
            editing: .repository
        )

        #expect(draft.value.isEmpty)
        #expect(draft.requestedValue == nil)
    }

    /// Clearing means "restore inheritance". Git keeps a stored empty string as a real value
    /// that still shadows the wider scope, so it must become an unset instead.
    @Test
    func anEmptyDraftRequestsAnUnsetRatherThanAnEmptyString() {
        var draft = ConfigurationFieldDraft(
            key: .userEmail,
            configuration: overriddenEmail,
            editing: .repository
        )
        draft.value = ""

        #expect(draft.requestedValue == nil)
        #expect(draft.needsSaving(against: overriddenEmail, editing: .repository))
    }

    @Test
    func anUnchangedDraftDoesNotNeedSaving() {
        let draft = ConfigurationFieldDraft(
            key: .userEmail,
            configuration: overriddenEmail,
            editing: .repository
        )

        #expect(!draft.needsSaving(against: overriddenEmail, editing: .repository))
    }

    /// Nothing is stored at the Repository scope, so clearing an already-empty field is a no-op
    /// and must not offer a doomed `--unset`.
    @Test
    func clearingAnInheritedFieldDoesNotNeedSaving() {
        let draft = ConfigurationFieldDraft(
            key: .userName,
            configuration: overriddenEmail,
            editing: .repository
        )

        #expect(!draft.needsSaving(against: overriddenEmail, editing: .repository))
    }

    @Test
    func reloadingFollowsTheScopeTheUserSwitchedTo() {
        var draft = ConfigurationFieldDraft(
            key: .userEmail,
            configuration: overriddenEmail,
            editing: .repository
        )
        #expect(draft.value == "local@example.invalid")

        draft.reload(from: overriddenEmail, editing: .global)

        #expect(draft.value == "global@example.invalid")
    }

    @Test
    func reloadingDiscardsAnUnsavedEdit() {
        var draft = ConfigurationFieldDraft(
            key: .userEmail,
            configuration: overriddenEmail,
            editing: .repository
        )
        draft.value = "typed@example.invalid"

        draft.reload(from: overriddenEmail, editing: .repository)

        #expect(draft.value == "local@example.invalid")
    }

    /// An included file is visible but not writable at its own scope, so the draft treats the
    /// Repository as having nothing to edit.
    @Test
    func ignoresAValueThatOnlyExistsThroughAnInclude() {
        let globalEntry = entry(.userEmail, "global@example.invalid", .global)
        let configuration = GitConfigurationSnapshot(
            entries: [globalEntry, entry(.userEmail, "included@example.invalid", .local)],
            editableEntries: [globalEntry]
        )

        let draft = ConfigurationFieldDraft(
            key: .userEmail,
            configuration: configuration,
            editing: .repository
        )

        #expect(draft.value.isEmpty)
    }

    private var overriddenEmail: GitConfigurationSnapshot {
        GitConfigurationSnapshot(entries: [
            entry(.userEmail, "global@example.invalid", .global),
            entry(.userEmail, "local@example.invalid", .local),
        ])
    }

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
