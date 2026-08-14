////
//  LocalizationLiteralTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// Reads the app's own source, so copy that reaches a view as a literal fails here rather than
/// shipping one screen that is English in every language.
///
/// `LocalizationCompletenessTests` can only judge keys the String Catalog already holds. A view
/// that never asks the catalog is invisible to it, which is the gap this closes.
struct LocalizationLiteralTests {
    /// SwiftUI API whose first argument is copy the user reads. `Text(verbatim:)` is deliberately
    /// absent here: it is how content Git produced — a path, a Hunk header, a line of a patch —
    /// is shown without being translated, and `verbatimLiteralPattern` covers its own misuse.
    private static let localizedInitializers = [
        "Button",
        "ContentUnavailableView",
        "DisclosureGroup",
        "GroupBox",
        "Label",
        "LabeledContent",
        "Link",
        "LocalizedStringKey",
        "LocalizedStringResource",
        "Menu",
        "Picker",
        "ProgressView",
        "SecureField",
        "Section",
        "Stepper",
        "Text",
        "TextField",
        "Toggle",
    ]

    /// Modifiers that take user-facing copy. Identifier-only modifiers such as
    /// `accessibilityIdentifier` are absent: they name an element for tests and are never read.
    private static let localizedModifiers = [
        "accessibilityHint",
        "accessibilityLabel",
        "accessibilityValue",
        "alert",
        "confirmationDialog",
        "help",
        "navigationSubtitle",
        "navigationTitle",
    ]

    @Test
    func noUserFacingCopyReachesAViewAsALiteral() throws {
        var violations: [String] = []
        for url in try Self.appSourceFiles() {
            let source = try String(contentsOf: url, encoding: .utf8)
            violations += try Self.literalCopy(in: source, of: url.lastPathComponent)
        }

        #expect(
            violations.isEmpty,
            "Bypassing the String Catalog: \(violations.joined(separator: ", "))"
        )
    }

    /// The check has to fail for the case it exists for, or it would pass forever by looking at
    /// nothing.
    @Test
    func theCheckFlagsALiteralAndAcceptsEveryLocalizedForm() throws {
        let bypasses = """
        Text("Raw user-facing copy")
        Button("Load Anyway", action: load)
        .help("Why this is disabled")
        """
        let accepted = """
        Text(.diffBeyondLimit)
        Text(verbatim: change.path)
        Button(.reloadDiff, action: reload)
        // Text("Copy inside a comment")
        Text(String(localized: .loadingDiff))
        .accessibilityIdentifier("repository.diff.content")
        """

        #expect(try Self.literalCopy(in: bypasses, of: "Bypasses.swift").count == 3)
        #expect(try Self.literalCopy(in: accepted, of: "Accepted.swift").isEmpty)
    }

    /// One line per form the check can be bypassed through, so a form that stops being seen fails
    /// on its own rather than hiding inside a block that still reports some other violation.
    @Test(
        arguments: [
            #"Text(verbatim: "Hard-coded UI")"#,
            #"ProgressView("Reading the patch")"#,
            #"SwiftUI.Text("Copy through the qualified name")"#,
            #"SwiftUI.Text(verbatim: "Qualified and hard-coded")"#,
            // An escape is not a value: each of these is copy that happens to be spelled with a
            // backslash, a raw literal, or three quotes.
            #"Text(verbatim: "Hard-coded\nUI")"#,
            #"Text(verbatim: "Press \"Continue\"")"#,
            ##"Text(verbatim: #"Hard-coded UI"#)"##,
            ##"Text(#"A hard-coded key"#)"##,
            #"""
            Text(verbatim: """
            Hard-coded UI
            """)
            """#,
        ]
    )
    func theCheckFlagsCopyInEveryFormThatReachesAView(_ line: String) throws {
        #expect(try Self.literalCopy(in: line, of: "Bypass.swift").count == 1)
    }

    /// The forms next to them that must keep working, because content Git produced is shown
    /// without translation and is the reason `verbatim:` exists at all.
    @Test(
        arguments: [
            "Text(verbatim: change.path)",
            #"Text(verbatim: "+\(stats.additions.formatted(.number))")"#,
            #"Text(verbatim: "")"#,
            #"Text(verbatim: "\(oldMode) → \(newMode)")"#,
            ##"Text(verbatim: #"\#(change.path)"#)"##,
            #"""
            Text(verbatim: """
            \(diff.files.count)
            """)
            """#,
            "ProgressView()",
            "ProgressView(String(localized: .loadingDiff))",
            #"DiffText("a line of a patch")"#,
        ]
    )
    func theCheckAcceptsEveryFormThatDoesNotBypassTheCatalog(_ line: String) throws {
        #expect(try Self.literalCopy(in: line, of: "Accepted.swift").isEmpty)
    }

    private static func literalCopy(in source: String, of name: String) throws -> [String] {
        let code = strippingComments(from: source)
        return try patterns().flatMap { pattern in
            code.matches(of: pattern).map { match in
                let line = code[code.startIndex..<match.range.lowerBound]
                    .count { $0 == "\n" }
                return "\(name):\(line + 1): \(code[match.range])"
            }
        }
    }

    /// Content shown without translation has to come from a value: a `Text(verbatim:)` given a
    /// literal with nothing interpolated into it is copy taking the escape hatch that exists for
    /// Git's output. All three spellings of a Swift literal are covered, because a multi-line or
    /// raw one holds hard-coded copy just as well as an ordinary one does.
    ///
    /// An escape is not an interpolation — `"Press \"Continue\""` is copy with a quote in it —
    /// and `strippingComments(from:)` keeps a backslash only where an interpolation begins, so
    /// "holds a backslash" and "holds a value" mean the same thing to these patterns. An empty
    /// literal is a placeholder holding a row's height rather than copy, so a match needs at
    /// least one character between the delimiters.
    private static var verbatimLiteralPatterns: [String] {
        let verbatim = "(?:^|[^\\w.])(?:SwiftUI\\.)?Text\\s*\\(\\s*verbatim:\\s*"
        return [
            verbatim + "\"[^\"\\\\]+\"",
            verbatim + "#+\"[^\"\\\\]+\"#+",
            verbatim + "\"\"\"[^\\\\]+?\"\"\"",
        ]
    }

    /// A leading string literal is what marks the copy: `Text(.key)` starts with something else,
    /// so it does not match.
    private static func patterns() throws -> [Regex<AnyRegexOutput>] {
        // The leading `[^\w.]` keeps a type of the project's own such as `DiffText(` out of it,
        // while the optional `SwiftUI.` keeps the framework's fully qualified spelling in. The
        // `#*` before the quote keeps a raw literal from being a way around any of them.
        let initializers = try localizedInitializers.map {
            try Regex("(?:^|[^\\w.])(?:SwiftUI\\.)?\($0)\\s*\\(\\s*#*\"")
        }
        let modifiers = try localizedModifiers.map { try Regex("\\.\($0)\\s*\\(\\s*#*\"") }
        // A literal key here bypasses the generated symbols the catalog is read through.
        return try (initializers + modifiers + [Regex("String\\(\\s*localized:\\s*#*\"")])
            + verbatimLiteralPatterns.map { try Regex($0) }
    }

    /// Blanks comments while keeping every line where it was, so a match still reports the line
    /// the reader will look at.
    ///
    /// Quoted spans are stepped over, so a `//` inside a URL is not read as a comment. A
    /// multi-line literal's `"""` toggles the quoted state three times at each end, which leaves
    /// the state right on the far side of it and the body intact for a pattern to read. What it
    /// does not model is a lone `"` inside such a body, which can only hide a match rather than
    /// invent one.
    private static func strippingComments(from source: String) -> String {
        var code = ""
        var isInString = false
        var isInBlockComment = false
        let characters = Array(source)
        var index = 0

        while index < characters.count {
            let character = characters[index]
            let next = index + 1 < characters.count ? characters[index + 1] : nil
            if isInBlockComment {
                if character == "*" && next == "/" {
                    isInBlockComment = false
                    code.append("  ")
                    index += 2
                    continue
                }
                code.append(character == "\n" ? "\n" : " ")
            } else if isInString {
                if character == "\\" {
                    // Only an interpolation's own backslash survives: `\(`, or `\#(` inside a raw
                    // literal, is how a value reaches a string, while `\n` and `\"` are copy with
                    // an escape in it. What the backslash escapes is blanked either way, so a
                    // quote cannot end the string early.
                    if let next, next == "(" || next == "#" {
                        code.append("\\")
                        code.append(next)
                    } else {
                        code.append("  ")
                    }
                    index += 2
                    continue
                }
                isInString = character != "\""
                code.append(character)
            } else if character == "/" && next == "/" {
                while index < characters.count && characters[index] != "\n" {
                    index += 1
                }
                continue
            } else if character == "/" && next == "*" {
                isInBlockComment = true
                code.append("  ")
                index += 2
                continue
            } else {
                isInString = character == "\""
                code.append(character)
            }
            index += 1
        }
        return code
    }

    /// Every Swift file in the app target, located from this file rather than from anything about
    /// the machine running the test.
    private static func appSourceFiles() throws -> [URL] {
        let appURL = URL(filePath: #filePath)
            .deletingLastPathComponent()      // Workspace
            .deletingLastPathComponent()      // Features
            .deletingLastPathComponent()      // ColofaTests
            .deletingLastPathComponent()      // the checkout
            .appending(path: "Colofa", directoryHint: .isDirectory)
        let files = FileManager.default.enumerator(at: appURL, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" } ?? []
        #expect(files.count > 1, "No app source was found to check")
        return files
    }
}
