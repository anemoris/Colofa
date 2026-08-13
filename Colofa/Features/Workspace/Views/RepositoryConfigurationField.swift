////
//  RepositoryConfigurationField.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import SwiftUI

struct RepositoryConfigurationField: View {
    @Environment(WorkspaceState.self) private var state
    let configuration: GitConfigurationSnapshot
    let key: GitConfigurationKey
    let editingScope: GitConfigurationEditScope
    @State private var draft: ConfigurationFieldDraft

    init(
        configuration: GitConfigurationSnapshot,
        key: GitConfigurationKey,
        editingScope: GitConfigurationEditScope
    ) {
        self.configuration = configuration
        self.key = key
        self.editingScope = editingScope
        _draft = State(
            initialValue: ConfigurationFieldDraft(
                key: key,
                configuration: configuration,
                editing: editingScope
            )
        )
    }

    var body: some View {
        let sourceEntries = configuration.entries(for: key)

        VStack(alignment: .leading, spacing: 6) {
            TextField(String(localized: key.title), text: $draft.value)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("repository.configuration.\(key.rawValue)")
                .onSubmit(save)

            Text(key.helpText)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let warning = key.warning(for: draft.value) {
                RepositoryConfigurationNote(
                    message: warning,
                    systemImage: "exclamationmark.triangle",
                    isWarning: true
                )
            }

            if let relationship = configuration.relationship(for: key, editing: editingScope) {
                RepositoryConfigurationRelationshipView(
                    relationship: relationship,
                    canRemoveOverride: state.canEditConfiguration,
                    removeOverride: removeOverride
                )
                .accessibilityIdentifier("repository.configuration.relationship.\(key.rawValue)")
            }

            if sourceEntries.isEmpty {
                Text(.configurationNoValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                // Identified by position, not by entry: a file that sets the same key twice
                // yields two byte-identical entries, which would collide as ForEach identities.
                ForEach(sourceEntries.indices, id: \.self) { index in
                    RepositoryConfigurationSourceView(
                        entry: sourceEntries[index],
                        isEffective: index == sourceEntries.count - 1
                    )
                }
            }

            Button(.configurationSave, action: save)
                .disabled(!state.canEditConfiguration || !hasChanges)
                .accessibilityIdentifier("repository.configuration.save.\(key.rawValue)")
        }
        .onChange(of: configuration.editableValue(for: key, editing: editingScope)) {
            draft.reload(from: configuration, editing: editingScope)
        }
        .onChange(of: editingScope) {
            draft.reload(from: configuration, editing: editingScope)
        }
    }

    private var hasChanges: Bool {
        draft.needsSaving(against: configuration, editing: editingScope)
    }

    private func save() {
        guard state.canEditConfiguration, hasChanges else {
            return
        }
        Task {
            await state.updateConfiguration(
                key,
                value: draft.requestedValue,
                in: editingScope
            )
        }
    }

    private func removeOverride() {
        guard state.canEditConfiguration,
              let scope = configuration.relationship(
            for: key,
            editing: editingScope
        )?.removableScope else {
            return
        }

        Task {
            await state.updateConfiguration(key, value: nil, in: scope)
        }
    }
}
