////
//  AppLanguageStoreTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

@Suite(.serialized)
struct AppLanguageStoreTests {
    private static let key = "AppleLanguages"

    @Test
    func anEmptyAppDomainReadsAsFollowSystem() throws {
        try withStore { store, defaults, _ in
            // The trap this closes: `AppleLanguages` also lives in `NSGlobalDomain`, which every
            // ordinary lookup resolves through, so `object(forKey:)` answers even when the app
            // has chosen nothing. macOS always supplies that value, so requiring it here fails
            // loudly rather than letting the assertion below pass over nothing.
            _ = try #require(
                defaults.object(forKey: Self.key),
                "NSGlobalDomain is expected to supply the system's own language list"
            )

            #expect(store.selection == .followSystem)
        }
    }

    /// The same key macOS's own per-app language row writes, so a language chosen in System
    /// Settings is the selection Colofa shows.
    @Test
    func anOverrideWrittenOutsideColofaIsTheCurrentSelection() throws {
        try withStore { store, defaults, _ in
            defaults.set(["ko"], forKey: Self.key)

            #expect(store.selection == .explicit("ko"))
        }
    }

    @Test
    func choosingALanguageWritesOnlyTheAppleLanguagesKey() throws {
        try withStore { store, defaults, domainName in
            store.setSelection(.explicit("zh-Hant"))

            let domain = try #require(defaults.persistentDomain(forName: domainName))
            #expect(domain[Self.key] as? [String] == ["zh-Hant"])
            #expect(domain.keys.sorted() == [Self.key])
        }
    }

    /// Follow System removes the key rather than writing one, so the app goes back to reading the
    /// system's own preference instead of being frozen to whatever it says today.
    @Test
    func choosingFollowSystemRemovesTheKey() throws {
        try withStore { store, defaults, domainName in
            store.setSelection(.explicit("ja"))
            store.setSelection(.followSystem)

            let domain = defaults.persistentDomain(forName: domainName) ?? [:]
            #expect(domain[Self.key] == nil)
            #expect(store.selection == .followSystem)
        }
    }

    @Test
    func aWrittenSelectionIsTheOneReadBack() throws {
        try withStore { store, _, _ in
            store.setSelection(.explicit("zh-Hans"))

            #expect(store.selection == .explicit("zh-Hans"))
        }
    }

    private func withStore(
        _ body: (AppLanguageStore, UserDefaults, String) throws -> Void
    ) throws {
        let domainName = "com.anemoris.Colofa.AppLanguageStoreTests"
        let defaults = try #require(UserDefaults(suiteName: domainName))
        defaults.removePersistentDomain(forName: domainName)
        defer { defaults.removePersistentDomain(forName: domainName) }

        let store = AppLanguageStore(userDefaults: defaults, domainName: domainName)
        try body(store, defaults, domainName)
    }
}
