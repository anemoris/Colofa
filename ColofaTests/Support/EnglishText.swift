////
//  EnglishText.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation
@testable import Colofa

/// The English copy of one resource.
///
/// A test that asserts what a string actually says has to name the language it is reading, or it
/// passes and fails by the language of whatever machine ran it. English is the development and
/// fallback language, so it is the one these assertions are written against; that every other
/// supported language has a value at all is `LocalizationCompletenessTests`' job.
func englishText(_ resource: LocalizedStringResource) -> String {
    var english = resource
    english.locale = Locale(identifier: "en")
    return String(localized: english)
}
