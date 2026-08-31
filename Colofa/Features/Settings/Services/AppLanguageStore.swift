////
//  AppLanguageStore.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// Reads and writes the Display Language.
///
/// The single source of truth is `AppleLanguages` in the app's own persistent domain — the same
/// key macOS's per-app language row in System Settings writes. Sharing it means a choice made in
/// Colofa and one made in System Settings can never disagree, and it is why there is no second
/// preference key here.
///
/// Not `@Observable`: this is stored preference I/O rather than UI-facing mutable state.
nonisolated struct AppLanguageStore {
    private let userDefaults: UserDefaults

    /// The persistent domain to read, which is the app's own rather than the search list.
    private let domainName: String

    init(userDefaults: UserDefaults, domainName: String) {
        self.userDefaults = userDefaults
        self.domainName = domainName
    }

    /// The stored selection.
    ///
    /// Read through the persistent domain rather than `object(forKey:)`, which resolves through
    /// `NSGlobalDomain` and always answers with the system's own language list. That lookup
    /// cannot tell "follow the system" apart from an explicit choice; this one can.
    var selection: DisplayLanguageSelection {
        DisplayLanguageSelection(
            appleLanguages: userDefaults.persistentDomain(forName: domainName)?[Self.key]
                as? [String]
        )
    }

    /// The system's own language preference, which is what Follow System resolves against.
    var systemLanguages: [String] {
        userDefaults.persistentDomain(forName: UserDefaults.globalDomain)?[Self.key]
            as? [String] ?? []
    }

    /// Stores `selection`, removing the key outright when it follows the system.
    func setSelection(_ selection: DisplayLanguageSelection) {
        guard let languages = selection.appleLanguages else {
            userDefaults.removeObject(forKey: Self.key)
            return
        }
        userDefaults.set(languages, forKey: Self.key)
    }

    private static let key = "AppleLanguages"
}

extension AppLanguageStore {
    /// The store the app itself runs on, writing to its own preferences domain.
    static func live(bundle: Bundle = .main) -> Self {
        Self(
            userDefaults: .standard,
            // A bundle without an identifier has no preferences domain to write to, and the empty
            // name simply reads and writes nothing rather than reaching another app's domain.
            domainName: bundle.bundleIdentifier ?? ""
        )
    }
}
