////
//  LocalizationCompletenessTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// Reads the String Catalog itself, so adding a key without translating it fails here rather
/// than shipping a screen that falls back to English.
struct LocalizationCompletenessTests {
    private static let supportedLanguages = ["en", "ja", "ko", "zh-Hans", "zh-Hant"]

    @Test
    func everyKeyHasAValueInEverySupportedLanguage() throws {
        let catalog = try Self.catalog()
        var missing: [String] = []

        for (key, entry) in catalog.strings.sorted(by: { $0.key < $1.key }) {
            for language in Self.supportedLanguages {
                let value = entry.localizations[language]?.stringUnit.value
                if value?.isEmpty != false {
                    missing.append("\(key) [\(language)]")
                }
            }
        }

        #expect(missing.isEmpty, "Untranslated: \(missing.joined(separator: ", "))")
    }

    /// A key still marked as needing review is not a translated key, whatever it holds.
    @Test
    func everyValueIsMarkedTranslated() throws {
        let catalog = try Self.catalog()
        let unfinished = catalog.strings
            .flatMap { key, entry in
                entry.localizations
                    .filter { $0.value.stringUnit.state != "translated" }
                    .map { "\(key) [\($0.key): \($0.value.stringUnit.state)]" }
            }
            .sorted()

        #expect(unfinished.isEmpty, "Not translated: \(unfinished.joined(separator: ", "))")
    }

    @Test
    func theCatalogDeclaresExactlyTheSupportedLanguages() throws {
        let catalog = try Self.catalog()
        let declared = Set(catalog.strings.values.flatMap(\.localizations.keys))

        #expect(declared == Set(Self.supportedLanguages))
        #expect(catalog.sourceLanguage == "en")
    }

    private typealias Catalog = LocalizationCatalog

    /// The String Catalog is a source file that Xcode compiles into per-language tables, so the
    /// `.xcstrings` itself never reaches a bundle. It is read from the checkout instead, located
    /// from this file rather than from anything about the machine running the test.
    private static func catalog() throws -> Catalog {
        let url = URL(filePath: #filePath)
            .deletingLastPathComponent()      // Workspace
            .deletingLastPathComponent()      // Features
            .deletingLastPathComponent()      // ColofaTests
            .deletingLastPathComponent()      // the checkout
            .appending(path: "Colofa/Resources/Localizable.xcstrings")
        return try JSONDecoder().decode(Catalog.self, from: try Data(contentsOf: url))
    }
}

/// The parts of a String Catalog these tests read. Declared alongside rather than nested, because
/// a catalog nests four levels deep and the project caps nesting at one.
private struct LocalizationCatalog: Decodable {
    let sourceLanguage: String
    let strings: [String: LocalizationEntry]
}

private struct LocalizationEntry: Decodable {
    let localizations: [String: Localization]
}

private struct Localization: Decodable {
    let stringUnit: LocalizationUnit
}

private struct LocalizationUnit: Decodable {
    let state: String
    let value: String
}
