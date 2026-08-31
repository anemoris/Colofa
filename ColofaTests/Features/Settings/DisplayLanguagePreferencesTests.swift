////
//  DisplayLanguagePreferencesTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// What the Settings pane reads, and why it has to be able to read it more than once.
@Suite(.serialized)
struct DisplayLanguagePreferencesTests {
    private static let key = "AppleLanguages"

    /// The case the refresh exists for: macOS's own per-app language row writes the same key, so
    /// the pane can be showing a choice the user has since made somewhere else. Reading again has
    /// to report the new one rather than the one the window opened with.
    @Test
    func readingAgainReportsAchoiceMadeOutsideColofa() throws {
        try withStore { store, defaults, _ in
            let opened = DisplayLanguagePreferences(store: store)
            #expect(opened.selection == .followSystem)

            // Stands in for System Settings writing the app's own per-app language row.
            defaults.set(["ja"], forKey: Self.key)

            #expect(DisplayLanguagePreferences(store: store).selection == .explicit("ja"))
            // The value the window opened with is untouched: a refresh replaces it rather than
            // mutating what was already read.
            #expect(opened.selection == .followSystem)
        }
    }

    /// Setting the selection is a decision, so it stays in the value the picker holds and reaches
    /// stored preferences only when the view writes it. Nothing here writes on its own.
    @Test
    func changingTheSelectionDoesNotWriteAnything() throws {
        try withStore { store, defaults, domainName in
            var preferences = DisplayLanguagePreferences(store: store)

            preferences.selection = .explicit("ko")

            #expect(preferences.selection == .explicit("ko"))
            #expect(defaults.persistentDomain(forName: domainName)?[Self.key] == nil)
        }
    }

    /// The relaunch notice is a comparison against the system's own list, which is exactly why
    /// that list is read alongside the selection instead of being kept from launch: a system
    /// language that changed makes the same selection need a relaunch, or stop needing one.
    @Test
    func followSystemNeedsArelaunchOnlyWhenTheSystemResolvesElsewhere() {
        let localizations = ["en", "ja"]

        let moved = DisplayLanguagePreferences(selection: .followSystem, systemLanguages: ["ja"])
        #expect(
            moved.requiresRelaunch(
                fromLaunchLanguage: "en",
                availableLocalizations: localizations
            )
        )

        let unchanged = DisplayLanguagePreferences(selection: .followSystem, systemLanguages: ["en"])
        #expect(
            !unchanged.requiresRelaunch(
                fromLaunchLanguage: "en",
                availableLocalizations: localizations
            )
        )
    }

    /// A chosen language is compared against the language the running process resolved, so
    /// choosing back what is already on screen takes the notice away again.
    @Test
    func anExplicitChoiceIsComparedAgainstTheRunningLanguage() {
        let localizations = ["en", "ja"]

        let preferences = DisplayLanguagePreferences(
            selection: .explicit("ja"),
            systemLanguages: ["en"]
        )
        #expect(
            preferences.requiresRelaunch(
                fromLaunchLanguage: "en",
                availableLocalizations: localizations
            )
        )
        #expect(
            !preferences.requiresRelaunch(
                fromLaunchLanguage: "ja",
                availableLocalizations: localizations
            )
        )
    }

    private func withStore(
        _ body: (AppLanguageStore, UserDefaults, String) throws -> Void
    ) throws {
        let domainName = "com.anemoris.Colofa.DisplayLanguagePreferencesTests"
        let defaults = try #require(UserDefaults(suiteName: domainName))
        defaults.removePersistentDomain(forName: domainName)
        defer { defaults.removePersistentDomain(forName: domainName) }

        let store = AppLanguageStore(userDefaults: defaults, domainName: domainName)
        try body(store, defaults, domainName)
    }
}
