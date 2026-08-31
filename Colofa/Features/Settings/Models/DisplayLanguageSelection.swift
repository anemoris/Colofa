////
//  DisplayLanguageSelection.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// What the user has chosen the Display Language to be: the system's own answer, or one language
/// named outright.
nonisolated enum DisplayLanguageSelection: Hashable, Sendable {
    case followSystem
    case explicit(String)

    /// Reads the selection an `AppleLanguages` value in the app's own domain expresses.
    ///
    /// The key holds an ordered preference list, and the first entry is the one the app launches
    /// in. An empty array is what macOS writes when its own per-app language row is set back to
    /// the system default, which says the same thing as no key at all.
    init(appleLanguages: [String]?) {
        guard let first = appleLanguages?.first else {
            self = .followSystem
            return
        }
        self = .explicit(first)
    }

    /// The value to store, or `nil` when the key is to be removed. Following the system means
    /// having no override: writing today's system language instead would freeze the app to it the
    /// moment the system changed.
    var appleLanguages: [String]? {
        switch self {
        case .followSystem:
            nil
        case .explicit(let code):
            [code]
        }
    }

    /// Whether applying this selection needs the app to be launched again.
    ///
    /// The comparison is against the language the app would launch in rather than against the
    /// preference string itself: a system asking for `zh-Hans-JP` already launches Colofa in
    /// `zh-Hans`, and a system asking for a language Colofa does not ship already launches it in
    /// the development language. `launchLanguage` is what the bundle resolved at launch, so
    /// setting a choice back to it makes the notice disappear.
    func requiresRelaunch(
        fromLaunchLanguage launchLanguage: String?,
        systemPreferences: [String],
        availableLocalizations: [String]
    ) -> Bool {
        // Nothing is known about what a relaunch would change when the bundle reports no
        // language at all, and a notice that cannot say that should not appear.
        guard let launchLanguage else {
            return false
        }
        let preferences: [String]
        switch self {
        case .followSystem:
            preferences = systemPreferences
        case .explicit(let code):
            preferences = [code]
        }
        let resolved = Bundle.preferredLocalizations(
            from: availableLocalizations,
            forPreferences: preferences
        )
        return resolved.first != launchLanguage
    }
}
