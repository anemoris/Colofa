////
//  WorkspaceState+Configuration.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation

/// Editing of the Git configuration values Colofa supports.
///
/// The selected scope is passed in per call rather than read from
/// `configurationEditingScope`, because removing a Repository override is a write to the
/// Repository even while the user is editing Global.
extension WorkspaceState {
    var canEditConfiguration: Bool {
        canMutateRepository && repository != nil
    }

    var hasEffectiveCommitIdentity: Bool {
        repository?.configuration.hasEffectiveIdentity == true
    }

    func updateConfiguration(
        _ key: GitConfigurationKey,
        value: String?,
        in scope: GitConfigurationEditScope
    ) async {
        guard let repository, canEditConfiguration else {
            return
        }

        // Clearing a field means "restore inheritance", so an absent value at this scope is
        // already the requested state and must not run a doomed unset.
        if value == nil,
           !repository.configuration.hasEditableEntry(for: key, editing: scope) {
            return
        }

        // The `-all` forms, not the plain ones: a file may legitimately list a key more than
        // once, and Git refuses to overwrite or unset a multi-valued key through the singular
        // commands. Against a single value they behave identically.
        let arguments: [String]
        if let value {
            arguments = ["config"] + scope.gitArguments + ["--replace-all", key.rawValue, value]
        } else {
            arguments = ["config"] + scope.gitArguments + ["--unset-all", key.rawValue]
        }
        await performMutation(arguments, failureTitle: .configurationSaveFailed)
    }
}
