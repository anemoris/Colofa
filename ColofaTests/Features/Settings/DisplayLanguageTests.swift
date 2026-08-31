////
//  DisplayLanguageTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

struct DisplayLanguageTests {
    /// The list is the bundle's own localizations, so adding one to the String Catalog surfaces
    /// it in the picker without a code change. `Base` is a resource-loading fallback rather than
    /// a language anyone reads, so it never appears.
    @Test
    func availableLanguagesAreTheBundleLocalizationsWithoutBase() {
        let languages = DisplayLanguage.available(in: ["zh-Hant", "Base", "en", "ja"])

        #expect(languages.map(\.code) == ["en", "ja", "zh-Hant"])
    }

    /// A bundle reports its localizations in whatever order the resources happen to sit in, and a
    /// picker whose rows move between launches is not a picker anyone can use twice.
    @Test
    func availableLanguagesAreOrderedByCode() {
        let first = DisplayLanguage.available(in: ["ko", "en", "zh-Hans"])
        let second = DisplayLanguage.available(in: ["zh-Hans", "ko", "en"])

        #expect(first == second)
        #expect(first.map(\.code) == ["en", "ko", "zh-Hans"])
    }

    /// Every row is labelled in its own language: the user this picker exists for is the one who
    /// cannot read the language the rest of the window is in.
    @Test(
        arguments: [
            ("en", "English"),
            ("ja", "日本語"),
            ("ko", "한국어"),
            ("zh-Hans", "简体中文"),
            ("zh-Hant", "繁體中文"),
        ]
    )
    func eachLanguageIsLabelledInItsOwnLanguage(code: String, endonym: String) {
        #expect(DisplayLanguage(code: code).endonym == endonym)
    }

    /// A code Foundation has no name for still has to render as something selectable.
    @Test
    func anUnnamedLanguageFallsBackToItsOwnCode() {
        #expect(DisplayLanguage(code: "qqq-Zzzz").endonym == "qqq-Zzzz")
    }
}
