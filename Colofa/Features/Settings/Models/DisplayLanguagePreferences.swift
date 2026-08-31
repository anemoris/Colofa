////
//  DisplayLanguagePreferences.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// What the Display Language pane has read from stored preferences.
///
/// The two values are read together rather than one at a time. They are compared against each
/// other to decide whether a relaunch is still owed, and reading them apart lets that comparison
/// answer against a selection and a system list that never held at the same moment.
///
/// It exists because neither value is Colofa's alone: `AppleLanguages` is the same key macOS's
/// own per-app language row writes, so both can change while the Settings window is open — with
/// no notification, because a plain stored preference is not observable state.
nonisolated struct DisplayLanguagePreferences: Equatable, Sendable {
    /// The chosen Display Language. Mutable because the picker is what sets it.
    var selection: DisplayLanguageSelection

    /// The system's own language preference, which Follow System resolves against. Nothing in
    /// Colofa chooses it, so nothing in Colofa writes it.
    let systemLanguages: [String]

    /// Takes both values as they stand right now.
    init(store: AppLanguageStore) {
        selection = store.selection
        systemLanguages = store.systemLanguages
    }

    init(selection: DisplayLanguageSelection, systemLanguages: [String]) {
        self.selection = selection
        self.systemLanguages = systemLanguages
    }

    /// Whether applying the current selection needs the app to be launched again.
    func requiresRelaunch(
        fromLaunchLanguage launchLanguage: String?,
        availableLocalizations: [String]
    ) -> Bool {
        selection.requiresRelaunch(
            fromLaunchLanguage: launchLanguage,
            systemPreferences: systemLanguages,
            availableLocalizations: availableLocalizations
        )
    }
}
