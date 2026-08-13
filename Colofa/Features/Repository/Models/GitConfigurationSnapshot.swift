////
//  GitConfigurationSnapshot.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation

struct GitConfigurationSnapshot: Equatable, Sendable {
    let entries: [GitConfigurationEntry]
    private let editableEntries: [GitConfigurationEntry]

    /// Treats every entry as living directly in the file its scope names.
    ///
    /// Convenience for callers with no include indirection to model — tests and the UI-testing
    /// stub. Real snapshots go through `init(entries:editableEntries:)`, because an entry that
    /// arrived through `include.path` is visible but cannot be written at its own scope.
    nonisolated init(entries: [GitConfigurationEntry]) {
        self.entries = entries
        editableEntries = entries
    }

    /// - Parameters:
    ///   - entries: What Git resolves, includes followed, in precedence order.
    ///   - editableEntries: The subset written literally in a global or local file, which is all
    ///     Colofa may rewrite or unset.
    nonisolated init(
        entries: [GitConfigurationEntry],
        editableEntries: [GitConfigurationEntry]
    ) {
        self.entries = entries
        self.editableEntries = editableEntries
    }

    nonisolated static let empty = Self(entries: [])

    func effectiveEntry(for key: GitConfigurationKey) -> GitConfigurationEntry? {
        entries.last { $0.key == key }
    }

    func entries(for key: GitConfigurationKey) -> [GitConfigurationEntry] {
        entries.filter { $0.key == key }
    }

    func editableValue(
        for key: GitConfigurationKey,
        editing scope: GitConfigurationEditScope
    ) -> String? {
        editableEntry(for: key, editing: scope)?.value
    }

    func requiresUpdate(
        _ value: String?,
        for key: GitConfigurationKey,
        editing scope: GitConfigurationEditScope
    ) -> Bool {
        editableValue(for: key, editing: scope) != value
    }

    func hasEntry(for key: GitConfigurationKey, in scope: GitConfigurationScope) -> Bool {
        entries.contains { $0.key == key && $0.scope == scope }
    }

    func hasEditableEntry(
        for key: GitConfigurationKey,
        editing scope: GitConfigurationEditScope
    ) -> Bool {
        editableEntry(for: key, editing: scope) != nil
    }

    func shadowingEntry(
        for key: GitConfigurationKey,
        editing scope: GitConfigurationEditScope
    ) -> GitConfigurationEntry? {
        guard let effective = effectiveEntry(for: key) else {
            return nil
        }

        if let effectiveRank = effective.scope.precedenceRank,
           let editingRank = scope.gitScope.precedenceRank,
           effectiveRank > editingRank
            || (effectiveRank == editingRank
                && effective != editableEntry(for: key, editing: scope)) {
            return effective
        }

        return nil
    }

    func relationship(
        for key: GitConfigurationKey,
        editing scope: GitConfigurationEditScope
    ) -> GitConfigurationRelationship? {
        if let shadowingEntry = shadowingEntry(for: key, editing: scope) {
            // Removable only when the Repository holds a directly editable value for this key.
            // Matching on key and scope rather than on the whole entry keeps this independent of
            // how Git happens to spell the origin path in each of the two reads.
            let removableScope: GitConfigurationEditScope? =
                shadowingEntry.scope == .local
                    && hasEditableEntry(for: key, editing: .repository)
                ? .repository
                : nil
            return .shadowedBy(shadowingEntry, removableScope: removableScope)
        }

        guard scope == .repository,
              let globalEntry = entries.last(where: { $0.key == key && $0.scope == .global }) else {
            return nil
        }
        if editableValue(for: key, editing: .repository) == nil {
            return .inheritsGlobal(globalEntry)
        }
        return .overridesGlobal(globalEntry)
    }

    private func editableEntry(
        for key: GitConfigurationKey,
        editing scope: GitConfigurationEditScope
    ) -> GitConfigurationEntry? {
        editableEntries.last { $0.key == key && $0.scope == scope.gitScope }
    }

    var hasEffectiveIdentity: Bool {
        guard let name = effectiveEntry(for: .userName)?.value,
              let email = effectiveEntry(for: .userEmail)?.value else {
            return false
        }
        return !name.isEmpty && !email.isEmpty
    }
}
