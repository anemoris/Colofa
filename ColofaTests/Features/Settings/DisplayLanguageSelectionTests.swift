////
//  DisplayLanguageSelectionTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

struct DisplayLanguageSelectionTests {
    private static let localizations = ["en", "ja", "ko", "zh-Hans", "zh-Hant"]

    @Test
    func anAbsentOverrideReadsAsFollowSystem() {
        #expect(DisplayLanguageSelection(appleLanguages: nil) == .followSystem)
    }

    /// macOS writes an empty array when its own per-app language row is set back to the system
    /// default, which is the same statement as no key at all.
    @Test
    func anEmptyOverrideReadsAsFollowSystem() {
        #expect(DisplayLanguageSelection(appleLanguages: []) == .followSystem)
    }

    /// `AppleLanguages` is an ordered preference list, and the first entry is the one the app
    /// actually launches in.
    @Test
    func anOverrideReadsAsItsFirstLanguage() {
        #expect(DisplayLanguageSelection(appleLanguages: ["ja", "en"]) == .explicit("ja"))
    }

    @Test
    func anExplicitSelectionIsWrittenAsASingleEntryList() {
        #expect(DisplayLanguageSelection.explicit("zh-Hant").appleLanguages == ["zh-Hant"])
    }

    /// Following the system means having no override at all. Writing a value that happens to
    /// match today's system language would freeze the app to it the moment the system changed.
    @Test
    func followingTheSystemIsWrittenAsNoValue() {
        #expect(DisplayLanguageSelection.followSystem.appleLanguages == nil)
    }

    @Test
    func anExplicitSelectionMatchingTheLaunchLanguageNeedsNoRelaunch() {
        let selection = DisplayLanguageSelection.explicit("ja")

        #expect(
            !selection.requiresRelaunch(
                fromLaunchLanguage: "ja",
                systemPreferences: ["en-US"],
                availableLocalizations: Self.localizations
            )
        )
    }

    @Test
    func anExplicitSelectionDifferingFromTheLaunchLanguageNeedsARelaunch() {
        let selection = DisplayLanguageSelection.explicit("ko")

        #expect(
            selection.requiresRelaunch(
                fromLaunchLanguage: "ja",
                systemPreferences: ["en-US"],
                availableLocalizations: Self.localizations
            )
        )
    }

    /// The comparison is against the language the app would launch in, not against the literal
    /// preference string: a system asking for `zh-Hans-JP` already launches Colofa in `zh-Hans`.
    @Test
    func followingASystemAlreadyResolvingToTheLaunchLanguageNeedsNoRelaunch() {
        #expect(
            !DisplayLanguageSelection.followSystem.requiresRelaunch(
                fromLaunchLanguage: "zh-Hans",
                systemPreferences: ["zh-Hans-JP", "ja-JP"],
                availableLocalizations: Self.localizations
            )
        )
    }

    /// Going back to the system after an override is what the notice has to appear for, since the
    /// override is exactly what the running process is still using.
    @Test
    func followingASystemResolvingElsewhereNeedsARelaunch() {
        #expect(
            DisplayLanguageSelection.followSystem.requiresRelaunch(
                fromLaunchLanguage: "ja",
                systemPreferences: ["ko-KR"],
                availableLocalizations: Self.localizations
            )
        )
    }

    /// A system language Colofa does not ship falls back to the development language, so a
    /// French system that launched Colofa in English stays settled on Follow System.
    @Test
    func followingASystemWithNoShippedLocalizationResolvesToTheDevelopmentLanguage() {
        #expect(
            !DisplayLanguageSelection.followSystem.requiresRelaunch(
                fromLaunchLanguage: "en",
                systemPreferences: ["fr-FR"],
                availableLocalizations: Self.localizations
            )
        )
    }

    /// Nothing is known about the launch language when the bundle reports none, and a notice that
    /// cannot say what would change should not appear.
    @Test
    func anUnknownLaunchLanguageNeverAsksForARelaunch() {
        #expect(
            !DisplayLanguageSelection.explicit("ko").requiresRelaunch(
                fromLaunchLanguage: nil,
                systemPreferences: ["en-US"],
                availableLocalizations: Self.localizations
            )
        )
    }
}
