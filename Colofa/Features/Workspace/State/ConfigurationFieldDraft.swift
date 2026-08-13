////
//  ConfigurationFieldDraft.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation

/// The unsaved contents of one configuration field.
///
/// The three rules that decide what a draft *means* live here rather than in the view, so they
/// can be tested without driving the UI: seed from the value stored at the scope being edited,
/// refill when that value or the scope changes, and treat an empty field as a request to unset.
///
/// The edit scope is deliberately not stored. It belongs to the workspace, changes while a
/// draft is alive, and a stale copy would write to the wrong file — so callers pass the current
/// scope on every call.
struct ConfigurationFieldDraft: Equatable, Sendable {
    let key: GitConfigurationKey
    var value: String

    init(
        key: GitConfigurationKey,
        configuration: GitConfigurationSnapshot,
        editing scope: GitConfigurationEditScope
    ) {
        self.key = key
        value = Self.storedValue(in: configuration, key: key, editing: scope)
    }

    /// What a save should write, or `nil` to unset the key.
    ///
    /// Clearing the field means "restore inheritance". Git treats a stored empty string as a
    /// real value that keeps shadowing the wider scope, so an empty draft must never be written
    /// through as `""`.
    var requestedValue: String? {
        value.isEmpty ? nil : value
    }

    /// Whether saving would change anything at `scope`.
    func needsSaving(
        against configuration: GitConfigurationSnapshot,
        editing scope: GitConfigurationEditScope
    ) -> Bool {
        configuration.requiresUpdate(requestedValue, for: key, editing: scope)
    }

    /// Discards the draft in favour of what is stored at `scope`.
    mutating func reload(
        from configuration: GitConfigurationSnapshot,
        editing scope: GitConfigurationEditScope
    ) {
        value = Self.storedValue(in: configuration, key: key, editing: scope)
    }

    private static func storedValue(
        in configuration: GitConfigurationSnapshot,
        key: GitConfigurationKey,
        editing scope: GitConfigurationEditScope
    ) -> String {
        configuration.editableValue(for: key, editing: scope) ?? ""
    }
}
